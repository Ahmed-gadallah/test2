import {
  Body,
  CanActivate,
  Controller,
  createParamDecorator,
  ExecutionContext,
  HttpCode,
  HttpStatus,
  Inject,
  Injectable,
  Ip,
  Post,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { ApiProperty, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { hash as argonHash, verify as argonVerify } from '@node-rs/argon2';
import { IsEmail, IsString, MaxLength } from 'class-validator';
import { and, eq, sql } from 'drizzle-orm';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service';
import { AppError } from '../common/errors';
import { ENV, Env } from '../config/env';
import { DB, Db } from '../db/db.module';
import { adminUsers } from '../db/schema';

export type AdminRole = 'super_admin' | 'marketing_admin' | 'customer_support';
export interface AdminPrincipal {
  adminId: string;
  role: AdminRole;
}

const ROLES_KEY = 'admin_roles';
/** Authorization is enforced HERE on the server, never only by hiding UI (spec §22). */
export const Roles = (...roles: AdminRole[]) => SetMetadata(ROLES_KEY, roles);

export const ADMIN_ARGON = { memoryCost: 19_456, timeCost: 2, parallelism: 1 } as const;
export const hashAdminPassword = (p: string) => argonHash(p, ADMIN_ARGON);

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
    @Inject(ENV) private readonly env: Env,
    @Inject(DB) private readonly db: Db,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request & { admin?: AdminPrincipal }>();
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new AppError('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    let claims: { sub: string };
    try {
      claims = await this.jwt.verifyAsync(token, { secret: this.env.JWT_ADMIN_SECRET, audience: 'zaad-admin', algorithms: ['HS256'] });
    } catch {
      throw new AppError('SESSION_EXPIRED', HttpStatus.UNAUTHORIZED);
    }
    // Role is read from the DB on every request so demotion/deactivation is immediate.
    const [admin] = await this.db.select({ id: adminUsers.id, role: adminUsers.role }).from(adminUsers).where(and(eq(adminUsers.id, claims.sub), eq(adminUsers.active, true)));
    if (!admin) throw new AppError('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);

    const required = this.reflector.getAllAndOverride<AdminRole[] | undefined>(ROLES_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (!required || required.length === 0) throw new AppError('FORBIDDEN', HttpStatus.FORBIDDEN, 'Endpoint has no role policy'); // deny by default
    if (!required.includes(admin.role)) throw new AppError('FORBIDDEN', HttpStatus.FORBIDDEN);
    req.admin = { adminId: admin.id, role: admin.role };
    return true;
  }
}

export const CurrentAdmin = createParamDecorator((_: unknown, ctx: ExecutionContext): AdminPrincipal => ctx.switchToHttp().getRequest<{ admin: AdminPrincipal }>().admin);

class AdminLoginDto {
  @ApiProperty() @IsEmail() @MaxLength(200) email: string;
  @ApiProperty() @IsString() @MaxLength(128) password: string;
}

const DUMMY = argonHash('timing-equalizer', ADMIN_ARGON);

@ApiTags('admin')
@Controller('admin/auth')
export class AdminAuthController {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(ENV) private readonly env: Env,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
  ) {}

  @Post('login')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  async login(@Body() dto: AdminLoginDto, @Ip() ip: string) {
    const [admin] = await this.db.select().from(adminUsers).where(eq(sql`lower(${adminUsers.email})`, dto.email.toLowerCase()));
    if (admin?.lockedUntil && admin.lockedUntil.getTime() > Date.now()) {
      throw new AppError('ACCOUNT_LOCKED', HttpStatus.TOO_MANY_REQUESTS, 'Too many failed attempts. Try again later.');
    }
    const ok = await argonVerify(admin?.passwordHash ?? (await DUMMY), dto.password);
    if (!admin || !ok || !admin.active) {
      if (admin) {
        const max = this.env.LOGIN_MAX_FAILURES;
        const lockMs = this.env.LOGIN_LOCK_MINUTES * 60_000;
        await this.db
          .update(adminUsers)
          .set({
            failedLoginCount: sql`case when ${adminUsers.failedLoginCount} + 1 >= ${max} then 0 else ${adminUsers.failedLoginCount} + 1 end`,
            lockedUntil: sql`case when ${adminUsers.failedLoginCount} + 1 >= ${max} then now() + (${lockMs} || ' milliseconds')::interval else ${adminUsers.lockedUntil} end`,
          })
          .where(eq(adminUsers.id, admin.id));
      }
      await this.audit.log({ actorType: 'admin', actorId: admin?.id ?? null, action: 'admin.login_failed', resourceType: 'admin', ipAddress: ip });
      throw new AppError('INVALID_CREDENTIALS', HttpStatus.UNAUTHORIZED);
    }
    await this.db.update(adminUsers).set({ failedLoginCount: 0, lockedUntil: null }).where(eq(adminUsers.id, admin.id));
    await this.audit.log({ actorType: 'admin', actorId: admin.id, action: 'admin.login', resourceType: 'admin', resourceId: admin.id, ipAddress: ip });
    const accessToken = await this.jwt.signAsync({ sub: admin.id }, { secret: this.env.JWT_ADMIN_SECRET, audience: 'zaad-admin', expiresIn: this.env.ADMIN_TOKEN_TTL_SECONDS });
    return { data: { accessToken, admin: { id: admin.id, name: admin.name, email: admin.email, role: admin.role } } };
  }
}
