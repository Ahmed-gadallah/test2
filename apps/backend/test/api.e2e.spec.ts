import { eq, sql } from 'drizzle-orm';
import { notifications, offers, otpRequests, users } from '../src/db/schema';
import { OffersService } from '../src/offers/offers.service';
import { auth, createAdmin, DEVICE, registerCustomer, setupApp, TestCtx } from './helpers';

let ctx: TestCtx;
beforeEach(async () => {
  ctx = await setupApp();
});
afterEach(async () => {
  await ctx.app.close();
});

const P = '/api/v1';

const offer = (startOffsetMs = -60_000) => ({
  titleAr: 'خصم ٢٠٪ على الفيتامينات',
  titleEn: '20% off vitamins',
  descriptionAr: 'لفترة محدودة في جميع الفروع',
  descriptionEn: 'Limited time in all branches',
  startAt: new Date(Date.now() + startOffsetMs).toISOString(),
  endAt: new Date(Date.now() + 7 * 86_400_000).toISOString(),
});


// ─── Authentication (spec §22) ──────────────────────────────────────────────
describe('authentication', () => {
  it('existing ERP customer can register and is linked to the ERP customer id', async () => {
    const t = await registerCustomer(ctx);
    expect(t.accessToken).toBeTruthy();
    const [u] = await ctx.db.select().from(users);
    expect(u.erpCustomerId).toBe('900001');
    expect(u.mobileNumber).toBe('+966500000001');
    expect(u.passwordHash).not.toContain('zaad1234');
  });

  it('unknown mobile number cannot register', async () => {
    const r = await ctx.http().post(`${P}/auth/send-otp`).send({ mobile: '0599999999', purpose: 'register' }).expect(404);
    expect(r.body.error.code).toBe('MOBILE_NOT_REGISTERED');
  });

  it('duplicate ERP matches stop registration and are audit-logged', async () => {
    const r = await ctx.http().post(`${P}/auth/check-mobile`).send({ mobile: '0500000003' }).expect(409);
    expect(r.body.error.code).toBe('ACCOUNT_NEEDS_SUPPORT');
    const rows = await ctx.db.execute(sql`select action from audit_logs`);
    expect(rows.rows.map((x) => x.action)).toContain('registration.blocked_duplicate_erp_match');
  });

  it('institutional accounts are not eligible', async () => {
    const r = await ctx.http().post(`${P}/auth/check-mobile`).send({ mobile: '0500000004' }).expect(403);
    expect(r.body.error.code).toBe('ACCOUNT_NOT_ELIGIBLE');
  });

  it('cannot create a second account for the same customer', async () => {
    await registerCustomer(ctx);
    const r = await ctx.http().post(`${P}/auth/check-mobile`).send({ mobile: '+966500000001' }).expect(409);
    expect(r.body.error.code).toBe('ACCOUNT_EXISTS');
  });

  it('invalid OTP is rejected and attempts are limited', async () => {
    await ctx.http().post(`${P}/auth/send-otp`).send({ mobile: '0500000001', purpose: 'register' }).expect(200);
    for (let i = 0; i < 5; i++) {
      const r = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'register', code: '000000' }).expect(400);
      expect(r.body.error.code).toBe('OTP_INVALID');
    }
    const r = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'register', code: '123456' }).expect(429);
    expect(r.body.error.code).toBe('OTP_TOO_MANY_ATTEMPTS');
  });

  it('expired OTP is rejected', async () => {
    await ctx.http().post(`${P}/auth/send-otp`).send({ mobile: '0500000001', purpose: 'register' }).expect(200);
    await ctx.db.update(otpRequests).set({ expiresAt: new Date(Date.now() - 1000) });
    const r = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'register', code: '123456' }).expect(400);
    expect(r.body.error.code).toBe('OTP_EXPIRED');
  });

  it('a verification token cannot be used twice', async () => {
    await ctx.http().post(`${P}/auth/send-otp`).send({ mobile: '0500000001', purpose: 'register' });
    const v = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'register', code: '123456' });
    const body = { verificationToken: v.body.data.verificationToken, password: 'zaad1234', ...DEVICE };
    await ctx.http().post(`${P}/auth/register`).send(body).expect(201);
    await ctx.http().post(`${P}/auth/register`).send(body).expect(409);
  });

  it('login works after registration; wrong password is rejected', async () => {
    await registerCustomer(ctx);
    await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'zaad1234', ...DEVICE }).expect(200);
    const r = await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'wrong1234', ...DEVICE }).expect(401);
    expect(r.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('logout revokes the session immediately', async () => {
    const t = await registerCustomer(ctx);
    await ctx.http().post(`${P}/auth/logout`).set(auth(t.accessToken)).expect(200);
    await ctx.http().get(`${P}/customer/points`).set(auth(t.accessToken)).expect(401);
    await ctx.http().post(`${P}/auth/refresh`).send({ refreshToken: t.refreshToken }).expect(401);
  });

  it('refresh rotates tokens and a replayed old token kills the session', async () => {
    const t = await registerCustomer(ctx);
    const r1 = await ctx.http().post(`${P}/auth/refresh`).send({ refreshToken: t.refreshToken }).expect(200);
    await ctx.http().post(`${P}/auth/refresh`).send({ refreshToken: t.refreshToken }).expect(401); // replay
    await ctx.http().post(`${P}/auth/refresh`).send({ refreshToken: r1.body.data.refreshToken }).expect(401); // session now revoked
  });

  it('password reset via OTP signs out every device', async () => {
    const t = await registerCustomer(ctx);
    await ctx.http().post(`${P}/auth/forgot-password`).send({ mobile: '0500000001' }).expect(200);
    const v = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'reset_password', code: '123456' }).expect(200);
    await ctx.http().post(`${P}/auth/reset-password`).send({ verificationToken: v.body.data.verificationToken, password: 'newpass99' }).expect(200);
    await ctx.http().get(`${P}/customer/points`).set(auth(t.accessToken)).expect(401);
    await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'newpass99', ...DEVICE }).expect(200);
  });
});

// ─── Loyalty (spec §22) ─────────────────────────────────────────────────────
describe('loyalty', () => {
  it('balance comes from the ERP and SAR uses the agreed 50:1 rate', async () => {
    const t = await registerCustomer(ctx);
    const r = await ctx.http().get(`${P}/customer/points`).set(auth(t.accessToken)).expect(200);
    expect(r.body.data).toMatchObject({ points: 2500, equivalentSar: 50, pointsPerSar: 50, source: 'erp' });
  });

  it('refund adjustments are displayed exactly as received from the ERP', async () => {
    const t = await registerCustomer(ctx);
    const r = await ctx.http().get(`${P}/customer/points/history?limit=50`).set(auth(t.accessToken)).expect(200);
    const refunds = r.body.data.filter((e: { type: string }) => e.type === 'refund_adjustment');
    expect(refunds.length).toBeGreaterThan(0);
    const erpLedger = (await ctx.erp.getPointsHistory('900001', null, 50)).items.filter((e) => e.type === 'refund_adjustment');
    expect(refunds.map((e: { pointsDelta: number }) => e.pointsDelta)).toEqual(erpLedger.map((e) => e.pointsDelta));
  });

  it('reading data never changes the authoritative balance and the app DB stores no balances', async () => {
    const t = await registerCustomer(ctx);
    for (const path of ['/customer/points', '/customer/points/history', '/customer/invoices', '/customer/profile']) {
      await ctx.http().get(`${P}${path}`).set(auth(t.accessToken)).expect(200);
    }
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(2500);
    const cols = await ctx.db.execute(sql`select column_name from information_schema.columns where table_schema='public' and column_name ~* '(balance|points_balance)'`);
    expect(cols.rows).toEqual([]);
  });

  it('ERP outage returns a clear error, never fabricated data', async () => {
    const t = await registerCustomer(ctx);
    ctx.erp.simulateOutage = true;
    const r = await ctx.http().get(`${P}/customer/points?refresh=true`).set(auth(t.accessToken)).expect(503);
    expect(r.body.error.code).toBe('ERP_UNAVAILABLE');
    expect(r.body.data).toBeUndefined();
  });
});

// ─── Redemption (spec §22) ──────────────────────────────────────────────────
describe('redemption', () => {
  async function cashier(points = 1000, ttlSeconds = 120) {
    const r = await ctx.http().post(`${P}/dev/simulate/cashier-redemption`).send({ mobile: '0500000001', points, ttlSeconds }).expect(201);
    return r.body.data.id as string;
  }

  it('pending request appears in the app and creates an in-app notification', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier();
    const r = await ctx.http().get(`${P}/redemption/pending`).set(auth(t.accessToken)).expect(200);
    expect(r.body.data).toHaveLength(1);
    expect(r.body.data[0]).toMatchObject({ id, points: 1000, discountAmount: 20, status: 'pending' });
    const n = await ctx.db.select().from(notifications);
    expect(n.map((x) => x.type)).toEqual(['redemption_request']);
  });

  it('customer can approve; the ERP deducts once', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000);
    const r = await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(200);
    expect(r.body.data.status).toBe('completed');
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(1500);
    const p = await ctx.http().get(`${P}/customer/points`).set(auth(t.accessToken)).expect(200);
    expect(p.body.data.points).toBe(1500); // cache invalidated
  });

  it('customer can reject; no points are deducted', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000);
    const r = await ctx.http().post(`${P}/redemption/${id}/reject`).set(auth(t.accessToken)).expect(200);
    expect(r.body.data.status).toBe('rejected');
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(2500);
  });

  it('expired request cannot be approved', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000, 10);
    await ctx.db.execute(sql`update redemption_requests set expires_at = now() - interval '1 second'`);
    const r = await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(410);
    expect(r.body.error.code).toBe('REDEMPTION_EXPIRED');
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(2500);
  });

  it('concurrent duplicate approvals cause exactly one deduction and one final notification', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000);
    const results = await Promise.all(Array.from({ length: 5 }, () => ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken))));
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(1500);
    const finals = (await ctx.db.select().from(notifications)).filter((n) => n.type === 'redemption_completed');
    expect(finals).toHaveLength(1);
  });

  it('cannot reject after approving', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000);
    await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(200);
    const r = await ctx.http().post(`${P}/redemption/${id}/reject`).set(auth(t.accessToken)).expect(409);
    expect(r.body.error.code).toBe('REDEMPTION_ALREADY_DECIDED');
  });

  it('ERP failure during decision is safe: recorded, retried with the same key, deducted once', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(1000);
    ctx.erp.simulateOutage = true;
    const r1 = await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(202);
    expect(r1.body.error.code).toBe('REDEMPTION_DECISION_PENDING');
    expect((await ctx.erp.getPointsBalance('900001').catch(() => ({ points: -1 }))).points).toBe(-1);
    ctx.erp.simulateOutage = false;
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(2500);
    const r2 = await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(200);
    expect(r2.body.data.status).toBe('completed');
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(1500);
  });

  it('insufficient live balance is decided by the ERP, not the app', async () => {
    const t = await registerCustomer(ctx);
    const id = await cashier(5000);
    const r = await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(t.accessToken)).expect(200);
    expect(r.body.data.status).toBe('failed');
    expect((await ctx.erp.getPointsBalance('900001')).points).toBe(2500);
  });

  it("a customer cannot see or decide another customer's request", async () => {
    await registerCustomer(ctx);
    const id = await cashier(1000);
    const other = await registerCustomer(ctx, '0500000002');
    await ctx.http().get(`${P}/redemption/${id}`).set(auth(other.accessToken)).expect(404);
    await ctx.http().post(`${P}/redemption/${id}/approve`).set(auth(other.accessToken)).expect(404);
  });
});

// ─── Invoices (spec §22) ────────────────────────────────────────────────────
describe('invoices', () => {
  it('lists invoices from multiple branches with pagination', async () => {
    const t = await registerCustomer(ctx);
    const p1 = await ctx.http().get(`${P}/customer/invoices?limit=20`).set(auth(t.accessToken)).expect(200);
    const p2 = await ctx.http().get(`${P}/customer/invoices?limit=20&cursor=${p1.body.meta.nextCursor}`).set(auth(t.accessToken)).expect(200);
    const all = [...p1.body.data, ...p2.body.data];
    expect(all).toHaveLength(34);
    expect(new Set(all.map((i: { branchId: string }) => i.branchId)).size).toBeGreaterThan(1);
    expect(p2.body.meta.nextCursor).toBeNull();
  });

  it("customer sees only their own invoices", async () => {
    const t = await registerCustomer(ctx);
    await ctx.http().get(`${P}/customer/invoices/900002-1000`).set(auth(t.accessToken)).expect(404);
    const empty = await registerCustomer(ctx, '0500000002');
    const r = await ctx.http().get(`${P}/customer/invoices`).set(auth(empty.accessToken)).expect(200);
    expect(r.body.data).toEqual([]);
  });

  it('details render with missing optional ERP fields (null, not fabricated)', async () => {
    const t = await registerCustomer(ctx);
    const list = await ctx.http().get(`${P}/customer/invoices?limit=50`).set(auth(t.accessToken));
    const details = await Promise.all(list.body.data.map((i: { invoiceId: string }) => ctx.http().get(`${P}/customer/invoices/${i.invoiceId}`).set(auth(t.accessToken)).expect(200)));
    const withoutPayment = details.filter((d) => d.body.data.paymentMethod === null);
    expect(withoutPayment.length).toBeGreaterThan(0);
    expect(details[0].body.data.lines.length).toBeGreaterThan(0);
  });
});

// ─── Offers & notifications (spec §22) ──────────────────────────────────────
describe('offers & notifications', () => {

  it('publishing an active offer notifies every registered customer once; edits never re-notify', async () => {
    const c1 = await registerCustomer(ctx);
    await registerCustomer(ctx, '0500000002');
    const admin = await createAdmin(ctx, 'marketing_admin');
    const created = await ctx.http().post(`${P}/admin/offers`).set(auth(admin)).send(offer()).expect(201);
    const id = created.body.data.id;
    expect(created.body.data.status).toBe('draft');
    expect(await ctx.db.select().from(notifications)).toHaveLength(0); // drafts are silent

    await ctx.http().post(`${P}/admin/offers/${id}/publish`).set(auth(admin)).expect(200);
    await ctx.http().patch(`${P}/admin/offers/${id}`).set(auth(admin)).send({ titleEn: '25% off vitamins' }).expect(200);
    await ctx.http().post(`${P}/admin/offers/${id}/publish`).set(auth(admin)).expect(409); // already published

    const n = await ctx.db.select().from(notifications);
    expect(n).toHaveLength(2);
    expect(n.every((x) => x.deepLink === `zaad://offers/${id}`)).toBe(true);

    const visible = await ctx.http().get(`${P}/offers/${id}`).set(auth(c1.accessToken)).expect(200);
    expect(visible.body.data.titleEn).toBe('25% off vitamins');
  });

  it('a repeat notification requires the explicit resend action', async () => {
    await registerCustomer(ctx);
    const admin = await createAdmin(ctx, 'marketing_admin');
    const id = (await ctx.http().post(`${P}/admin/offers`).set(auth(admin)).send(offer())).body.data.id;
    await ctx.http().post(`${P}/admin/offers/${id}/publish`).set(auth(admin)).expect(200);
    await ctx.http().post(`${P}/admin/offers/${id}/resend-notification`).set(auth(admin)).expect(200);
    expect(await ctx.db.select().from(notifications)).toHaveLength(2);
  });

  it('scheduled offers notify when they go live, exactly once even if the dispatcher runs twice', async () => {
    await registerCustomer(ctx);
    const admin = await createAdmin(ctx, 'marketing_admin');
    const id = (await ctx.http().post(`${P}/admin/offers`).set(auth(admin)).send(offer(3_600_000))).body.data.id;
    const pub = await ctx.http().post(`${P}/admin/offers/${id}/publish`).set(auth(admin)).expect(200);
    expect(pub.body.data.status).toBe('scheduled');
    expect(await ctx.db.select().from(notifications)).toHaveLength(0);

    await ctx.db.update(offers).set({ startAt: new Date(Date.now() - 1000) }).where(eq(offers.id, id));
    const svc = ctx.app.get(OffersService);
    await Promise.all([svc.dispatchDueOffers(), svc.dispatchDueOffers()]);
    expect(await ctx.db.select().from(notifications)).toHaveLength(1);
  });

  it('notification center: list, unread count, mark read', async () => {
    const t = await registerCustomer(ctx);
    await ctx.http().post(`${P}/dev/simulate/cashier-redemption`).send({ mobile: '0500000001', points: 500 }).expect(201);
    const l = await ctx.http().get(`${P}/notifications`).set(auth(t.accessToken)).expect(200);
    expect(l.body.meta.unread).toBe(1);
    await ctx.http().patch(`${P}/notifications/${l.body.data[0].id}/read`).set(auth(t.accessToken)).expect(200);
    const l2 = await ctx.http().get(`${P}/notifications`).set(auth(t.accessToken)).expect(200);
    expect(l2.body.meta.unread).toBe(0);
  });
});

// ─── Admin permissions (spec §22) ───────────────────────────────────────────
describe('admin permissions (enforced by the backend)', () => {
  it('super admin has full access', async () => {
    const s = await createAdmin(ctx, 'super_admin');
    await ctx.http().get(`${P}/admin/admins`).set(auth(s)).expect(200);
    await ctx.http().get(`${P}/admin/audit-logs`).set(auth(s)).expect(200);
    await ctx.http().get(`${P}/admin/offers`).set(auth(s)).expect(200);
    await ctx.http().get(`${P}/admin/customers?mobile=0500000001`).set(auth(s)).expect(200);
  });

  it('marketing admin cannot manage administrators or view customers', async () => {
    const m = await createAdmin(ctx, 'marketing_admin');
    await ctx.http().get(`${P}/admin/admins`).set(auth(m)).expect(403);
    await ctx.http().post(`${P}/admin/admins`).set(auth(m)).send({ name: 'x', email: 'x@zaad.test', password: 'Password12345', role: 'super_admin' }).expect(403);
    await ctx.http().get(`${P}/admin/customers?mobile=0500000001`).set(auth(m)).expect(403);
  });

  it('customer support is read-only', async () => {
    const s = await createAdmin(ctx, 'customer_support');
    const r = await ctx.http().get(`${P}/admin/customers?mobile=0500000001`).set(auth(s)).expect(200);
    expect(r.body.data[0].erpCustomerId).toBe('900001');
    await ctx.http().get(`${P}/admin/customers/900001/points`).set(auth(s)).expect(200);
    await ctx.http().post(`${P}/admin/offers`).set(auth(s)).send(offer()).expect(403);
    await ctx.http().get(`${P}/admin/audit-logs`).set(auth(s)).expect(403);
  });

  it('customer tokens cannot reach admin endpoints', async () => {
    const t = await registerCustomer(ctx);
    await ctx.http().get(`${P}/admin/dashboard`).set(auth(t.accessToken)).expect(401);
  });
});
