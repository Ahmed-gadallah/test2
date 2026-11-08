import { Controller, Get, HttpCode, Ip, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentCustomer, CustomerAuthGuard, CustomerPrincipal } from '../auth/customer-auth.guard';
import { RedemptionService } from './redemption.service';

@ApiTags('redemption')
@ApiBearerAuth()
@UseGuards(CustomerAuthGuard)
@Controller('redemption')
export class RedemptionController {
  constructor(private readonly svc: RedemptionService) {}

  @Get('pending')
  async pending(@CurrentCustomer() c: CustomerPrincipal) {
    return { data: await this.svc.pending(c.userId, c.erpCustomerId) };
  }

  @Get('history')
  async history(@CurrentCustomer() c: CustomerPrincipal) {
    return { data: await this.svc.history(c.userId) };
  }

  @Get(':id')
  async get(@CurrentCustomer() c: CustomerPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    return { data: await this.svc.get(c.userId, id) };
  }

  @Post(':id/approve')
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  async approve(@CurrentCustomer() c: CustomerPrincipal, @Param('id', ParseUUIDPipe) id: string, @Ip() ip: string) {
    return { data: await this.svc.decide(c.userId, id, 'approve', ip ?? null) };
  }

  @Post(':id/reject')
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  async reject(@CurrentCustomer() c: CustomerPrincipal, @Param('id', ParseUUIDPipe) id: string, @Ip() ip: string) {
    return { data: await this.svc.decide(c.userId, id, 'reject', ip ?? null) };
  }
}
