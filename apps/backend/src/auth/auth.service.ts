import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { hash as argonHash, verify as argonVerify } from '@node-rs/argon2';
import { createHash, randomBytes } from 'node:crypto';
import { and, eq, isNull } from 'drizzle-orm';
import { AppError } from '../common/errors';
import { maskMobile, normalizeSaudiMobile } from '../common/phone';
import { ENV, Env } from '../config/env';
import { DB, Db } from '../db/db.module';
import { refreshSessions, users } from '../db/schema';
import { ErpAdapter } from '../erp/erp.adapter';
import { ErpCustomer, ErpUnavailableError } from '../erp/erp.types';
import { AuditService } from '../audit/audit.service';
import { OtpService } from './otp/otp.service';

export interface AccessClaims {
  sub: string; // user id
  sid: string; // refresh session id
  ecid: string; // ERP customer id — the ONLY source of customer scoping
}

interface VerificationClaims {
  mobile: string;
  purpose: 'register' | 'reset_password';
  otpId: string;
}

export interface TokenPair {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
}

// Argon2id parameters (OWASP 2024 minimum: m=19MiB, t=2, p=1).
const ARGON = { memoryCost: 19_456, timeCost: 2, parallelism: 1 } as const;
// Used to equalize timing when the account does not exist.
const DUMMY_HASH_PROMISE = argonHash('timing-equalizer-not-a-password', ARGON);

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(ENV) private readonly env: Env,
    private readonly jwt: JwtService,
    private readonly erp: ErpAdapter,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
  ) {}

  normalizeOrThrow(raw: string): string {
    const mobile = normalizeSaudiMobile(raw);
    if (!mobile) throw new AppError('INVALID_MOBILE', HttpStatus.BAD_REQUEST, 'Invalid Saudi mobile number');
    return mobile;
  }

  private async erpCall<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (err) {
      if (err instanceof ErpUnavailableError) throw new AppError('ERP_UNAVAILABLE', HttpStatus.SERVICE_UNAVAILABLE);
      throw err;
    }
  }

  /**
   * Registration eligibility. Ordered checks:
   * invalid → already has app account → not in ERP → multiple ERP matches → ineligible account → eligible.
   */
  async resolveRegistrationCandidate(rawMobile: string): Promise<{ mobile: string; customer: ErpCustomer }> {
    const mobile = this.normalizeOrThrow(rawMobile);
    const [existing] = await this.db.select({ id: users.id }).from(users).where(eq(users.mobileNumber, mobile)).limit(1);
    if (existing) throw new AppError('ACCOUNT_EXISTS', HttpStatus.CONFLICT, 'An account already exists for this number');

    const matches = await this.erpCall(() => this.erp.findCustomersByMobile(mobile));
    if (matches.length === 0) {
      throw new AppError('MOBILE_NOT_REGISTERED', HttpStatus.NOT_FOUND, 'This mobile number is not registered with Zaad Pharmacies');
    }
    if (matches.length > 1) {
      await this.audit.log({
        actorType: 'system',
        action: 'registration.blocked_duplicate_erp_match',
        resourceType: 'mobile',
        resourceId: maskMobile(mobile),
        metadata: { erpCustomerIds: matches.map((m) => m.erpCustomerId) },
      });
      throw new AppError('ACCOUNT_NEEDS_SUPPORT', HttpStatus.CONFLICT, 'This number needs verification by customer support');
    }
    const [customer] = matches;
    if (!customer.eligibleForApp) {
      throw new AppError('ACCOUNT_NOT_ELIGIBLE', HttpStatus.FORBIDDEN, 'This account type cannot use the app');
    }
    const [linked] = await this.db.select({ id: users.id }).from(users).where(eq(users.erpCustomerId, customer.erpCustomerId)).limit(1);
    if (linked) throw new AppError('ACCOUNT_EXISTS', HttpStatus.CONFLICT, 'An account already exists for this customer');
    return { mobile, customer };
  }

  async checkMobile(rawMobile: string) {
    await this.resolveRegistrationCandidate(rawMobile);
    return { status: 'eligible' as const };
  }

  async sendOtp(rawMobile: string, purpose: 'register' | 'reset_password', ip: string | null) {
    if (purpose === 'register') {
      const { mobile } = await this.resolveRegistrationCandidate(rawMobile);
      return this.otp.issue(mobile, purpose, ip);
    }
    const mobile = this.normalizeOrThrow(rawMobile);
    const [user] = await this.db.select({ id: users.id }).from(users).where(eq(users.mobileNumber, mobile)).limit(1);
    if (!user) {
      // Do not reveal whether an app account exists for password reset.
      return { expiresInSeconds: this.env.OTP_TTL_SECONDS, resendAfterSeconds: this.env.OTP_RESEND_COOLDOWN_SECONDS, channel: 'whatsapp' };
    }
    return this.otp.issue(mobile, purpose, ip);
  }

  async verifyOtp(rawMobile: string, purpose: 'register' | 'reset_password', code: string) {
    const mobile = this.normalizeOrThrow(rawMobile);
    const otpId = await this.otp.verify(mobile, purpose, code);
    const claims: VerificationClaims = { mobile, purpose, otpId };
    const verificationToken = await this.jwt.signAsync(claims, {
      secret: this.env.JWT_ACCESS_SECRET,
      audience: 'zaad-verify',
      expiresIn: this.env.VERIFICATION_TOKEN_TTL_SECONDS,
    });
    return { verificationToken, expiresInSeconds: this.env.VERIFICATION_TOKEN_TTL_SECONDS };
  }

  private async readVerification(token: string, purpose: VerificationClaims['purpose']): Promise<VerificationClaims> {
    try {
      const c = await this.jwt.verifyAsync<VerificationClaims>(token, { secret: this.env.JWT_ACCESS_SECRET, audience: 'zaad-verify' });
      if (c.purpose !== purpose) throw new Error('purpose mismatch');
      return c;
    } catch {
      throw new AppError('OTP_EXPIRED', HttpStatus.BAD_REQUEST, 'Verification expired. Please request a new code.');
    }
  }

  async register(input: { verificationToken: string; password: string; deviceId: string; platform: 'android' | 'ios' | 'web'; language: 'ar' | 'en' }) {
    const claims = await this.readVerification(input.verificationToken, 'register');
    // Re-check against ERP at the moment of account creation (state may have changed since OTP).
    const { mobile, customer } = await this.resolveRegistrationCandidate(claims.mobile);
    const passwordHash = await argonHash(input.password, ARGON);

    const userId = await this.db.transaction(async (tx) => {
      if (!(await this.otp.consume(claims.otpId, tx))) {
        throw new AppError('OTP_EXPIRED', HttpStatus.BAD_REQUEST, 'Verification already used');
      }
      try {
        const [u] = await tx
          .insert(users)
          .values({ erpCustomerId: customer.erpCustomerId, mobileNumber: mobile, passwordHash, preferredLanguage: input.language })
          .returning({ id: users.id });
        return u.id;
      } catch (err) {
        // Unique constraints on erp_customer_id / mobile_number guard against concurrent double registration.
        if ((err as { code?: string }).code === '23505' || (err as { cause?: { code?: string } }).cause?.code === '23505') {
          throw new AppError('ACCOUNT_EXISTS', HttpStatus.CONFLICT, 'An account already exists for this customer');
        }
        throw err;
      }
    });

    await this.audit.log({ actorType: 'customer', actorId: userId, action: 'customer.registered', resourceType: 'user', resourceId: userId });
    return this.issueTokens(userId, customer.erpCustomerId, input.deviceId, input.platform);
  }

  async login(input: { mobile: string; password: string; deviceId: string; platform: 'android' | 'ios' | 'web' }) {
    const mobile = normalizeSaudiMobile(input.mobile);
    const [user] = mobile ? await this.db.select().from(users).where(eq(users.mobileNumber, mobile)).limit(1) : [];
    const ok = await argonVerify(user?.passwordHash ?? (await DUMMY_HASH_PROMISE), input.password);
    if (!user || !ok) throw new AppError('INVALID_CREDENTIALS', HttpStatus.UNAUTHORIZED, 'Incorrect mobile number or password');
    if (user.accountStatus !== 'active') throw new AppError('ACCOUNT_SUSPENDED', HttpStatus.FORBIDDEN);
    await this.db.update(users).set({ lastLoginAt: new Date() }).where(eq(users.id, user.id));
    return this.issueTokens(user.id, user.erpCustomerId, input.deviceId, input.platform);
  }

  /** Refresh token format: "<sessionId>.<secret>". Only sha256(token) is stored. Rotated on every use. */
  async refresh(refreshToken: string): Promise<TokenPair> {
    const [sessionId] = refreshToken.split('.');
    if (!sessionId || !/^[0-9a-f-]{36}$/.test(sessionId)) throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);

    const [row] = await this.db
      .select({ s: refreshSessions, erpCustomerId: users.erpCustomerId, status: users.accountStatus })
      .from(refreshSessions)
      .innerJoin(users, eq(users.id, refreshSessions.userId))
      .where(eq(refreshSessions.id, sessionId))
      .limit(1);

    if (!row || row.s.revokedAt || row.s.expiresAt.getTime() <= Date.now() || row.status !== 'active') {
      throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);
    }
    if (row.s.refreshTokenHash !== sha256(refreshToken)) {
      // An old (already rotated) token was replayed → assume theft, kill the session.
      await this.db.update(refreshSessions).set({ revokedAt: new Date() }).where(eq(refreshSessions.id, sessionId));
      this.logger.warn(`Refresh token reuse detected; session ${sessionId} revoked`);
      throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);
    }

    const next = `${sessionId}.${randomBytes(32).toString('base64url')}`;
    const rotated = await this.db
      .update(refreshSessions)
      .set({ refreshTokenHash: sha256(next), lastUsedAt: new Date() })
      .where(and(eq(refreshSessions.id, sessionId), eq(refreshSessions.refreshTokenHash, row.s.refreshTokenHash), isNull(refreshSessions.revokedAt)))
      .returning({ id: refreshSessions.id });
    if (rotated.length !== 1) throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED); // concurrent refresh lost the race

    return { ...(await this.signAccess(row.s.userId, sessionId, row.erpCustomerId)), refreshToken: next };
  }

  async logout(sessionId: string) {
    await this.db.update(refreshSessions).set({ revokedAt: new Date() }).where(and(eq(refreshSessions.id, sessionId), isNull(refreshSessions.revokedAt)));
  }

  async resetPassword(verificationToken: string, password: string) {
    const claims = await this.readVerification(verificationToken, 'reset_password');
    const passwordHash = await argonHash(password, ARGON);
    await this.db.transaction(async (tx) => {
      if (!(await this.otp.consume(claims.otpId, tx))) throw new AppError('OTP_EXPIRED', HttpStatus.BAD_REQUEST, 'Verification already used');
      const [u] = await tx.update(users).set({ passwordHash, updatedAt: new Date() }).where(eq(users.mobileNumber, claims.mobile)).returning({ id: users.id });
      if (!u) throw new AppError('OTP_EXPIRED', HttpStatus.BAD_REQUEST);
      // A password reset signs out every device.
      await tx.update(refreshSessions).set({ revokedAt: new Date() }).where(and(eq(refreshSessions.userId, u.id), isNull(refreshSessions.revokedAt)));
    });
    return { ok: true };
  }

  private async signAccess(userId: string, sessionId: string, erpCustomerId: string) {
    const claims: AccessClaims = { sub: userId, sid: sessionId, ecid: erpCustomerId };
    const accessToken = await this.jwt.signAsync(claims, {
      secret: this.env.JWT_ACCESS_SECRET,
      audience: 'zaad-customer',
      expiresIn: this.env.ACCESS_TOKEN_TTL_SECONDS,
    });
    return { accessToken, accessTokenExpiresIn: this.env.ACCESS_TOKEN_TTL_SECONDS };
  }

  private async issueTokens(userId: string, erpCustomerId: string, deviceId: string, platform: 'android' | 'ios' | 'web'): Promise<TokenPair> {
    // One active session per device: re-login on the same device replaces the old session.
    await this.db
      .update(refreshSessions)
      .set({ revokedAt: new Date() })
      .where(and(eq(refreshSessions.userId, userId), eq(refreshSessions.deviceIdentifier, deviceId), isNull(refreshSessions.revokedAt)));

    const [session] = await this.db
      .insert(refreshSessions)
      .values({
        userId,
        deviceIdentifier: deviceId,
        devicePlatform: platform,
        refreshTokenHash: sha256(randomBytes(16).toString('hex')), // placeholder, replaced below
        expiresAt: new Date(Date.now() + this.env.REFRESH_TOKEN_TTL_DAYS * 86_400_000),
      })
      .returning({ id: refreshSessions.id });
    const refreshToken = `${session.id}.${randomBytes(32).toString('base64url')}`;
    await this.db.update(refreshSessions).set({ refreshTokenHash: sha256(refreshToken) }).where(eq(refreshSessions.id, session.id));
    return { ...(await this.signAccess(userId, session.id, erpCustomerId)), refreshToken };
  }
}
