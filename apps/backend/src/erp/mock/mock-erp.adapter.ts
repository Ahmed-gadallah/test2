import { randomUUID } from 'node:crypto';
import { ErpAdapter } from '../erp.adapter';
import {
  ErpCustomer,
  ErpDecisionRejectedError,
  ErpInvoiceDetail,
  ErpInvoiceLine,
  ErpInvoiceStatus,
  ErpInvoiceSummary,
  ErpPointsBalance,
  ErpPointsEntry,
  ErpRedemptionRequest,
  ErpUnavailableError,
  Page,
} from '../erp.types';

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  MOCK ERP — DEVELOPMENT / DEMO ONLY. Refused at startup when NODE_ENV=production.
 * ─────────────────────────────────────────────────────────────────────────────
 * This class pretends to be the ERP. The arithmetic below (deducting points on
 * an approved redemption) simulates what the REAL ERP does; the app backend
 * itself never performs these calculations. All names, numbers and branches
 * are fictional. No real customer data is used.
 *
 * Demo accounts (all OTPs are logged to the console in dev):
 *   +966500000001  regular customer, 2,500 pts, 34 invoices across branches
 *   +966500000002  customer with 0 points and no invoices (empty states)
 *   +966500000003  TWO ERP records share this mobile → registration needs support
 *   +966500000004  institutional account → not eligible for the app
 */

const BRANCHES = [
  { id: 'B01', name: 'زاد — فرع النخيل (تجريبي)' },
  { id: 'B02', name: 'زاد — فرع الربوة (تجريبي)' },
  { id: 'B03', name: 'زاد — فرع الملقا (تجريبي)' },
  { id: 'B04', name: 'زاد — فرع السلي (تجريبي)' },
];

const PRODUCTS = [
  { name: 'Paracetamol 500mg 24 Tab', price: 9.5 },
  { name: 'Vitamin D3 1000IU 60 Cap', price: 42 },
  { name: 'Omega 3 Fish Oil 90 Softgel', price: 79 },
  { name: 'Baby Diapers Size 4 (44)', price: 65.25 },
  { name: 'Sunscreen SPF50 50ml', price: 88 },
  { name: 'Hand Sanitizer 500ml', price: 18.75 },
  { name: 'Multivitamin Kids Syrup 150ml', price: 36.5 },
  { name: 'Moisturizing Cream 200ml', price: 54 },
  { name: 'Ibuprofen 400mg 20 Tab', price: 12.25 },
  { name: 'Toothpaste Sensitive 75ml', price: 21 },
];

interface MockCustomerState {
  customer: ErpCustomer;
  points: number;
  ledger: ErpPointsEntry[];
  invoices: ErpInvoiceDetail[];
}

/** Small deterministic PRNG so the demo data is stable between restarts. */
function rng(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

const round2 = (n: number) => Math.round(n * 100) / 100;

export class MockErpAdapter extends ErpAdapter {
  readonly name = 'mock';
  private readonly customers = new Map<string, MockCustomerState>();
  private readonly redemptions = new Map<string, ErpRedemptionRequest>();
  private readonly decisions = new Map<string, ErpRedemptionRequest>();
  /** Toggle to demo/test the "ERP unavailable" path. */
  public simulateOutage = false;

  constructor(private readonly pointsPerSar = 50) {
    super();
    this.seed();
  }

  // ── Seed ──────────────────────────────────────────────────────────────────
  private seed() {
    this.addCustomer({ erpCustomerId: '900001', name: 'محمد عبدالله', mobileNumber: '+966500000001', eligibleForApp: true }, 34, 2500, 7);
    this.addCustomer({ erpCustomerId: '900002', name: 'سارة أحمد', mobileNumber: '+966500000002', eligibleForApp: true }, 0, 0, 11);
    this.addCustomer({ erpCustomerId: '900003', name: 'خالد', mobileNumber: '+966500000003', eligibleForApp: true }, 2, 120, 13);
    this.addCustomer({ erpCustomerId: '900013', name: 'خالد م', mobileNumber: '+966500000003', eligibleForApp: true }, 1, 40, 17);
    this.addCustomer({ erpCustomerId: '900004', name: 'Insurance Co. (demo)', mobileNumber: '+966500000004', eligibleForApp: false }, 3, 1_000_000, 19);
  }

  private addCustomer(customer: ErpCustomer, invoiceCount: number, finalBalance: number, seed: number) {
    const rand = rng(seed);
    const invoices: ErpInvoiceDetail[] = [];
    const ledger: ErpPointsEntry[] = [];
    const now = Date.now();
    let earnedTotal = 0;

    for (let i = 0; i < invoiceCount; i++) {
      const branch = BRANCHES[Math.floor(rand() * BRANCHES.length)];
      const issuedAt = new Date(now - (invoiceCount - i) * 3.7 * 86_400_000 - Math.floor(rand() * 36_000_000));
      const lineCount = 1 + Math.floor(rand() * 4);
      const lines: ErpInvoiceLine[] = [];
      for (let l = 0; l < lineCount; l++) {
        const p = PRODUCTS[Math.floor(rand() * PRODUCTS.length)];
        const quantity = 1 + Math.floor(rand() * 2);
        const discount = rand() < 0.3 ? round2(p.price * quantity * 0.1) : 0;
        const net = round2(p.price * quantity - discount);
        const tax = round2(net * 0.15);
        lines.push({ name: p.name, quantity, unitPrice: p.price, discount: discount || null, pointsDiscount: null, tax, lineTotal: round2(net + tax) });
      }
      const subTotal = round2(lines.reduce((s, l) => s + l.unitPrice * l.quantity, 0));
      const discountTotal = round2(lines.reduce((s, l) => s + (l.discount ?? 0), 0));
      const taxTotal = round2(lines.reduce((s, l) => s + (l.tax ?? 0), 0));
      const total = round2(lines.reduce((s, l) => s + l.lineTotal, 0));
      const status: ErpInvoiceStatus = i === invoiceCount - 3 ? 'refunded' : i === invoiceCount - 6 ? 'partially_refunded' : 'finished';
      const pointsEarned = Math.floor(total); // what the mock "ERP" reports
      const id = `${customer.erpCustomerId}-${1000 + i}`;
      const invoiceNumber = String(1_650_000 + Number(customer.erpCustomerId.slice(-2)) * 1000 + i);
      const payments = ['cash', 'card', 'cash_and_card'] as const;

      invoices.push({
        invoiceId: id,
        invoiceNumber,
        issuedAt,
        branchId: branch.id,
        branchName: branch.name,
        total,
        currency: 'SAR',
        status,
        lines,
        subTotal,
        discountTotal: discountTotal || null,
        voucherDiscount: null,
        pointsUsed: null,
        pointsValue: null,
        taxTotal,
        pointsEarned,
        paymentMethod: i % 5 === 4 ? null : payments[Math.floor(rand() * 3)],
      });
      earnedTotal += pointsEarned;
      ledger.push({
        id: randomUUID(),
        occurredAt: issuedAt,
        type: 'earned',
        pointsDelta: pointsEarned,
        balanceAfter: null,
        invoiceId: id,
        invoiceNumber,
        branchName: branch.name,
        description: null,
      });
      if (status !== 'finished') {
        const deducted = status === 'refunded' ? pointsEarned : Math.floor(pointsEarned / 2);
        earnedTotal -= deducted;
        ledger.push({
          id: randomUUID(),
          occurredAt: new Date(issuedAt.getTime() + 2 * 86_400_000),
          type: 'refund_adjustment',
          pointsDelta: -deducted,
          balanceAfter: null,
          invoiceId: id,
          invoiceNumber,
          branchName: branch.name,
          description: status === 'refunded' ? 'Invoice refunded' : 'Invoice partially refunded',
        });
      }
    }
    // Reconcile to the desired final balance with one historic redemption / manual adjustment.
    const diff = finalBalance - earnedTotal;
    if (diff !== 0 && invoices.length > 0) {
      const at = new Date(invoices[Math.floor(invoices.length / 2)].issuedAt.getTime() + 3_600_000);
      ledger.push({
        id: randomUUID(),
        occurredAt: at,
        type: diff < 0 ? 'redeemed' : 'manual_adjustment',
        pointsDelta: diff,
        balanceAfter: null,
        invoiceId: diff < 0 ? invoices[Math.floor(invoices.length / 2)].invoiceId : null,
        invoiceNumber: diff < 0 ? invoices[Math.floor(invoices.length / 2)].invoiceNumber : null,
        branchName: diff < 0 ? invoices[Math.floor(invoices.length / 2)].branchName : null,
        description: diff < 0 ? null : 'Opening balance adjustment',
      });
    }
    ledger.sort((a, b) => a.occurredAt.getTime() - b.occurredAt.getTime());
    let running = 0;
    for (const e of ledger) {
      running += e.pointsDelta;
      e.balanceAfter = running;
    }
    ledger.reverse();
    invoices.reverse();
    this.customers.set(customer.erpCustomerId, { customer, points: finalBalance, ledger, invoices });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  private guard() {
    if (this.simulateOutage) throw new ErpUnavailableError('Simulated ERP outage');
  }

  private state(erpCustomerId: string): MockCustomerState | undefined {
    return this.customers.get(erpCustomerId);
  }

  private page<T>(all: T[], cursor: string | null, limit: number): Page<T> {
    const start = cursor ? Number(cursor) : 0;
    const items = all.slice(start, start + limit);
    const next = start + limit < all.length ? String(start + limit) : null;
    return { items, nextCursor: next };
  }

  private refreshExpiry(r: ErpRedemptionRequest): ErpRedemptionRequest {
    if (r.status === 'pending' && r.expiresAt.getTime() <= Date.now()) r.status = 'expired';
    return r;
  }

  // ── ErpAdapter ────────────────────────────────────────────────────────────
  async findCustomersByMobile(e164: string): Promise<ErpCustomer[]> {
    this.guard();
    return [...this.customers.values()].filter((s) => s.customer.mobileNumber === e164).map((s) => ({ ...s.customer }));
  }

  async getCustomer(erpCustomerId: string): Promise<ErpCustomer | null> {
    this.guard();
    const s = this.state(erpCustomerId);
    return s ? { ...s.customer } : null;
  }

  async getPointsBalance(erpCustomerId: string): Promise<ErpPointsBalance> {
    this.guard();
    return { points: this.state(erpCustomerId)?.points ?? 0, asOf: new Date() };
  }

  async getPointsHistory(erpCustomerId: string, cursor: string | null, limit: number): Promise<Page<ErpPointsEntry>> {
    this.guard();
    return this.page(this.state(erpCustomerId)?.ledger ?? [], cursor, limit);
  }

  async listInvoices(erpCustomerId: string, cursor: string | null, limit: number): Promise<Page<ErpInvoiceSummary>> {
    this.guard();
    const all = this.state(erpCustomerId)?.invoices ?? [];
    const p = this.page(all, cursor, limit);
    return {
      nextCursor: p.nextCursor,
      items: p.items.map(({ invoiceId, invoiceNumber, issuedAt, branchId, branchName, total, currency, status }) => ({
        invoiceId, invoiceNumber, issuedAt, branchId, branchName, total, currency, status,
      })),
    };
  }

  async getInvoice(erpCustomerId: string, invoiceId: string): Promise<ErpInvoiceDetail | null> {
    this.guard();
    return this.state(erpCustomerId)?.invoices.find((i) => i.invoiceId === invoiceId) ?? null;
  }

  async listPendingRedemptions(erpCustomerId: string): Promise<ErpRedemptionRequest[]> {
    this.guard();
    return [...this.redemptions.values()]
      .map((r) => this.refreshExpiry(r))
      .filter((r) => r.erpCustomerId === erpCustomerId && r.status === 'pending')
      .map((r) => ({ ...r }));
  }

  async getRedemption(erpCustomerId: string, erpRequestId: string): Promise<ErpRedemptionRequest | null> {
    this.guard();
    const r = this.redemptions.get(erpRequestId);
    if (!r || r.erpCustomerId !== erpCustomerId) return null;
    return { ...this.refreshExpiry(r) };
  }

  async submitRedemptionDecision(
    erpCustomerId: string,
    erpRequestId: string,
    decision: 'approve' | 'reject',
    idempotencyKey: string,
  ): Promise<ErpRedemptionRequest> {
    this.guard();
    const replay = this.decisions.get(idempotencyKey);
    if (replay) return { ...replay };

    const r = this.redemptions.get(erpRequestId);
    if (!r || r.erpCustomerId !== erpCustomerId) throw new ErpDecisionRejectedError('not_found');
    this.refreshExpiry(r);
    if (r.status === 'expired') throw new ErpDecisionRejectedError('expired', { ...r });
    if (r.status !== 'pending') throw new ErpDecisionRejectedError('already_decided', { ...r });

    const s = this.state(erpCustomerId)!;
    if (decision === 'reject') {
      r.status = 'rejected';
    } else {
      // The REAL ERP validates the live balance and deducts. Simulated here.
      if (s.points < r.points) {
        r.status = 'failed';
        this.decisions.set(idempotencyKey, { ...r });
        throw new ErpDecisionRejectedError('insufficient_balance', { ...r });
      }
      s.points -= r.points;
      r.status = 'completed';
      r.completedAt = new Date();
      s.ledger.unshift({
        id: randomUUID(),
        occurredAt: r.completedAt,
        type: 'redeemed',
        pointsDelta: -r.points,
        balanceAfter: s.points,
        invoiceId: null,
        invoiceNumber: null,
        branchName: r.branchName,
        description: `Redemption ${r.erpRequestId}`,
      });
    }
    this.decisions.set(idempotencyKey, { ...r });
    return { ...r };
  }

  // ── Dev-only simulation hooks (exposed via /api/v1/dev when the mock is active) ──
  /** Simulates the cashier starting a redemption at the POS. */
  simulateCashierRequest(erpCustomerId: string, points: number, ttlSeconds: number, branchIndex = 0): ErpRedemptionRequest {
    const s = this.state(erpCustomerId);
    if (!s) throw new Error('Unknown mock customer');
    const sar = Math.floor(points / this.pointsPerSar);
    const normalizedPoints = sar * this.pointsPerSar; // POS redeems whole SAR only (verified in ERP data)
    if (normalizedPoints <= 0) throw new Error(`Minimum is ${this.pointsPerSar} points (1 SAR)`);
    const branch = BRANCHES[branchIndex % BRANCHES.length];
    const now = new Date();
    const req: ErpRedemptionRequest = {
      erpRequestId: `RR-${now.getTime().toString(36).toUpperCase()}`,
      erpCustomerId,
      branchId: branch.id,
      branchName: branch.name,
      points: normalizedPoints,
      discountAmount: sar,
      currency: 'SAR',
      status: 'pending',
      createdAt: now,
      expiresAt: new Date(now.getTime() + ttlSeconds * 1000),
      completedAt: null,
    };
    this.redemptions.set(req.erpRequestId, req);
    return { ...req };
  }
}
