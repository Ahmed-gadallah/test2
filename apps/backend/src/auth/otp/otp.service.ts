import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { and, desc, eq, gte, isNull } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { maskMobile } from '../../common/phone';
import { ENV, Env } from '../../config/env';
import { DB, Db } from '../../db/db.module';
import { otpRequests } from '../../db/schema';
import { ConsoleOtpSender, OtpSender, SmsOtpSender, WhatsAppOtpSender } from './otp.provider';

type Purpose = 'register' | 'reset_password';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly primary: OtpSender;
  private readonly fallback: OtpSender | null;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(ENV) private readonly env: Env,
  ) {
    const make = (c: string): OtpSender =>
      c === 'whatsapp' ? new WhatsAppOtpSender() : c === 'sms' ? new SmsOtpSender() : new ConsoleOtpSender();
    this.primary = make(env.OTP_PROVIDER);
    this.fallback = env.OTP_FALLBACK_PROVIDER === 'sms' ? new SmsOtpSender() : null;
  }

  /** OTPs are short-lived and attempt-limited, so a keyed HMAC is sufficient and constant-time comparable. */
  private hash(mobile: string, purpose: Purpose, code: string) {
    return createHmac('sha256', this.env.JWT_REFRESH_SECRET).update(`${mobile}|${purpose}|${code}`).digest('hex');
  }

  async issue(mobile: string, purpose: Purpose, ip: string | null): Promise<{ expiresInSeconds: number; resendAfterSeconds: number; channel: string }> {
    const now = Date.now();
    const hourAgo = new Date(now - 3_600_000);
    const recent = await this.db
      .select({ createdAt: otpRequests.createdAt })
      .from(otpRequests)
      .where(and(eq(otpRequests.mobileNumber, mobile), gte(otpRequests.createdAt, hourAgo)))
      .orderBy(desc(otpRequests.createdAt));

    if (recent.length >= this.env.OTP_MAX_PER_HOUR) {
      throw new AppError('RATE_LIMITED', HttpStatus.TOO_MANY_REQUESTS, 'Too many OTP requests. Try again later.');
    }
    if (recent[0]) {
      const elapsed = (now - recent[0].createdAt.getTime()) / 1000;
      if (elapsed < this.env.OTP_RESEND_COOLDOWN_SECONDS) {
        const retryAfter = Math.ceil(this.env.OTP_RESEND_COOLDOWN_SECONDS - elapsed);
        throw new AppError('OTP_COOLDOWN', HttpStatus.TOO_MANY_REQUESTS, 'Please wait before requesting a new code', { retryAfterSeconds: retryAfter });
      }
    }

    const code = this.env.OTP_DEV_FIXED_CODE ?? String(randomInt(0, 1_000_000)).padStart(6, '0');

    let sender = this.primary;
    try {
      await sender.send(mobile, code, purpose);
    } catch (err) {
      if (!this.fallback) {
        this.logger.error(`OTP delivery failed for ${maskMobile(mobile)} via ${sender.channel}`);
        throw new AppError('INTERNAL', HttpStatus.SERVICE_UNAVAILABLE, 'Could not send verification code');
      }
      this.logger.warn(`OTP ${sender.channel} failed for ${maskMobile(mobile)}; falling back to ${this.fallback.channel}`);
      sender = this.fallback;
      await sender.send(mobile, code, purpose);
    }

    // Previous unverified codes for the same purpose are invalidated by issuing a new one (only the latest is checked).
    await this.db.insert(otpRequests).values({
      mobileNumber: mobile,
      purpose,
      otpHash: this.hash(mobile, purpose, code),
      deliveryChannel: sender.channel,
      expiresAt: new Date(now + this.env.OTP_TTL_SECONDS * 1000),
      requestIp: ip,
    });

    return { expiresInSeconds: this.env.OTP_TTL_SECONDS, resendAfterSeconds: this.env.OTP_RESEND_COOLDOWN_SECONDS, channel: sender.channel };
  }

  /** Returns the id of the verified OTP row. That id is bound into the single-use verification token. */
  async verify(mobile: string, purpose: Purpose, code: string): Promise<string> {
    const [latest] = await this.db
      .select()
      .from(otpRequests)
      .where(and(eq(otpRequests.mobileNumber, mobile), eq(otpRequests.purpose, purpose), isNull(otpRequests.consumedAt)))
      .orderBy(desc(otpRequests.createdAt))
      .limit(1);

    if (!latest || latest.verifiedAt) throw new AppError('OTP_INVALID', HttpStatus.BAD_REQUEST, 'Invalid code');
    if (latest.attempts >= this.env.OTP_MAX_VERIFY_ATTEMPTS) {
      throw new AppError('OTP_TOO_MANY_ATTEMPTS', HttpStatus.TOO_MANY_REQUESTS, 'Too many attempts. Request a new code.');
    }
    if (latest.expiresAt.getTime() <= Date.now()) throw new AppError('OTP_EXPIRED', HttpStatus.BAD_REQUEST, 'Code expired');

    await this.db.update(otpRequests).set({ attempts: latest.attempts + 1 }).where(eq(otpRequests.id, latest.id));

    const expected = Buffer.from(latest.otpHash, 'hex');
    const actual = Buffer.from(this.hash(mobile, purpose, code.trim()), 'hex');
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
      throw new AppError('OTP_INVALID', HttpStatus.BAD_REQUEST, 'Invalid code');
    }
    await this.db.update(otpRequests).set({ verifiedAt: new Date() }).where(eq(otpRequests.id, latest.id));
    return latest.id;
  }

  /** Atomically marks a verified OTP as consumed. Returns false if it was already used. */
  async consume(otpId: string, tx: Pick<Db, 'update'> = this.db): Promise<boolean> {
    const rows = await tx
      .update(otpRequests)
      .set({ consumedAt: new Date() })
      .where(and(eq(otpRequests.id, otpId), isNull(otpRequests.consumedAt)))
      .returning({ id: otpRequests.id });
    return rows.length === 1;
  }
}
