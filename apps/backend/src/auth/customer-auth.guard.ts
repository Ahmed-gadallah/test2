import { CanActivate, createParamDecorator, ExecutionContext, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { and, eq, isNull } from 'drizzle-orm';
import type { Request } from 'express';
import { AppError } from '../common/errors';
import { ENV, Env } from '../config/env';
import { DB, Db } from '../db/db.module';
import { refreshSessions, users } from '../db/schema';
import type { AccessClaims } from './auth.service';

export interface CustomerPrincipal {
  userId: string;
  sessionId: string;
  erpCustomerId: string;
}

/**
 * Validates the access token AND that its session is still live, so logout and
 * password reset take effect immediately rather than after token expiry.
 */
@Injectable()
export class CustomerAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    @Inject(ENV) private readonly env: Env,
    @Inject(DB) private readonly db: Db,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request & { customer?: CustomerPrincipal }>();
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new AppError('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);

    let claims: AccessClaims;
    try {
      claims = await this.jwt.verifyAsync<AccessClaims>(token, { secret: this.env.JWT_ACCESS_SECRET, audience: 'zaad-customer' });
    } catch {
      throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);
    }

    const [live] = await this.db
      .select({ id: refreshSessions.id })
      .from(refreshSessions)
      .innerJoin(users, eq(users.id, refreshSessions.userId))
      .where(and(eq(refreshSessions.id, claims.sid), isNull(refreshSessions.revokedAt), eq(users.accountStatus, 'active')))
      .limit(1);
    if (!live) throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);

    req.customer = { userId: claims.sub, sessionId: claims.sid, erpCustomerId: claims.ecid };
    return true;
  }
}

export const CurrentCustomer = createParamDecorator((_: unknown, ctx: ExecutionContext): CustomerPrincipal => {
  return ctx.switchToHttp().getRequest<{ customer: CustomerPrincipal }>().customer;
});
