import { Controller, Get, HttpStatus, Inject, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { AppError } from '../common/errors';
import { ENV, Env } from '../config/env';
import { ErpAdapter } from '../erp/erp.adapter';
import { ErpNotConfiguredError, ErpUnavailableError } from '../erp/erp.types';
import { CurrentCustomer, CustomerAuthGuard, CustomerPrincipal } from '../auth/customer-auth.guard';
import { BalanceCache } from './balance-cache';

export class PageQuery {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 20;
}

/** Maps ERP failures to the app's error contract. Never returns fabricated fallback data (spec §18). */
export async function fromErp<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof ErpUnavailableError) throw new AppError('ERP_UNAVAILABLE', HttpStatus.SERVICE_UNAVAILABLE, 'ERP temporarily unavailable');
    if (err instanceof ErpNotConfiguredError) throw new AppError('ERP_NOT_CONFIGURED', HttpStatus.SERVICE_UNAVAILABLE, err.message);
    throw err;
  }
}

@ApiTags('customer')
@ApiBearerAuth()
@UseGuards(CustomerAuthGuard)
@Controller('customer')
export class CustomerController {
  constructor(
    private readonly balanceCache: BalanceCache,
    private readonly erp: ErpAdapter,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Get('profile')
  async profile(@CurrentCustomer() c: CustomerPrincipal) {
    const customer = await fromErp(() => this.erp.getCustomer(c.erpCustomerId));
    if (!customer) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'Customer record not found in ERP');
    // Only fields approved for display. identity_id, gender, age are intentionally NOT exposed.
    return { data: { customerId: customer.erpCustomerId, name: customer.name, mobileNumber: customer.mobileNumber } };
  }

  @Get('points')
  async points(@CurrentCustomer() c: CustomerPrincipal, @Query('refresh') refresh?: string) {
    const ttl = this.env.BALANCE_CACHE_SECONDS * 1000;
    const cached = this.balanceCache.get(c.erpCustomerId, ttl);
    let points: number;
    let asOf: Date;
    if (cached && refresh !== 'true') {
      ({ points, asOf } = cached);
    } else {
      const b = await fromErp(() => this.erp.getPointsBalance(c.erpCustomerId));
      points = b.points;
      asOf = b.asOf ?? new Date();
      this.balanceCache.set(c.erpCustomerId, points, asOf);
    }
    const perSar = this.env.POINTS_PER_SAR;
    return {
      data: {
        points,
        // Display conversion only (spec §8.3). The POS redeems whole SAR, so the value is floored.
        equivalentSar: Math.floor(Math.max(points, 0) / perSar),
        pointsPerSar: perSar,
        currency: 'SAR',
        asOf: asOf.toISOString(),
        source: 'erp',
      },
    };
  }

  @Get('points/history')
  async history(@CurrentCustomer() c: CustomerPrincipal, @Query() q: PageQuery) {
    const page = await fromErp(() => this.erp.getPointsHistory(c.erpCustomerId, q.cursor ?? null, q.limit));
    return { data: page.items, meta: { nextCursor: page.nextCursor } };
  }

  @Get('invoices')
  async invoices(@CurrentCustomer() c: CustomerPrincipal, @Query() q: PageQuery) {
    const page = await fromErp(() => this.erp.listInvoices(c.erpCustomerId, q.cursor ?? null, q.limit));
    return { data: page.items, meta: { nextCursor: page.nextCursor } };
  }

  @Get('invoices/:invoiceId')
  async invoice(@CurrentCustomer() c: CustomerPrincipal, @Param('invoiceId') invoiceId: string) {
    if (!/^[\w-]{1,64}$/.test(invoiceId)) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    // Adapter scopes by the session's ERP customer id → another customer's invoice is indistinguishable from "not found".
    const inv = await fromErp(() => this.erp.getInvoice(c.erpCustomerId, invoiceId));
    if (!inv) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'Invoice not found');
    return { data: inv };
  }

  @Get('app-config')
  appConfig() {
    return { data: { onlineStoreUrl: this.env.ONLINE_STORE_URL, pointsPerSar: this.env.POINTS_PER_SAR } };
  }
}
