import { Body, Controller, Get, HttpStatus, Inject, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsIn, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { desc, eq, sql } from 'drizzle-orm';
import { AuditService } from '../audit/audit.service';
import { AppError } from '../common/errors';
import { normalizeSaudiMobile } from '../common/phone';
import { fromErp, PageQuery } from '../customer/customer.controller';
import { DB, Db } from '../db/db.module';
import { adminUsers, auditLogs, redemptionRequests, users } from '../db/schema';
import { ErpAdapter } from '../erp/erp.adapter';
import { toView } from '../redemption/redemption.service';
import { AdminGuard, AdminPrincipal, CurrentAdmin, hashAdminPassword, Roles } from './admin-auth';

class CustomerSearchQuery {
  @IsOptional() @IsString() @MaxLength(32) mobile?: string;
  @IsOptional() @Matches(/^\d{1,12}$/) customerId?: string;
}

class CreateAdminDto {
  @ApiProperty() @IsString() @Length(2, 100) name: string;
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @Matches(/^(?=.*[A-Za-z])(?=.*\d).{12,128}$/, { message: 'Admin password: 12+ chars with letters and digits' }) password: string;
  @ApiProperty({ enum: ['super_admin', 'marketing_admin', 'customer_support'] })
  @IsIn(['super_admin', 'marketing_admin', 'customer_support'])
  role: 'super_admin' | 'marketing_admin' | 'customer_support';
}

/**
 * Customer Support is READ-ONLY by construction: there is no endpoint here that
 * modifies customer records, points, invoices or redemptions — for any role.
 */
@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly erp: ErpAdapter,
    private readonly audit: AuditService,
  ) {}

  @Get('dashboard')
  @Roles('super_admin', 'marketing_admin', 'customer_support')
  async dashboard() {
    const [[u], [r]] = await Promise.all([
      this.db.select({ total: sql<number>`count(*)::int`, last7d: sql<number>`count(*) filter (where created_at > now() - interval '7 days')::int` }).from(users),
      this.db.select({ pending: sql<number>`count(*) filter (where status = 'pending')::int`, completed: sql<number>`count(*) filter (where status = 'completed')::int` }).from(redemptionRequests),
    ]);
    return { data: { registeredCustomers: u.total, newCustomers7d: u.last7d, redemptionsPending: r.pending, redemptionsCompleted: r.completed } };
  }

  @Get('customers')
  @Roles('super_admin', 'customer_support')
  async search(@CurrentAdmin() a: AdminPrincipal, @Query() q: CustomerSearchQuery) {
    let results;
    if (q.customerId) {
      const c = await fromErp(() => this.erp.getCustomer(q.customerId!));
      results = c ? [c] : [];
    } else if (q.mobile) {
      const m = normalizeSaudiMobile(q.mobile);
      if (!m) throw new AppError('INVALID_MOBILE', HttpStatus.BAD_REQUEST);
      results = await fromErp(() => this.erp.findCustomersByMobile(m));
    } else {
      throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'mobile or customerId is required');
    }
    await this.audit.log({ actorType: 'admin', actorId: a.adminId, action: 'customer.search', resourceType: 'customer', metadata: { by: q.customerId ? 'id' : 'mobile', count: results.length } });
    const linked = results.length
      ? await this.db.select({ erpCustomerId: users.erpCustomerId, status: users.accountStatus, createdAt: users.createdAt }).from(users).where(sql`${users.erpCustomerId} in ${results.map((c) => c.erpCustomerId)}`)
      : [];
    return { data: results.map((c) => ({ ...c, appAccount: linked.find((l) => l.erpCustomerId === c.erpCustomerId) ?? null })) };
  }

  @Get('customers/:erpCustomerId/points')
  @Roles('super_admin', 'customer_support')
  async points(@CurrentAdmin() a: AdminPrincipal, @Param('erpCustomerId') id: string, @Query() q: PageQuery) {
    await this.audit.log({ actorType: 'admin', actorId: a.adminId, action: 'customer.view_points', resourceType: 'customer', resourceId: id });
    const [balance, history] = await Promise.all([fromErp(() => this.erp.getPointsBalance(id)), fromErp(() => this.erp.getPointsHistory(id, q.cursor ?? null, q.limit))]);
    return { data: { balance, history: history.items }, meta: { nextCursor: history.nextCursor } };
  }

  @Get('customers/:erpCustomerId/invoices')
  @Roles('super_admin', 'customer_support')
  async invoices(@CurrentAdmin() a: AdminPrincipal, @Param('erpCustomerId') id: string, @Query() q: PageQuery) {
    await this.audit.log({ actorType: 'admin', actorId: a.adminId, action: 'customer.view_invoices', resourceType: 'customer', resourceId: id });
    const page = await fromErp(() => this.erp.listInvoices(id, q.cursor ?? null, q.limit));
    return { data: page.items, meta: { nextCursor: page.nextCursor } };
  }

  @Get('redemptions')
  @Roles('super_admin', 'customer_support')
  async redemptions() {
    const rows = await this.db.select().from(redemptionRequests).orderBy(desc(redemptionRequests.createdAt)).limit(200);
    return { data: rows.map((r) => ({ ...toView(r), erpCustomerId: r.erpCustomerId, lastErpError: r.lastErpError })) };
  }

  @Get('audit-logs')
  @Roles('super_admin')
  async auditLogs() {
    return { data: await this.db.select().from(auditLogs).orderBy(desc(auditLogs.createdAt)).limit(200) };
  }

  @Get('admins')
  @Roles('super_admin')
  async admins() {
    return { data: await this.db.select({ id: adminUsers.id, name: adminUsers.name, email: adminUsers.email, role: adminUsers.role, active: adminUsers.active, createdAt: adminUsers.createdAt }).from(adminUsers) };
  }

  @Post('admins')
  @Roles('super_admin')
  async createAdmin(@CurrentAdmin() a: AdminPrincipal, @Body() dto: CreateAdminDto) {
    const [exists] = await this.db.select({ id: adminUsers.id }).from(adminUsers).where(eq(sql`lower(${adminUsers.email})`, dto.email.toLowerCase()));
    if (exists) throw new AppError('ACCOUNT_EXISTS', HttpStatus.CONFLICT);
    const [created] = await this.db
      .insert(adminUsers)
      .values({ name: dto.name, email: dto.email, role: dto.role, passwordHash: await hashAdminPassword(dto.password) })
      .returning({ id: adminUsers.id, name: adminUsers.name, email: adminUsers.email, role: adminUsers.role });
    await this.audit.log({ actorType: 'admin', actorId: a.adminId, action: 'admin.created', resourceType: 'admin', resourceId: created.id, metadata: { role: dto.role } });
    return { data: created };
  }
}
