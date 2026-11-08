import { HttpStatus, Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { and, desc, eq, gt, inArray, isNull, lte, sql } from 'drizzle-orm';
import { AuditService } from '../audit/audit.service';
import { AppError } from '../common/errors';
import { ENV, Env } from '../config/env';
import { DB, Db } from '../db/db.module';
import { campaigns, offers, users } from '../db/schema';
import { NotificationsService } from '../notifications/notifications.service';

type Offer = typeof offers.$inferSelect;

/** Effective status: stored lifecycle + time window. */
export function effectiveStatus(o: Offer, now = new Date()): Offer['status'] {
  if (o.status === 'archived' || o.status === 'draft') return o.status;
  if (o.endAt <= now) return 'expired';
  if (o.startAt > now) return 'scheduled';
  return 'active';
}

export function customerView(o: Offer) {
  return {
    id: o.id,
    titleAr: o.titleAr,
    titleEn: o.titleEn,
    descriptionAr: o.descriptionAr,
    descriptionEn: o.descriptionEn,
    imageUrl: o.imageUrl,
    ctaLabelAr: o.ctaLabelAr,
    ctaLabelEn: o.ctaLabelEn,
    destinationUrl: o.destinationUrl,
    startAt: o.startAt.toISOString(),
    endAt: o.endAt.toISOString(),
  };
}

export interface OfferInput {
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  imageUrl?: string | null;
  ctaLabelAr?: string | null;
  ctaLabelEn?: string | null;
  destinationUrl?: string | null;
  startAt: string;
  endAt: string;
}

@Injectable()
export class OffersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OffersService.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(ENV) private readonly env: Env,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
  ) {}

  onModuleInit() {
    if (this.env.NODE_ENV !== 'test') this.timer = setInterval(() => this.dispatchDueOffers().catch((e) => this.logger.error(e)), 30_000);
  }
  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  // ── Customer side ─────────────────────────────────────────────────────────
  async listActive() {
    const now = new Date();
    const rows = await this.db
      .select()
      .from(offers)
      .where(and(inArray(offers.status, ['scheduled', 'active']), lte(offers.startAt, now), gt(offers.endAt, now)))
      .orderBy(desc(offers.startAt));
    return rows.map(customerView);
  }

  async getActive(id: string) {
    const [o] = await this.db.select().from(offers).where(eq(offers.id, id));
    // An expired offer stays viewable from an old notification, but marked so the app can say "ended".
    if (!o || o.status === 'draft' || o.status === 'archived' || o.startAt > new Date()) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    return { ...customerView(o), status: effectiveStatus(o) };
  }

  // ── Admin side ────────────────────────────────────────────────────────────
  private validateWindow(i: Pick<OfferInput, 'startAt' | 'endAt'>) {
    if (new Date(i.endAt) <= new Date(i.startAt)) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'endAt must be after startAt');
  }

  async create(adminId: string, input: OfferInput) {
    this.validateWindow(input);
    const [o] = await this.db.insert(offers).values({ ...input, startAt: new Date(input.startAt), endAt: new Date(input.endAt), createdBy: adminId, status: 'draft' }).returning();
    await this.audit.log({ actorType: 'admin', actorId: adminId, action: 'offer.created', resourceType: 'offer', resourceId: o.id });
    return this.adminView(o);
  }

  async update(adminId: string, id: string, input: Partial<OfferInput>) {
    const [cur] = await this.db.select().from(offers).where(eq(offers.id, id));
    if (!cur) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    if (cur.status === 'archived') throw new AppError('OFFER_INVALID_STATE', HttpStatus.CONFLICT, 'Archived offers cannot be edited');
    const next = { startAt: input.startAt ?? cur.startAt.toISOString(), endAt: input.endAt ?? cur.endAt.toISOString() };
    this.validateWindow(next);
    // Editing NEVER re-sends the notification (spec §12.3). Resend is an explicit action.
    const [o] = await this.db
      .update(offers)
      .set({ ...input, startAt: new Date(next.startAt), endAt: new Date(next.endAt), updatedAt: new Date() })
      .where(eq(offers.id, id))
      .returning();
    await this.audit.log({ actorType: 'admin', actorId: adminId, action: 'offer.updated', resourceType: 'offer', resourceId: id, metadata: { fields: Object.keys(input) } });
    return this.adminView(o);
  }

  async publish(adminId: string, id: string) {
    const [cur] = await this.db.select().from(offers).where(eq(offers.id, id));
    if (!cur) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    if (cur.status !== 'draft') throw new AppError('OFFER_INVALID_STATE', HttpStatus.CONFLICT, `Offer is ${effectiveStatus(cur)}`);
    if (cur.endAt <= new Date()) throw new AppError('OFFER_INVALID_STATE', HttpStatus.CONFLICT, 'Offer end date is in the past');
    const status = cur.startAt > new Date() ? 'scheduled' : 'active';
    await this.db.update(offers).set({ status, publishedAt: new Date(), updatedAt: new Date() }).where(eq(offers.id, id));
    await this.audit.log({ actorType: 'admin', actorId: adminId, action: 'offer.published', resourceType: 'offer', resourceId: id, metadata: { status } });
    // Active now → notify now. Scheduled → the dispatcher notifies when it goes live.
    if (status === 'active') await this.dispatch(id, adminId, 'publish');
    const [o] = await this.db.select().from(offers).where(eq(offers.id, id));
    return this.adminView(o);
  }

  async archive(adminId: string, id: string) {
    const [o] = await this.db.update(offers).set({ status: 'archived', updatedAt: new Date() }).where(eq(offers.id, id)).returning();
    if (!o) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    await this.audit.log({ actorType: 'admin', actorId: adminId, action: 'offer.archived', resourceType: 'offer', resourceId: id });
    return this.adminView(o);
  }

  /** Explicit admin re-send (spec §12.3: repeats require an explicit action). */
  async resend(adminId: string, id: string) {
    const [o] = await this.db.select().from(offers).where(eq(offers.id, id));
    if (!o) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    if (effectiveStatus(o) !== 'active') throw new AppError('OFFER_INVALID_STATE', HttpStatus.CONFLICT, 'Only active offers can be re-sent');
    if (!o.notificationDispatchedAt) throw new AppError('OFFER_INVALID_STATE', HttpStatus.CONFLICT, 'Initial notification not sent yet');
    return this.sendCampaign(o, adminId, 'resend');
  }

  /** Publishes scheduled offers whose start time has arrived. Safe to run on many instances. */
  async dispatchDueOffers() {
    const due = await this.db
      .select({ id: offers.id })
      .from(offers)
      .where(and(eq(offers.status, 'scheduled'), lte(offers.startAt, new Date()), gt(offers.endAt, new Date()), isNull(offers.notificationDispatchedAt)));
    for (const d of due) {
      await this.db.update(offers).set({ status: 'active', updatedAt: new Date() }).where(eq(offers.id, d.id));
      await this.dispatch(d.id, null, 'publish');
    }
  }

  /** Claims the one-time publish notification atomically; a second caller gets nothing to do. */
  private async dispatch(id: string, adminId: string | null, kind: 'publish') {
    const [claimed] = await this.db
      .update(offers)
      .set({ notificationDispatchedAt: new Date() })
      .where(and(eq(offers.id, id), isNull(offers.notificationDispatchedAt)))
      .returning();
    if (!claimed) return null;
    return this.sendCampaign(claimed, adminId, kind);
  }

  private async sendCampaign(o: Offer, adminId: string | null, kind: 'publish' | 'resend') {
    const [campaign] = await this.db.insert(campaigns).values({ offerId: o.id, triggeredBy: adminId, kind }).returning();
    // MVP audience: all active registered customers (spec §12.4).
    const audience = await this.db.select({ id: users.id }).from(users).where(eq(users.accountStatus, 'active'));
    const stats = await this.notifications.notifyUsers(
      audience.map((u) => u.id),
      {
        type: 'offer',
        titleAr: o.titleAr,
        titleEn: o.titleEn,
        bodyAr: o.descriptionAr.slice(0, 140),
        bodyEn: o.descriptionEn.slice(0, 140),
        imageUrl: o.imageUrl,
        deepLink: `zaad://offers/${o.id}`,
        offerId: o.id,
        campaignId: campaign.id,
      },
    );
    await this.db.update(campaigns).set(stats).where(eq(campaigns.id, campaign.id));
    return { campaignId: campaign.id, ...stats };
  }

  async adminList() {
    const rows = await this.db.select().from(offers).orderBy(desc(offers.createdAt)).limit(200);
    return rows.map((o) => this.adminView(o));
  }

  async campaignStats() {
    return this.db
      .select({
        id: campaigns.id,
        offerId: campaigns.offerId,
        kind: campaigns.kind,
        createdAt: campaigns.createdAt,
        recipients: campaigns.recipients,
        providerAccepted: campaigns.providerAccepted,
        providerFailed: campaigns.providerFailed,
        opened: sql<number>`(select count(*)::int from notifications n where n.campaign_id = ${campaigns.id} and n.opened_at is not null)`,
      })
      .from(campaigns)
      .orderBy(desc(campaigns.createdAt))
      .limit(100);
  }

  private adminView(o: Offer) {
    return { ...customerView(o), status: effectiveStatus(o), storedStatus: o.status, publishedAt: o.publishedAt, notificationDispatchedAt: o.notificationDispatchedAt, createdBy: o.createdBy };
  }
}
