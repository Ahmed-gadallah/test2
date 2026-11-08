import { Logger } from '@nestjs/common';

export interface PushMessage {
  title: string;
  body: string;
  imageUrl?: string | null;
  /** zaad://offers/<id>, zaad://redemptions/<id>, ... */
  deepLink: string;
  notificationId: string;
}

export interface PushResult {
  token: string;
  /** 'accepted' means the provider accepted it — NOT that the device received it (spec §15.4). */
  status: 'accepted' | 'failed' | 'invalid_token';
  providerMessageId?: string;
  error?: string;
}

export abstract class PushSender {
  abstract readonly name: string;
  abstract send(tokens: string[], message: PushMessage): Promise<PushResult[]>;
}

export class ConsolePushSender extends PushSender {
  readonly name = 'console';
  private readonly logger = new Logger('ConsolePush');
  async send(tokens: string[], m: PushMessage): Promise<PushResult[]> {
    this.logger.log(`[DEV PUSH] → ${tokens.length} device(s): "${m.title}" ${m.deepLink}`);
    return tokens.map((token) => ({ token, status: 'accepted' as const, providerMessageId: `console-${m.notificationId}` }));
  }
}

/** Firebase Cloud Messaging HTTP v1 — NOT IMPLEMENTED yet: needs the Zaad Firebase project + service account. */
export class FcmPushSender extends PushSender {
  readonly name = 'fcm';
  async send(tokens: string[]): Promise<PushResult[]> {
    return tokens.map((token) => ({ token, status: 'failed' as const, error: 'FCM not configured' }));
  }
}
