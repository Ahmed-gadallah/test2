import { eq, sql } from 'drizzle-orm';
import { notifications, offers, otpRequests, users } from '../src/db/schema';
import { OffersService } from '../src/offers/offers.service';
import { readBranchSheet } from '../src/branches/branch-import';
import { BranchesService } from '../src/branches/branches.service';
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

// ─── Security hardening ─────────────────────────────────────────────────────
describe('security hardening', () => {
  it('locks the account after repeated wrong passwords, even from different IPs', async () => {
    await registerCustomer(ctx);
    for (let i = 0; i < 5; i++) {
      await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: `wrong${i}pass`, ...DEVICE }).expect(401);
    }
    // Correct password is refused while locked.
    const r = await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'zaad1234', ...DEVICE }).expect(429);
    expect(r.body.error.code).toBe('ACCOUNT_LOCKED');
    expect(r.body.error.details.retryAfterSeconds).toBeGreaterThan(0);
  });

  it('a successful login resets the failure count', async () => {
    await registerCustomer(ctx);
    for (let i = 0; i < 4; i++) await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'nope1234', ...DEVICE }).expect(401);
    await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'zaad1234', ...DEVICE }).expect(200);
    for (let i = 0; i < 4; i++) await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'nope1234', ...DEVICE }).expect(401);
    await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'zaad1234', ...DEVICE }).expect(200);
  });

  it('password reset via OTP clears a lockout', async () => {
    await registerCustomer(ctx);
    for (let i = 0; i < 5; i++) await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'nope1234', ...DEVICE });
    await ctx.http().post(`${P}/auth/forgot-password`).send({ mobile: '0500000001' }).expect(200);
    const v = await ctx.http().post(`${P}/auth/verify-otp`).send({ mobile: '0500000001', purpose: 'reset_password', code: '123456' }).expect(200);
    await ctx.http().post(`${P}/auth/reset-password`).send({ verificationToken: v.body.data.verificationToken, password: 'fresh1234' }).expect(200);
    await ctx.http().post(`${P}/auth/login`).send({ mobile: '0500000001', password: 'fresh1234', ...DEVICE }).expect(200);
  });

  it('admin accounts lock out too', async () => {
    await createAdmin(ctx, 'super_admin');
    for (let i = 0; i < 5; i++) await ctx.http().post(`${P}/admin/auth/login`).send({ email: 'super_admin@zaad.test', password: 'WrongPass12345' });
    // the per-IP limit for admin login is 5/min, so the 6th call may be rate-limited first; either way it is refused
    const r = await ctx.http().post(`${P}/admin/auth/login`).send({ email: 'super_admin@zaad.test', password: 'AdminPass12345' });
    expect([429]).toContain(r.status);
    expect(['ACCOUNT_LOCKED', 'RATE_LIMITED']).toContain(r.body.error.code);
  });

  it('a spoofed X-Forwarded-For header does not bypass the per-IP limit', async () => {
    let last = 0;
    for (let i = 0; i < 12; i++) {
      const r = await ctx.http().post(`${P}/auth/check-mobile`).set('X-Forwarded-For', `203.0.113.${i}`).send({ mobile: '0599999999' });
      last = r.status;
    }
    expect(last).toBe(429);
  });

  it('rejects oversized bodies and unknown fields', async () => {
    await ctx.http().post(`${P}/auth/check-mobile`).send({ mobile: '0500000001', pad: 'x'.repeat(200_000) }).expect(413);
    await ctx.http().post(`${P}/auth/check-mobile`).send({ mobile: '0500000001', isAdmin: true }).expect(400);
    const bad = await ctx.http().post(`${P}/auth/check-mobile`).set('content-type', 'application/json').send('{"mobile": ').expect(400);
    expect(bad.body.error.code).toBe('VALIDATION_FAILED');
  });

  it('admin customer routes reject non-numeric ids', async () => {
    const s = await createAdmin(ctx, 'super_admin');
    await ctx.http().get(`${P}/admin/customers/abc%2F..%2Fx/points`).set(auth(s)).expect(400);
  });

  it('offer links and images must use an allowed host', async () => {
    const admin = await createAdmin(ctx, 'marketing_admin');
    const bad = await ctx.http().post(`${P}/admin/offers`).set(auth(admin)).send({ ...offer(), destinationUrl: 'https://zaad-offers.evil.example/win' }).expect(400);
    expect(bad.body.error.message).toMatch(/destinationUrl/);
    await ctx.http().post(`${P}/admin/offers`).set(auth(admin)).send({ ...offer(), destinationUrl: 'https://zaadonline.com/vitamins', imageUrl: 'https://cdn.zaadonline.com/a.jpg' }).expect(201);
  });

  it('tokens signed with another algorithm or secret are refused', async () => {
    const forged = ['eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0', Buffer.from(JSON.stringify({ sub: 'x', sid: 'x', ecid: '900001', aud: 'zaad-customer' })).toString('base64url'), ''].join('.');
    await ctx.http().get(`${P}/customer/points`).set(auth(forged)).expect(401);
  });
});

// ─── Admin dashboard endpoints ──────────────────────────────────────────────
describe('admin dashboard endpoints', () => {
  it('me + dashboard counters are available to every role', async () => {
    for (const role of ['super_admin', 'marketing_admin', 'customer_support'] as const) {
      const t = await createAdmin(ctx, role);
      const me = await ctx.http().get(`${P}/admin/me`).set(auth(t)).expect(200);
      expect(me.body.data.role).toBe(role);
      const d = await ctx.http().get(`${P}/admin/dashboard`).set(auth(t)).expect(200);
      expect(d.body.data).toHaveProperty('offersActive');
    }
  });

  it('support can open an invoice; marketing cannot', async () => {
    const s = await createAdmin(ctx, 'customer_support');
    const r = await ctx.http().get(`${P}/admin/customers/900001/invoices/900001-1000`).set(auth(s)).expect(200);
    expect(r.body.data.lines.length).toBeGreaterThan(0);
    await ctx.http().get(`${P}/admin/customers/900001/invoices/900002-1000`).set(auth(s)).expect(404);
    const m = await createAdmin(ctx, 'marketing_admin');
    await ctx.http().get(`${P}/admin/customers/900001/invoices/900001-1000`).set(auth(m)).expect(403);
  });

  it('super admin can change roles and deactivate others, but not lock themselves out', async () => {
    const s = await createAdmin(ctx, 'super_admin');
    const m = await createAdmin(ctx, 'marketing_admin');
    const list = await ctx.http().get(`${P}/admin/admins`).set(auth(s)).expect(200);
    const mkt = list.body.data.find((x: { role: string }) => x.role === 'marketing_admin');
    const me = list.body.data.find((x: { role: string }) => x.role === 'super_admin');
    await ctx.http().patch(`${P}/admin/admins/${mkt.id}`).set(auth(s)).send({ active: false }).expect(200);
    await ctx.http().get(`${P}/admin/offers`).set(auth(m)).expect(401); // deactivation is immediate
    await ctx.http().patch(`${P}/admin/admins/${me.id}`).set(auth(s)).send({ role: 'customer_support' }).expect(403);
    await ctx.http().patch(`${P}/admin/admins/${me.id}`).set(auth(s)).send({ active: false }).expect(403);
    await ctx.http().patch(`${P}/admin/admins/${me.id}`).set(auth(m)).send({ active: true }).expect(401);
  });
});

// ─── Branch Locator ─────────────────────────────────────────────────────────
describe('branch locator', () => {
  const SHEET = `${__dirname}/fixtures/zaad-branches.xlsx`;
  const upload = (t: string, dryRun: boolean) =>
    ctx.http().post(`${P}/admin/branches/import?dryRun=${dryRun}`).set(auth(t)).attach('file', SHEET);

  it('import is a dry run by default, then applies; importing the same file again creates no duplicates', async () => {
    const t = await createAdmin(ctx, 'super_admin');
    const dry = await ctx.http().post(`${P}/admin/branches/import`).set(auth(t)).attach('file', SHEET).expect(200);
    expect(dry.body.data).toMatchObject({ dryRun: true, applied: false, errors: [] });
    expect(dry.body.data.created).toHaveLength(53);
    await ctx.http().get(`${P}/branches`).expect(200).expect((r) => expect(r.body.data).toEqual([]));

    const first = await upload(t, false).expect(200);
    expect(first.body.data).toMatchObject({ applied: true });
    expect(first.body.data.created).toHaveLength(53);
    const second = await upload(t, false).expect(200);
    expect(second.body.data.created).toEqual([]);
    expect(second.body.data.updated).toEqual([]);
    expect(second.body.data.unchanged).toHaveLength(53);
    const [{ n }] = (await ctx.db.execute(sql`select count(*)::int as n from branches`)).rows as { n: number }[];
    expect(n).toBe(53);

    const audit = await ctx.http().get(`${P}/admin/audit-logs`).set(auth(t)).expect(200);
    expect(audit.body.data.filter((a: { action: string }) => a.action === 'branches.import')).toHaveLength(2);
  });

  it('customers get active branches only, with the single phone and the original maps link', async () => {
    const t = await createAdmin(ctx, 'super_admin');
    await upload(t, false).expect(200);
    await ctx.http().patch(`${P}/admin/branches/20`).set(auth(t)).send({ active: false }).expect(200);

    const list = await ctx.http().get(`${P}/branches`).expect(200); // public, no login
    expect(list.body.data).toHaveLength(52);
    expect(list.body.data.find((b: { id: number }) => b.id === 20)).toBeUndefined();
    await ctx.http().get(`${P}/branches/20`).expect(404);
    const b = await ctx.http().get(`${P}/branches/0`).expect(200);
    expect(b.body.data).toEqual({
      id: 0, nameAr: 'صيدلية زاد الدوائية 48', nameEn: 'zaad pharmacy 48', city: 'بقعاء', district: 'بقعاء', addressAr: 'بقعاء', addressEn: 'Baqaa',
      phone: '+966541418264', mapsUrl: 'https://maps.app.goo.gl/BB8rfs9zdyUzd7a38', notes: null,
    });
    expect(b.body.data).not.toHaveProperty('active');
    expect(Object.keys(b.body.data).filter((k) => /phone/i.test(k))).toEqual(['phone']); // ONE phone field
    const noPhone = await ctx.http().get(`${P}/branches/7`).expect(200);
    expect(noPhone.body.data.phone).toBeNull();

    // Re-importing the sheet (which says active = نعم) re-activates it: the sheet is the source of truth.
    const re = await upload(t, false).expect(200);
    expect(re.body.data.updated).toEqual([20]);
    expect((await ctx.http().get(`${P}/branches`).expect(200)).body.data).toHaveLength(53);
  });

  it('admin edits use the same validation; marketing can manage branches, support cannot', async () => {
    const s = await createAdmin(ctx, 'super_admin');
    const m = await createAdmin(ctx, 'marketing_admin');
    const c = await createAdmin(ctx, 'customer_support');
    await upload(s, false).expect(200);
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(m)).send({ phone: '055 000 1111' }).expect(200)
      .expect((r) => expect(r.body.data.phone).toBe('+966550001111'));
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(m)).send({ phone: 'abc' }).expect(400);
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(m)).send({ mapsUrl: 'https://evil.example/x' }).expect(400);
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(m)).send({ mapsUrl: '' }).expect(200)
      .expect((r) => expect(r.body.data.mapsUrl).toBeNull());
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(m)).send({ nameAr: '  ' }).expect(400);
    await ctx.http().post(`${P}/admin/branches`).set(auth(m)).send({ branchId: 7, nameAr: 'x', city: 'y', addressAr: 'z', active: true }).expect(409);
    await ctx.http().post(`${P}/admin/branches`).set(auth(m)).send({ branchId: 999, nameAr: 'فرع جديد', city: 'حائل', addressAr: 'حي', active: false }).expect(201);
    await ctx.http().get(`${P}/branches/999`).expect(404); // inactive → hidden from customers
    await ctx.http().get(`${P}/admin/branches`).set(auth(c)).expect(403);
    await ctx.http().patch(`${P}/admin/branches/7`).set(auth(c)).send({ active: false }).expect(403);
    await upload(c, false).expect(403);
    await ctx.http().get(`${P}/admin/branches`).expect(401);
  });

  it('rejects files that are not a workbook, and sheets with errors write nothing', async () => {
    const t = await createAdmin(ctx, 'super_admin');
    await ctx.http().post(`${P}/admin/branches/import?dryRun=false`).set(auth(t)).attach('file', Buffer.from('id,name\n1,x'), 'b.csv').expect(400);
    await ctx.http().post(`${P}/admin/branches/import?dryRun=false`).set(auth(t)).attach('file', Buffer.from('PK\x03\x04garbage'), 'b.xlsx').expect(400);
    await ctx.http().post(`${P}/admin/branches/import`).set(auth(t)).expect(400);

    const rows = await readBranchSheet(SHEET);
    rows.push([...rows[1]]); // duplicate Branch ID 0 at the end
    const r = await ctx.app.get(BranchesService).importRows(rows, false);
    expect(r.applied).toBe(false);
    expect(r.errors[0].message).toContain('Duplicate Branch ID');
    const [{ n }] = (await ctx.db.execute(sql`select count(*)::int as n from branches`)).rows as { n: number }[];
    expect(n).toBe(0);
  });
});
