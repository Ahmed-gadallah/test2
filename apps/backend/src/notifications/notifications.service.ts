import { Inject, Injectable, Logger } from '@nestjs/common';
import { and, desc, eq, inArray, isNull, lt, sql } from 'drizzle-orm';
import { ENV, Env } from '../config/env';
import { DB, Db } from '../db/db.module';
import { deviceTokens, notifications, pushDeliveries, users } from '../db/schema';
import { ConsolePushSender, FcmPushSender, PushSender } from './push.provider';

export interface NotificationContent {
  type: (typeof notifications.$inferInsert)['type'];
  titleAr: string;
  titleEn: string;
  bodyAr: string;
  bodyEn: string;
  deepLink: string;
  imageUrl?: string | null;
  offerId?: string | null;
  campaignId?: string | null;
  redemptionId?: string | null;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly push: PushSender;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(ENV) env: Env,
  ) {
    this.push = env.PUSH_PROVIDER === 'fcm' ? new FcmPushSender() : new ConsolePushSender();
  }

  /**
   * Creates in-app records first (the source of truth for the notification center),
   * then attempts push. Push failure never loses the in-app record (spec §13.3).
   * With a campaignId, the (user, campaign) unique index makes re-runs no-ops.
   */
  async notifyUsers(userIds: string[], content: NotificationContent) {
    let recipients = 0;
    let accepted = 0;
    let failed = 0;
    for (let i = 0; i < userIds.length; i += 500) {
      const batch = userIds.slice(i, i + 500);
      const inserted = await this.db
        .insert(notifications)
        .values(batch.map((userId) => ({ userId, type: content.type, titleAr: content.titleAr, titleEn: content.titleEn, bodyAr: content.bodyAr, bodyEn: content.bodyEn, deepLink: content.deepLink, offerId: content.offerId ?? null, campaignId: content.campaignId ?? null, redemptionId: content.redemptionId ?? null })))
        .onConflictDoNothing()
        .returning({ id: notifications.id, userId: notifications.userId });
      recipients += inserted.length;
      if (inserted.length === 0) continue;

      const [langRows, tokens] = await Promise.all([
        this.db.select({ id: users.id, lang: users.preferredLanguage }).from(users).where(inArray(users.id, inserted.map((n) => n.userId))),
        this.db.select().from(deviceTokens).where(and(inArray(deviceTokens.userId, inserted.map((n) => n.userId)), eq(deviceTokens.active, true))),
      ]);
      const lang = new Map(langRows.map((r) => [r.id, r.lang]));
      for (const n of inserted) {
        const userTokens = tokens.filter((t) => t.userId === n.userId);
        if (userTokens.length === 0) continue;
        const en = lang.get(n.userId) === 'en';
        const results = await this.push.send(
          userTokens.map((t) => t.deviceToken),
          { title: en ? content.titleEn : content.titleAr, body: en ? content.bodyEn : content.bodyAr, imageUrl: content.imageUrl, deepLink: content.deepLink, notificationId: n.id },
        );
        await this.db.insert(pushDeliveries).values(
          results.map((r) => ({
            notificationId: n.id,
            deviceTokenId: userTokens.find((t) => t.deviceToken === r.token)!.id,
            status: r.status,
            providerMessageId: r.providerMessageId ?? null,
            error: r.error ?? null,
          })),
        );
        const invalid = results.filter((r) => r.status === 'invalid_token').map((r) => r.token);
        if (invalid.length) await this.db.update(deviceTokens).set({ active: false }).where(inArray(deviceTokens.deviceToken, invalid));
        accepted += results.filter((r) => r.status === 'accepted').length;
        failed += results.filter((r) => r.status !== 'accepted').length;
      }
    }
    this.logger.log(`Notification ${content.type}: ${recipients} in-app, push accepted=${accepted} failed=${failed}`);
    return { recipients, providerAccepted: accepted, providerFailed: failed };
  }

  async list(userId: string, before: Date | null, limit: number) {
    const rows = await this.db
      .select()
      .from(notifications)
      .where(before ? and(eq(notifications.userId, userId), lt(notifications.createdAt, before)) : eq(notifications.userId, userId))
      .orderBy(desc(notifications.createdAt))
      .limit(limit + 1);
    const items = rows.slice(0, limit);
    const [{ unread }] = await this.db
      .select({ unread: sql<number>`count(*)::int` })
      .from(notifications)
      .where(and(eq(notifications.userId, userId), isNull(notifications.readAt)));
    return { items, nextCursor: rows.length > limit ? items[items.length - 1].createdAt.toISOString() : null, unread };
  }

  async markRead(userId: string, id: string) {
    const [row] = await this.db
      .update(notifications)
      .set({ readAt: sql`coalesce(${notifications.readAt}, now())`, openedAt: sql`coalesce(${notifications.openedAt}, now())` })
      .where(and(eq(notifications.id, id), eq(notifications.userId, userId)))
      .returning({ id: notifications.id });
    return !!row;
  }

  async markAllRead(userId: string) {
    await this.db.update(notifications).set({ readAt: new Date() }).where(and(eq(notifications.userId, userId), isNull(notifications.readAt)));
  }

  async registerDevice(userId: string, token: string, platform: 'android' | 'ios' | 'web') {
    // A token belongs to one user at a time (device handed over / re-login as someone else).
    await this.db
      .insert(deviceTokens)
      .values({ userId, deviceToken: token, platform })
      .onConflictDoUpdate({ target: deviceTokens.deviceToken, set: { userId, platform, active: true, updatedAt: new Date() } });
  }

  async removeDevice(userId: string, token: string) {
    await this.db.update(deviceTokens).set({ active: false, updatedAt: new Date() }).where(and(eq(deviceTokens.userId, userId), eq(deviceTokens.deviceToken, token)));
  }
}
