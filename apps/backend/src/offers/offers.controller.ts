import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags, PartialType } from '@nestjs/swagger';
import { IsDateString, IsOptional, IsString, IsUrl, Length, MaxLength } from 'class-validator';
import { CustomerAuthGuard } from '../auth/customer-auth.guard';
import { AdminGuard, AdminPrincipal, CurrentAdmin, Roles } from '../admin/admin-auth';
import { OffersService } from './offers.service';

export class OfferDto {
  @ApiProperty() @IsString() @Length(1, 120) titleAr: string;
  @ApiProperty() @IsString() @Length(1, 120) titleEn: string;
  @ApiProperty() @IsString() @Length(1, 2000) descriptionAr: string;
  @ApiProperty() @IsString() @Length(1, 2000) descriptionEn: string;
  @ApiPropertyOptional() @IsOptional() @IsUrl({ protocols: ['https'], require_protocol: true }) imageUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(40) ctaLabelAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(40) ctaLabelEn?: string;
  @ApiPropertyOptional() @IsOptional() @IsUrl({ protocols: ['https'], require_protocol: true }) destinationUrl?: string;
  @ApiProperty() @IsDateString() startAt: string;
  @ApiProperty() @IsDateString() endAt: string;
}
export class UpdateOfferDto extends PartialType(OfferDto) {}

@ApiTags('offers')
@ApiBearerAuth()
@UseGuards(CustomerAuthGuard)
@Controller('offers')
export class OffersController {
  constructor(private readonly svc: OffersService) {}

  @Get()
  async list() {
    return { data: await this.svc.listActive() };
  }

  @Get(':id')
  async get(@Param('id', ParseUUIDPipe) id: string) {
    return { data: await this.svc.getActive(id) };
  }
}

@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(AdminGuard)
@Roles('super_admin', 'marketing_admin')
@Controller('admin/offers')
export class AdminOffersController {
  constructor(private readonly svc: OffersService) {}

  @Get()
  async list() {
    return { data: await this.svc.adminList() };
  }

  @Post()
  async create(@CurrentAdmin() a: AdminPrincipal, @Body() dto: OfferDto) {
    return { data: await this.svc.create(a.adminId, dto) };
  }

  @Patch(':id')
  async update(@CurrentAdmin() a: AdminPrincipal, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateOfferDto) {
    return { data: await this.svc.update(a.adminId, id, dto) };
  }

  @Post(':id/publish')
  @HttpCode(200)
  async publish(@CurrentAdmin() a: AdminPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    return { data: await this.svc.publish(a.adminId, id) };
  }

  @Post(':id/archive')
  @HttpCode(200)
  async archive(@CurrentAdmin() a: AdminPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    return { data: await this.svc.archive(a.adminId, id) };
  }

  @Post(':id/resend-notification')
  @HttpCode(200)
  async resend(@CurrentAdmin() a: AdminPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    return { data: await this.svc.resend(a.adminId, id) };
  }

  @Get('campaigns/stats')
  async stats() {
    return { data: await this.svc.campaignStats(), meta: { note: 'providerAccepted = accepted by push provider; it is not device delivery.' } };
  }
}
