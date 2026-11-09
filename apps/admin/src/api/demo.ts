/**
 * DEMO DATA SOURCE — fictional data for showing the dashboard without a backend.
 * Mirrors the backend's rules (role permissions, offer lifecycle, one notification per publish,
 * explicit resend, read-only customer data) so the demo behaves like the real thing.
 * Demo accounts (password: Demo12345678):
 *   super@zaad.demo · marketing@zaad.demo · support@zaad.demo
 */
import type {
  Admin,
  AdminApi,
  AuditEntry,
  Branch,
  BranchInput,
  CampaignStat,
  CustomerResult,
  InvoiceDetail,
  Offer,
  OfferInput,
  OfferStatus,
  PointsEntry,
  Redemption,
  Role,
} from './types';
import { ApiError } from './types';
// Generated from the real branches sheet by the backend (`npm run export:branches-demo`), same parser as the import.
import demoBranches from './demo-branches.json';

const DAY = 86_400_000;
const now = () => Date.now();
const iso = (t: number) => new Date(t).toISOString();
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2));
const wait = () => new Promise((r) => setTimeout(r, 220 + Math.random() * 200));

const BRANCHES = ['زاد — فرع النخيل (تجريبي)', 'زاد — فرع الربوة (تجريبي)', 'زاد — فرع الملقا (تجريبي)', 'زاد — فرع السلي (تجريبي)'];
const PRODUCTS: [string, number][] = [
  ['Paracetamol 500mg 24 Tab', 9.5],
  ['Vitamin D3 1000IU 60 Cap', 42],
  ['Omega 3 Fish Oil 90 Softgel', 79],
  ['Baby Diapers Size 4 (44)', 65.25],
  ['Sunscreen SPF50 50ml', 88],
  ['Hand Sanitizer 500ml', 18.75],
];

function rng(seed: number) {
  let s = seed;
  return () => ((s = (s * 1664525 + 1013904223) % 4294967296) / 4294967296);
}
const r2 = (n: number) => Math.round(n * 100) / 100;

interface DemoCustomer {
  c: CustomerResult;
  points: number;
  ledger: PointsEntry[];
  invoices: InvoiceDetail[];
}

function makeCustomer(id: string, name: string, mobile: string, count: number, balance: number, seed: number, registered: boolean, eligible = true): DemoCustomer {
  const rand = rng(seed);
  const invoices: InvoiceDetail[] = [];
  const ledger: PointsEntry[] = [];
  let earned = 0;
  for (let i = 0; i < count; i++) {
    const at = now() - (count - i) * 3.7 * DAY;
    const branch = BRANCHES[Math.floor(rand() * BRANCHES.length)];
    const lines = Array.from({ length: 1 + Math.floor(rand() * 3) }, () => {
      const [n, p] = PRODUCTS[Math.floor(rand() * PRODUCTS.length)];
      const q = 1 + Math.floor(rand() * 2);
      return { name: n, quantity: q, unitPrice: p, discount: null, lineTotal: r2(p * q * 1.15) };
    });
    const total = r2(lines.reduce((s, l) => s + l.lineTotal, 0));
    const status = i === count - 3 ? 'refunded' : 'finished';
    const pts = Math.floor(total);
    const number = String(1650000 + Number(id.slice(-2)) * 1000 + i);
    invoices.push({
      invoiceId: `${id}-${1000 + i}`, invoiceNumber: number, issuedAt: iso(at), branchName: branch, total, status,
      lines, subTotal: r2(lines.reduce((s, l) => s + l.unitPrice * l.quantity, 0)), discountTotal: null, taxTotal: r2(total - total / 1.15),
      pointsEarned: pts, paymentMethod: (['cash', 'card', 'cash_and_card'] as const)[i % 3],
    });
    earned += pts;
    ledger.push({ id: uid(), occurredAt: iso(at), type: 'earned', pointsDelta: pts, balanceAfter: null, invoiceNumber: number, branchName: branch });
    if (status === 'refunded') {
      earned -= pts;
      ledger.push({ id: uid(), occurredAt: iso(at + 2 * DAY), type: 'refund_adjustment', pointsDelta: -pts, balanceAfter: null, invoiceNumber: number, branchName: branch });
    }
  }
  const diff = balance - earned;
  if (diff !== 0 && invoices.length) {
    ledger.push({ id: uid(), occurredAt: iso(now() - 20 * DAY), type: diff < 0 ? 'redeemed' : 'manual_adjustment', pointsDelta: diff, balanceAfter: null, invoiceNumber: null, branchName: diff < 0 ? BRANCHES[0] : null });
  }
  ledger.sort((a, b) => a.occurredAt.localeCompare(b.occurredAt));
  let run = 0;
  for (const e of ledger) e.balanceAfter = run += e.pointsDelta;
  return {
    c: { erpCustomerId: id, name, mobileNumber: mobile, eligibleForApp: eligible, appAccount: registered ? { status: 'active', createdAt: iso(now() - 12 * DAY) } : null },
    points: balance,
    ledger: ledger.reverse(),
    invoices: invoices.reverse(),
  };
}

function effective(o: Offer): OfferStatus {
  if (o.storedStatus === 'draft' || o.storedStatus === 'archived') return o.storedStatus;
  const t = now();
  if (Date.parse(o.endAt) <= t) return 'expired';
  if (Date.parse(o.startAt) > t) return 'scheduled';
  return 'active';
}

export class DemoAdminApi implements AdminApi {
  readonly demo = true;
  private me_: Admin | null = null;
  private readonly password = 'Demo12345678';
  private adminsList: Admin[] = [
    { id: uid(), name: 'مدير النظام', email: 'super@zaad.demo', role: 'super_admin', active: true, createdAt: iso(now() - 40 * DAY) },
    { id: uid(), name: 'فريق التسويق', email: 'marketing@zaad.demo', role: 'marketing_admin', active: true, createdAt: iso(now() - 30 * DAY) },
    { id: uid(), name: 'خدمة العملاء', email: 'support@zaad.demo', role: 'customer_support', active: true, createdAt: iso(now() - 25 * DAY) },
  ];
  private customers: DemoCustomer[] = [
    makeCustomer('900001', 'محمد عبدالله', '+966500000001', 34, 2500, 7, true),
    makeCustomer('900002', 'سارة أحمد', '+966500000002', 0, 0, 11, true),
    makeCustomer('900003', 'خالد', '+966500000003', 2, 120, 13, false),
    makeCustomer('900013', 'خالد م', '+966500000003', 1, 40, 17, false),
    makeCustomer('900004', 'Insurance Co. (demo)', '+966500000004', 3, 1_000_000, 19, false, false),
  ];
  private registered = 1248;
  private offersList: Offer[];
  private campaignList: CampaignStat[] = [];
  private audit: AuditEntry[] = [];
  private redemptionList: Redemption[];
  private branchList: Branch[] = (demoBranches as Branch[]).map((b) => ({ ...b }));

  constructor() {
    const mk = (titleAr: string, titleEn: string, dAr: string, dEn: string, start: number, end: number, stored: OfferStatus, published: boolean): Offer => {
      const o: Offer = {
        id: uid(), titleAr, titleEn, descriptionAr: dAr, descriptionEn: dEn, startAt: iso(now() + start * DAY), endAt: iso(now() + end * DAY),
        status: stored, storedStatus: stored, publishedAt: published ? iso(now() + start * DAY) : null, notificationDispatchedAt: published && start <= 0 ? iso(now() + start * DAY) : null,
        destinationUrl: 'https://zaadonline.com', ctaLabelAr: 'تسوّق الآن', ctaLabelEn: 'Shop now',
      };
      o.status = effective(o);
      return o;
    };
    this.offersList = [
      mk('خصم 20% على الفيتامينات والمكملات', '20% off vitamins & supplements', 'استمتع بخصم 20% على جميع الفيتامينات والمكملات الغذائية في جميع فروع زاد.', 'Enjoy 20% off all vitamins and supplements at every Zaad branch.', -2, 12, 'active', true),
      mk('نقاط مضاعفة على العناية بالبشرة', 'Double points on skincare', 'اكسب ضعف النقاط على منتجات العناية بالبشرة المشاركة.', 'Earn double points on participating skincare products.', -1, 6, 'active', true),
      mk('عروض اليوم الوطني', 'National Day offers', 'خصومات خاصة بمناسبة اليوم الوطني.', 'Special National Day discounts.', 5, 15, 'scheduled', true),
      mk('عروض الشتاء', 'Winter deals', 'مسودة — بانتظار المراجعة.', 'Draft — pending review.', 10, 40, 'draft', false),
      mk('عروض العودة للمدارس', 'Back-to-school deals', 'خصومات على مستلزمات العناية بالأطفال.', 'Discounts on kids care essentials.', -40, -10, 'active', true),
    ];
    for (const o of this.offersList.filter((x) => x.notificationDispatchedAt)) {
      const recipients = 1100 + Math.floor(Math.random() * 120);
      const accepted = recipients - Math.floor(Math.random() * 25);
      this.campaignList.push({ id: uid(), offerId: o.id, kind: 'publish', createdAt: o.notificationDispatchedAt!, recipients, providerAccepted: accepted, providerFailed: recipients - accepted, opened: Math.floor(accepted * (0.18 + Math.random() * 0.2)) });
    }
    const st: Redemption['status'][] = ['completed', 'completed', 'rejected', 'completed', 'expired', 'completed', 'failed', 'pending'];
    this.redemptionList = st.map((status, i) => ({
      id: uid(), reference: `RR-${(Date.now() - i * 3_600_000).toString(36).toUpperCase().slice(-6)}`, branchName: BRANCHES[i % 4],
      points: [1000, 500, 1500, 250, 750, 2000, 5000, 1000][i], discountAmount: [20, 10, 30, 5, 15, 40, 100, 20][i], status,
      createdAt: iso(now() - i * 5 * 3_600_000), expiresAt: iso(now() - i * 5 * 3_600_000 + 120_000),
      customerDecision: status === 'completed' || status === 'failed' ? 'approve' : status === 'rejected' ? 'reject' : null,
      completedAt: status === 'completed' ? iso(now() - i * 5 * 3_600_000 + 40_000) : null,
      erpCustomerId: ['900001', '900002'][i % 2], lastErpError: status === 'failed' ? 'insufficient_balance' : null,
    }));
    this.log('system', null, 'registration.blocked_duplicate_erp_match', 'mobile', '+9665******03');
    this.log('admin', this.adminsList[1].id, 'offer.published', 'offer', this.offersList[0].id);
    this.log('admin', this.adminsList[2].id, 'customer.search', 'customer', null);
  }

  // ── helpers ──
  private log(actorType: string, actorId: string | null, action: string, resourceType: string, resourceId: string | null, metadata: Record<string, unknown> | null = null) {
    this.audit.unshift({ id: uid(), actorType, actorId, action, resourceType, resourceId, metadata, ipAddress: actorType === 'admin' ? '10.0.0.12' : null, createdAt: iso(now()) });
  }
  private need(...roles: Role[]) {
    if (!this.me_) throw new ApiError('UNAUTHENTICATED', 401);
    if (!roles.includes(this.me_.role)) throw new ApiError('FORBIDDEN', 403);
    return this.me_;
  }
  private offer(id: string) {
    const o = this.offersList.find((x) => x.id === id);
    if (!o) throw new ApiError('NOT_FOUND', 404);
    return o;
  }
  private customer(id: string) {
    const c = this.customers.find((x) => x.c.erpCustomerId === id);
    if (!c) throw new ApiError('NOT_FOUND', 404);
    return c;
  }
  private sendCampaign(o: Offer, kind: 'publish' | 'resend') {
    const recipients = this.registered;
    const accepted = recipients - Math.floor(Math.random() * 15);
    const c: CampaignStat = { id: uid(), offerId: o.id, kind, createdAt: iso(now()), recipients, providerAccepted: accepted, providerFailed: recipients - accepted, opened: 0 };
    this.campaignList.unshift(c);
    return c;
  }
  private refresh() {
    for (const o of this.offersList) {
      // scheduled offers go live (and notify) when their start time arrives — like the backend dispatcher
      if (o.storedStatus === 'scheduled' && Date.parse(o.startAt) <= now() && !o.notificationDispatchedAt) {
        o.storedStatus = 'active';
        o.notificationDispatchedAt = iso(now());
        this.sendCampaign(o, 'publish');
      }
      o.status = effective(o);
    }
  }

  // ── AdminApi ──
  async login(email: string, password: string) {
    await wait();
    const a = this.adminsList.find((x) => x.email.toLowerCase() === email.trim().toLowerCase());
    if (!a || password !== this.password || !a.active) throw new ApiError('INVALID_CREDENTIALS', 401);
    this.me_ = a;
    this.log('admin', a.id, 'admin.login', 'admin', a.id);
    return { accessToken: `demo-${a.id}`, admin: a };
  }
  restore(token: string) {
    this.me_ = this.adminsList.find((a) => `demo-${a.id}` === token) ?? null;
  }
  async me() { await wait(); return this.need('super_admin', 'marketing_admin', 'customer_support'); }
  async dashboard() {
    await wait();
    this.need('super_admin', 'marketing_admin', 'customer_support');
    this.refresh();
    return {
      registeredCustomers: this.registered,
      newCustomers7d: 86,
      redemptionsPending: this.redemptionList.filter((r) => r.status === 'pending').length,
      redemptionsCompleted: this.redemptionList.filter((r) => r.status === 'completed').length,
      offersActive: this.offersList.filter((o) => o.status === 'active').length,
      offersScheduled: this.offersList.filter((o) => o.status === 'scheduled').length,
      offersDraft: this.offersList.filter((o) => o.status === 'draft').length,
    };
  }

  async offers() { await wait(); this.need('super_admin', 'marketing_admin'); this.refresh(); return this.offersList.map((o) => ({ ...o })); }
  async createOffer(input: OfferInput) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    if (Date.parse(input.endAt) <= Date.parse(input.startAt)) throw new ApiError('VALIDATION_FAILED', 400, 'endAt must be after startAt');
    const o: Offer = { ...input, id: uid(), status: 'draft', storedStatus: 'draft', publishedAt: null, notificationDispatchedAt: null };
    this.offersList.unshift(o);
    this.log('admin', me.id, 'offer.created', 'offer', o.id);
    return { ...o };
  }
  async updateOffer(id: string, input: Partial<OfferInput>) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    const o = this.offer(id);
    if (o.storedStatus === 'archived') throw new ApiError('OFFER_INVALID_STATE', 409);
    Object.assign(o, input);
    o.status = effective(o);
    this.log('admin', me.id, 'offer.updated', 'offer', id, { fields: Object.keys(input) });
    return { ...o }; // edits never re-send notifications
  }
  async publishOffer(id: string) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    const o = this.offer(id);
    if (o.storedStatus !== 'draft') throw new ApiError('OFFER_INVALID_STATE', 409);
    if (Date.parse(o.endAt) <= now()) throw new ApiError('OFFER_INVALID_STATE', 409, 'Offer end date is in the past');
    o.publishedAt = iso(now());
    if (Date.parse(o.startAt) > now()) o.storedStatus = 'scheduled';
    else {
      o.storedStatus = 'active';
      o.notificationDispatchedAt = iso(now());
      this.sendCampaign(o, 'publish');
    }
    o.status = effective(o);
    this.log('admin', me.id, 'offer.published', 'offer', id);
    return { ...o };
  }
  async archiveOffer(id: string) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    const o = this.offer(id);
    o.storedStatus = 'archived';
    o.status = 'archived';
    this.log('admin', me.id, 'offer.archived', 'offer', id);
    return { ...o };
  }
  async resendOffer(id: string) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    const o = this.offer(id);
    if (effective(o) !== 'active' || !o.notificationDispatchedAt) throw new ApiError('OFFER_INVALID_STATE', 409);
    const c = this.sendCampaign(o, 'resend');
    this.log('admin', me.id, 'offer.resend', 'offer', id);
    return { campaignId: c.id, recipients: c.recipients, providerAccepted: c.providerAccepted, providerFailed: c.providerFailed };
  }
  async campaigns() { await wait(); this.need('super_admin', 'marketing_admin'); return this.campaignList.map((c) => ({ ...c })); }

  async searchCustomers(q: { mobile?: string; customerId?: string }) {
    await wait();
    const me = this.need('super_admin', 'customer_support');
    let res: DemoCustomer[];
    if (q.customerId) res = this.customers.filter((c) => c.c.erpCustomerId === q.customerId!.trim());
    else {
      const d = (q.mobile ?? '').replace(/\D/g, '');
      if (d.length < 9) throw new ApiError('INVALID_MOBILE', 400);
      res = this.customers.filter((c) => c.c.mobileNumber.endsWith(d.slice(-9)));
    }
    this.log('admin', me.id, 'customer.search', 'customer', null, { count: res.length });
    return res.map((c) => ({ ...c.c }));
  }
  async customerPoints(id: string, cursor?: string | null) {
    await wait();
    this.need('super_admin', 'customer_support');
    const c = this.customer(id);
    const start = Number(cursor ?? 0);
    const items = c.ledger.slice(start, start + 30);
    return { balance: { points: c.points, asOf: iso(now()) }, history: items, nextCursor: start + 30 < c.ledger.length ? String(start + 30) : null };
  }
  async customerInvoices(id: string, cursor?: string | null) {
    await wait();
    this.need('super_admin', 'customer_support');
    const c = this.customer(id);
    const start = Number(cursor ?? 0);
    return { items: c.invoices.slice(start, start + 20), nextCursor: start + 20 < c.invoices.length ? String(start + 20) : null };
  }
  async customerInvoice(id: string, invoiceId: string) {
    await wait();
    this.need('super_admin', 'customer_support');
    const inv = this.customer(id).invoices.find((i) => i.invoiceId === invoiceId);
    if (!inv) throw new ApiError('NOT_FOUND', 404);
    return inv;
  }

  async redemptions() { await wait(); this.need('super_admin', 'customer_support'); return this.redemptionList.map((r) => ({ ...r })); }
  async auditLogs() { await wait(); this.need('super_admin'); return this.audit.map((a) => ({ ...a })); }
  async admins() { await wait(); this.need('super_admin'); return this.adminsList.map((a) => ({ ...a })); }
  async createAdmin(input: { name: string; email: string; password: string; role: Role }) {
    await wait();
    const me = this.need('super_admin');
    if (this.adminsList.some((a) => a.email.toLowerCase() === input.email.toLowerCase())) throw new ApiError('ACCOUNT_EXISTS', 409);
    if (!/^(?=.*[A-Za-z])(?=.*\d).{12,128}$/.test(input.password)) throw new ApiError('VALIDATION_FAILED', 400, 'Admin password: 12+ chars with letters and digits');
    const a: Admin = { id: uid(), name: input.name, email: input.email, role: input.role, active: true, createdAt: iso(now()) };
    this.adminsList.push(a);
    this.log('admin', me.id, 'admin.created', 'admin', a.id, { role: a.role });
    return { ...a };
  }
  async updateAdmin(id: string, patch: { role?: Role; active?: boolean }) {
    await wait();
    const me = this.need('super_admin');
    if (id === me.id && (patch.active === false || (patch.role && patch.role !== 'super_admin'))) throw new ApiError('FORBIDDEN', 403, 'You cannot demote or deactivate your own account');
    const a = this.adminsList.find((x) => x.id === id);
    if (!a) throw new ApiError('NOT_FOUND', 404);
    Object.assign(a, patch);
    this.log('admin', me.id, 'admin.updated', 'admin', id, { ...patch });
    return { ...a };
  }

  // ── branches (same rules as the backend; the sheet import itself needs the real backend) ──
  async branches() { await wait(); this.need('super_admin', 'marketing_admin'); return this.branchList.map((b) => ({ ...b })); }
  async createBranch(input: BranchInput & { branchId: number }) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    if (this.branchList.some((b) => b.id === input.branchId)) throw new ApiError('VALIDATION_FAILED', 409, `Branch ID ${input.branchId} already exists`);
    const { branchId, ...rest } = input;
    const b: Branch = { id: branchId, ...cleanBranch(rest) } as Branch;
    this.branchList.push(b);
    this.log('admin', me.id, 'branch.create', 'branch', String(b.id));
    return { ...b };
  }
  async updateBranch(id: number, patch: Partial<BranchInput>) {
    await wait();
    const me = this.need('super_admin', 'marketing_admin');
    const b = this.branchList.find((x) => x.id === id);
    if (!b) throw new ApiError('NOT_FOUND', 404);
    Object.assign(b, cleanBranch(patch), { updatedAt: iso(now()) });
    this.log('admin', me.id, 'branch.update', 'branch', String(id), { fields: Object.keys(patch) });
    return { ...b };
  }
  async importBranches(): Promise<never> {
    await wait();
    this.need('super_admin', 'marketing_admin');
    throw new ApiError('DEMO_IMPORT', 400);
  }
}

/** Mirrors the backend: trims, '' → null, one Saudi phone, https Google Maps links only. */
function cleanBranch<T extends Partial<BranchInput>>(p: T): T {
  const out: Record<string, unknown> = { ...p };
  for (const [k, v] of Object.entries(p)) if (typeof v === 'string') out[k] = v.trim() === '' ? null : v.trim().replace(/\s+/g, ' ');
  for (const k of ['nameAr', 'city', 'addressAr'] as const) if (k in p && !out[k]) throw new ApiError('VALIDATION_FAILED', 400, `${k} is required`);
  if (typeof out.phone === 'string') {
    const d = out.phone.replace(/\D/g, '').replace(/^966/, '').replace(/^0/, '');
    if (/^5\d{8}$/.test(d) || /^1[1-7]\d{7}$/.test(d)) out.phone = `+966${d}`;
    else if (/^92\d{7}$/.test(d) || /^800\d{7}$/.test(d)) out.phone = d;
    else throw new ApiError('VALIDATION_FAILED', 400, 'Invalid phone number');
  }
  if (typeof out.mapsUrl === 'string') {
    let ok = false;
    try {
      const u = new URL(out.mapsUrl);
      ok = u.protocol === 'https:' && (u.hostname === 'maps.app.goo.gl' || (u.hostname === 'goo.gl' && u.pathname.startsWith('/maps/')) || u.hostname === 'maps.google.com' || (/(^|\.)google\.com(\.sa)?$/.test(u.hostname) && u.pathname.startsWith('/maps')));
    } catch { ok = false; }
    if (!ok) throw new ApiError('VALIDATION_FAILED', 400, 'Location must be an https Google Maps link');
  }
  return out as T;
}
