import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { and, desc, eq, ne, sql } from 'drizzle-orm';
import { AppError } from '../common/errors';
import { DB, Db } from '../db/db.module';
import { redemptionRequests } from '../db/schema';
import { ErpAdapter } from '../erp/erp.adapter';
import { ErpDecisionRejectedError, ErpNotConfiguredError, ErpRedemptionRequest, ErpUnavailableError } from '../erp/erp.types';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BalanceCache } from '../customer/balance-cache';

type Row = typeof redemptionRequests.$inferSelect;

export function toView(r: Row) {
  const expired = r.status === 'pending' && r.expiresAt.getTime() <= Date.now();
  return {
    id: r.id,
    reference: r.erpRequestId,
    branchName: r.branchName,
    points: r.pointsRequested,
    discountAmount: Number(r.discountAmount),
    currency: r.currency,
    status: expired ? ('expired' as const) : r.status,
    expiresAt: r.expiresAt.toISOString(),
    createdAt: r.createdAt.toISOString(),
    customerDecision: r.customerDecision,
    customerDecisionAt: r.customerDecisionAt?.toISOString() ?? null,
    completedAt: r.erpCompletedAt?.toISOString() ?? null,
  };
}

/**
 * Redemption workflow (spec §10). The backend:
 *   - mirrors ERP requests for audit, deep links and idempotency;
 *   - forwards the customer's decision with an idempotency key;
 *   - NEVER deducts points. The ERP validates expiry + live balance and finalizes.
 */
@Injectable()
export class RedemptionService {
  private readonly logger = new Logger(RedemptionService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly erp: ErpAdapter,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
    private readonly balanceCache: BalanceCache,
  ) {}

  private erpError(err: unknown): never {
    if (err instanceof ErpUnavailableError) throw new AppError('ERP_UNAVAILABLE', HttpStatus.SERVICE_UNAVAILABLE);
    if (err instanceof ErpNotConfiguredError) throw new AppError('ERP_NOT_CONFIGURED', HttpStatus.SERVICE_UNAVAILABLE, err.message);
    throw err;
  }

  /**
   * Upserts an ERP request into the mirror. Returns the row and whether it is new.
   * Called by the pending-list pull today and by the webhook receiver once the ERP supports one.
   */
  async ingest(userId: string, r: ErpRedemptionRequest): Promise<{ row: Row; isNew: boolean }> {
    const inserted = await this.db
      .insert(redemptionRequests)
      .values({
        erpRequestId: r.erpRequestId,
        userId,
        erpCustomerId: r.erpCustomerId,
        branchId: r.branchId,
        branchName: r.branchName,
        pointsRequested: r.points,
        discountAmount: r.discountAmount.toFixed(2),
        currency: r.currency,
        status: r.status,
        expiresAt: r.expiresAt,
        createdAt: r.createdAt,
      })
      .onConflictDoNothing({ target: redemptionRequests.erpRequestId })
      .returning();
    if (inserted[0]) {
      const row = inserted[0];
      await this.notifications.notifyUsers([userId], {
        type: 'redemption_request',
        titleAr: 'طلب استبدال نقاط',
        titleEn: 'Points redemption request',
        bodyAr: `${row.branchName}: ${row.pointsRequested} نقطة = ${Number(row.discountAmount)} ر.س. يرجى التأكيد أو الرفض.`,
        bodyEn: `${row.branchName}: ${row.pointsRequested} points = SAR ${Number(row.discountAmount)}. Please confirm or reject.`,
        deepLink: `zaad://redemptions/${row.id}`,
        redemptionId: row.id,
      });
      return { row, isNew: true };
    }
    const [row] = await this.db.select().from(redemptionRequests).where(eq(redemptionRequests.erpRequestId, r.erpRequestId));
    if (row.userId !== userId) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    return { row: await this.applyErpState(row, r), isNew: false };
  }

  private async applyErpState(row: Row, r: ErpRedemptionRequest): Promise<Row> {
    if (row.status === r.status) return row;
    const [updated] = await this.db
      .update(redemptionRequests)
      .set({ status: r.status, erpCompletedAt: r.completedAt ?? row.erpCompletedAt, updatedAt: new Date() })
      .where(eq(redemptionRequests.id, row.id))
      .returning();
    return updated;
  }

  /** Pending list always asks the ERP — push may never arrive (spec §13.3), so the app polls this. */
  async pending(userId: string, erpCustomerId: string) {
    let fromErp: ErpRedemptionRequest[];
    try {
      fromErp = await this.erp.listPendingRedemptions(erpCustomerId);
    } catch (err) {
      this.erpError(err);
    }
    const rows: Row[] = [];
    for (const r of fromErp) rows.push((await this.ingest(userId, r)).row);
    return rows.map(toView).filter((v) => v.status === 'pending');
  }

  async get(userId: string, id: string) {
    const [row] = await this.db.select().from(redemptionRequests).where(and(eq(redemptionRequests.id, id), eq(redemptionRequests.userId, userId)));
    if (!row) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    if (row.status === 'pending' || row.status === 'approved') {
      try {
        const latest = await this.erp.getRedemption(row.erpCustomerId, row.erpRequestId);
        if (latest) return toView(await this.applyErpState(row, latest));
      } catch (err) {
        if (!(err instanceof ErpUnavailableError)) this.erpError(err);
        // ERP down: return our last known state; the app marks it as "awaiting confirmation".
      }
    }
    return toView(row);
  }

  async history(userId: string) {
    const rows = await this.db.select().from(redemptionRequests).where(eq(redemptionRequests.userId, userId)).orderBy(desc(redemptionRequests.createdAt)).limit(50);
    return rows.map(toView);
  }

  async decide(userId: string, id: string, decision: 'approve' | 'reject', ip: string | null) {
    // Serialize concurrent taps / duplicate requests on the same row.
    const result = await this.db.transaction(async (tx) => {
      const [row] = await tx
        .select()
        .from(redemptionRequests)
        .where(and(eq(redemptionRequests.id, id), eq(redemptionRequests.userId, userId)))
        .for('update');
      if (!row) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);

      if (row.customerDecision) {
        if (row.customerDecision !== decision) {
          throw new AppError('REDEMPTION_ALREADY_DECIDED', HttpStatus.CONFLICT, 'A decision was already submitted', { request: toView(row) });
        }
        // Same decision again → fall through and replay with the SAME key (safe: ERP is idempotent on it).
      } else if (row.status !== 'pending') {
        throw new AppError('REDEMPTION_ALREADY_DECIDED', HttpStatus.CONFLICT, 'This request is no longer pending', { request: toView(row) });
      } else if (row.expiresAt.getTime() <= Date.now()) {
        await tx.update(redemptionRequests).set({ status: 'expired', updatedAt: new Date() }).where(eq(redemptionRequests.id, row.id));
        throw new AppError('REDEMPTION_EXPIRED', HttpStatus.GONE, 'This redemption request has expired');
      }

      const key = row.decisionIdempotencyKey ?? `${row.erpRequestId}:${decision}`;
      if (!row.customerDecision) {
        await tx
          .update(redemptionRequests)
          .set({ customerDecision: decision, customerDecisionAt: new Date(), decisionIdempotencyKey: key, updatedAt: new Date() })
          .where(eq(redemptionRequests.id, row.id));
      }
      return { row, key };
    });

    const { row, key } = result;
    this.balanceCache.invalidate(row.erpCustomerId);
    let erpResult: ErpRedemptionRequest;
    try {
      erpResult = await this.erp.submitRedemptionDecision(row.erpCustomerId, row.erpRequestId, decision, key);
    } catch (err) {
      if (err instanceof ErpDecisionRejectedError) {
        const status = err.reason === 'expired' ? 'expired' : err.current?.status ?? 'failed';
        const changed = await this.transition(row.id, status, { lastErpError: err.reason });
        if (err.reason === 'expired') throw new AppError('REDEMPTION_EXPIRED', HttpStatus.GONE, 'This redemption request has expired');
        if (changed) {
          await this.audit.log({ actorType: 'customer', actorId: userId, action: `redemption.${decision}.rejected_by_erp`, resourceType: 'redemption', resourceId: row.id, metadata: { reason: err.reason }, ipAddress: ip });
          await this.notifyFinal(changed);
        }
        return toView(changed ?? (await this.load(row.id)));
      }
      // Unknown outcome (timeout / ERP down). The decision is recorded; retrying reuses the same idempotency key.
      await this.db.update(redemptionRequests).set({ lastErpError: err instanceof Error ? err.message.slice(0, 200) : 'unknown', updatedAt: new Date() }).where(eq(redemptionRequests.id, row.id));
      this.logger.warn(`Redemption ${row.erpRequestId}: decision sent but ERP outcome unknown`);
      throw new AppError('REDEMPTION_DECISION_PENDING', HttpStatus.ACCEPTED, 'Decision recorded; waiting for ERP confirmation');
    }

    // Conditional transition: among concurrent/replayed requests exactly one wins and notifies.
    const changed = await this.transition(row.id, erpResult.status, { erpCompletedAt: erpResult.completedAt, lastErpError: null });
    if (changed) {
      await this.audit.log({ actorType: 'customer', actorId: userId, action: `redemption.${decision}`, resourceType: 'redemption', resourceId: row.id, metadata: { erpStatus: erpResult.status }, ipAddress: ip });
      await this.notifyFinal(changed);
    }
    return toView(changed ?? (await this.load(row.id)));
  }

  private async load(id: string): Promise<Row> {
    const [r] = await this.db.select().from(redemptionRequests).where(eq(redemptionRequests.id, id));
    return r;
  }

  /** Sets the status only if it differs; returns the row if THIS call changed it, otherwise null. */
  private async transition(id: string, status: Row['status'], extra: Partial<Row>): Promise<Row | null> {
    const [r] = await this.db
      .update(redemptionRequests)
      .set({ ...extra, status, updatedAt: new Date() })
      .where(and(eq(redemptionRequests.id, id), ne(redemptionRequests.status, status)))
      .returning();
    return r ?? null;
  }

  private async notifyFinal(row: Row) {
    const map = {
      completed: ['redemption_completed', 'تم استبدال النقاط', 'Redemption completed', `تم خصم ${row.pointsRequested} نقطة مقابل ${Number(row.discountAmount)} ر.س في ${row.branchName}.`, `${row.pointsRequested} points redeemed for SAR ${Number(row.discountAmount)} at ${row.branchName}.`],
      rejected: ['redemption_rejected', 'تم رفض طلب الاستبدال', 'Redemption rejected', 'لم يتم خصم أي نقاط.', 'No points were deducted.'],
      expired: ['redemption_expired', 'انتهت صلاحية طلب الاستبدال', 'Redemption request expired', 'لم يتم خصم أي نقاط.', 'No points were deducted.'],
      failed: ['redemption_rejected', 'تعذر إتمام الاستبدال', 'Redemption could not be completed', 'لم يتم خصم أي نقاط. يرجى مراجعة الكاشير.', 'No points were deducted. Please check with the cashier.'],
    } as const;
    const m = map[row.status as keyof typeof map];
    if (!m) return;
    await this.notifications.notifyUsers([row.userId], {
      type: m[0],
      titleAr: m[1],
      titleEn: m[2],
      bodyAr: m[3],
      bodyEn: m[4],
      deepLink: `zaad://redemptions/${row.id}`,
      redemptionId: row.id,
    });
  }

  /** Background sweep: mark locally expired requests (display only — ERP is authoritative). */
  async sweepExpired() {
    await this.db
      .update(redemptionRequests)
      .set({ status: 'expired', updatedAt: new Date() })
      .where(and(eq(redemptionRequests.status, 'pending'), sql`${redemptionRequests.expiresAt} <= now()`, sql`${redemptionRequests.customerDecision} is null`));
  }
}
