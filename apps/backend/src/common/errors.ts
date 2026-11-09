import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';

/**
 * Stable machine-readable error codes. The mobile app maps these to localized
 * messages; it never shows raw server text.
 */
export type ErrorCode =
  | 'VALIDATION_FAILED'
  | 'PAYLOAD_TOO_LARGE'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'RATE_LIMITED'
  | 'INVALID_MOBILE'
  | 'MOBILE_NOT_REGISTERED'
  | 'ACCOUNT_EXISTS'
  | 'ACCOUNT_NEEDS_SUPPORT'
  | 'ACCOUNT_NOT_ELIGIBLE'
  | 'OTP_INVALID'
  | 'OTP_EXPIRED'
  | 'OTP_TOO_MANY_ATTEMPTS'
  | 'OTP_COOLDOWN'
  | 'INVALID_CREDENTIALS'
  | 'ACCOUNT_SUSPENDED'
  | 'ACCOUNT_LOCKED'
  | 'SESSION_EXPIRED'
  | 'ERP_UNAVAILABLE'
  | 'ERP_NOT_CONFIGURED'
  | 'REDEMPTION_EXPIRED'
  | 'REDEMPTION_ALREADY_DECIDED'
  | 'REDEMPTION_DECISION_PENDING'
  | 'OFFER_INVALID_STATE'
  | 'INTERNAL';

export class AppError extends HttpException {
  constructor(
    public readonly code: ErrorCode,
    status: HttpStatus,
    message?: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super({ code, message: message ?? code, details }, status);
  }
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exceptions');

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();

    if (exception instanceof AppError) {
      const body = exception.getResponse() as { code: string; message: string; details?: unknown };
      return res.status(exception.getStatus()).json({ error: body });
    }
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const raw = exception.getResponse();
      const code: ErrorCode =
        status === 400
          ? 'VALIDATION_FAILED'
          : status === 401
            ? 'UNAUTHENTICATED'
            : status === 403
              ? 'FORBIDDEN'
              : status === 404
                ? 'NOT_FOUND'
                : status === 429
                  ? 'RATE_LIMITED'
                  : 'INTERNAL';
      const message =
        typeof raw === 'object' && raw && 'message' in raw
          ? Array.isArray((raw as { message: unknown }).message)
            ? ((raw as { message: string[] }).message).join('; ')
            : String((raw as { message: unknown }).message)
          : String(raw);
      return res.status(status).json({ error: { code, message } });
    }

    // body-parser errors (oversized or malformed bodies) are client errors, not 500s.
    const bp = exception as { type?: string; status?: number };
    if (bp && typeof bp.status === 'number' && bp.status >= 400 && bp.status < 500 && typeof bp.type === 'string') {
      const tooLarge = bp.type === 'entity.too.large';
      return res
        .status(tooLarge ? 413 : 400)
        .json({ error: { code: tooLarge ? 'PAYLOAD_TOO_LARGE' : 'VALIDATION_FAILED', message: tooLarge ? 'Request body too large' : 'Malformed request body' } });
    }

    // Never leak internals. Log without request bodies (may contain OTPs/passwords).
    this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    return res.status(500).json({ error: { code: 'INTERNAL', message: 'Unexpected error' } });
  }
}
