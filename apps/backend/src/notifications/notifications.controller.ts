import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { AppError } from '../common/errors';
import { CurrentCustomer, CustomerAuthGuard, CustomerPrincipal } from '../auth/customer-auth.guard';
import { NotificationsService } from './notifications.service';

class ListQuery {
  @IsOptional()
  @IsDateString()
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 20;
}

class DeviceTokenDto {
  @ApiProperty()
  @IsString()
  @Length(10, 4096)
  token: string;

  @ApiProperty({ enum: ['android', 'ios', 'web'] })
  @IsIn(['android', 'ios', 'web'])
  platform: 'android' | 'ios' | 'web';
}

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(CustomerAuthGuard)
@Controller()
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  @Get('notifications')
  async list(@CurrentCustomer() c: CustomerPrincipal, @Query() q: ListQuery) {
    const r = await this.svc.list(c.userId, q.cursor ? new Date(q.cursor) : null, q.limit);
    return { data: r.items, meta: { nextCursor: r.nextCursor, unread: r.unread } };
  }

  @Patch('notifications/:id/read')
  async read(@CurrentCustomer() c: CustomerPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    if (!(await this.svc.markRead(c.userId, id))) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND);
    return { data: { ok: true } };
  }

  @Post('notifications/read-all')
  @HttpCode(200)
  async readAll(@CurrentCustomer() c: CustomerPrincipal) {
    await this.svc.markAllRead(c.userId);
    return { data: { ok: true } };
  }

  @Post('devices/register')
  @HttpCode(200)
  async register(@CurrentCustomer() c: CustomerPrincipal, @Body() dto: DeviceTokenDto) {
    await this.svc.registerDevice(c.userId, dto.token, dto.platform);
    return { data: { ok: true } };
  }

  @Delete('devices/:token')
  async remove(@CurrentCustomer() c: CustomerPrincipal, @Param('token') token: string) {
    if (token.length < 10 || token.length > 4096) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST);
    await this.svc.removeDevice(c.userId, token);
    return { data: { ok: true } };
  }
}
