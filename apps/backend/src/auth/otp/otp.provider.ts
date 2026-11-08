import { Logger } from '@nestjs/common';
import { maskMobile } from '../../common/phone';

export type OtpChannel = 'console' | 'whatsapp' | 'sms';

export abstract class OtpSender {
  abstract readonly channel: OtpChannel;
  abstract send(mobileE164: string, code: string, purpose: 'register' | 'reset_password'): Promise<void>;
}

/** Development only — prints the code to the server log. Refused in production by env validation. */
export class ConsoleOtpSender extends OtpSender {
  readonly channel = 'console' as const;
  private readonly logger = new Logger('ConsoleOtp');
  async send(mobile: string, code: string, purpose: string) {
    this.logger.warn(`[DEV OTP] ${maskMobile(mobile)} purpose=${purpose} code=${code}`);
  }
}

/**
 * WhatsApp Business Platform (authentication template) — NOT IMPLEMENTED.
 * Needs: a Meta BSP account, an approved authentication template in Arabic and
 * English, and credentials. Business decision + cost review pending (spec §5.1).
 */
export class WhatsAppOtpSender extends OtpSender {
  readonly channel = 'whatsapp' as const;
  async send(): Promise<void> {
    throw new Error('WhatsApp OTP provider not configured');
  }
}

/** Saudi SMS gateway with a CST-registered sender ID — NOT IMPLEMENTED (provider not chosen). */
export class SmsOtpSender extends OtpSender {
  readonly channel = 'sms' as const;
  async send(): Promise<void> {
    throw new Error('SMS OTP provider not configured');
  }
}
