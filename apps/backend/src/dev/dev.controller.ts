import { Body, Controller, HttpCode, HttpStatus, Inject, Post } from '@nestjs/common';
import { ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { eq } from 'drizzle-orm';
import { AppError } from '../common/errors';
import { normalizeSaudiMobile } from '../common/phone';
import { DB, Db } from '../db/db.module';
import { users } from '../db/schema';
import { ErpAdapter } from '../erp/erp.adapter';
import { MockErpAdapter } from '../erp/mock/mock-erp.adapter';
import { RedemptionService } from '../redemption/redemption.service';

class SimulateRedemptionDto {
  @ApiProperty({ example: '0500000001' }) @IsString() mobile: string;
  @ApiProperty({ example: 1000 }) @IsInt() @Min(50) @Max(1_000_000) points: number;
  @ApiProperty({ example: 120, required: false }) @IsOptional() @IsInt() @Min(10) @Max(3600) ttlSeconds: number = 120;
  @ApiProperty({ required: false }) @IsOptional() @IsInt() @Min(0) @Max(10) branchIndex: number = 0;
}

class OutageDto {
  @ApiProperty() @IsBoolean() on: boolean;
}

/**
 * DEV/DEMO ONLY. Registered only when ERP_ADAPTER=mock (which production refuses).
 * Simulates what a cashier would do at the POS so the full redemption flow can be demonstrated.
 */
@ApiTags('dev (mock only)')
@Controller('dev')
export class DevController {
  constructor(
    private readonly erp: ErpAdapter,
    private readonly redemption: RedemptionService,
    @Inject(DB) private readonly db: Db,
  ) {}

  private mock(): MockErpAdapter {
    if (!(this.erp instanceof MockErpAdapter)) throw new AppError('FORBIDDEN', HttpStatus.FORBIDDEN);
    return this.erp;
  }

  @Post('simulate/cashier-redemption')
  async simulate(@Body() dto: SimulateRedemptionDto) {
    const m = normalizeSaudiMobile(dto.mobile);
    if (!m) throw new AppError('INVALID_MOBILE', HttpStatus.BAD_REQUEST);
    const [user] = await this.db.select().from(users).where(eq(users.mobileNumber, m));
    if (!user) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'No app account for this mobile');
    const req = this.mock().simulateCashierRequest(user.erpCustomerId, dto.points, dto.ttlSeconds, dto.branchIndex);
    // Stands in for the future ERP webhook "redemption.created".
    const { row } = await this.redemption.ingest(user.id, req);
    return { data: { id: row.id, reference: req.erpRequestId, points: req.points, discountAmount: req.discountAmount, expiresAt: req.expiresAt } };
  }

  @Post('simulate/erp-outage')
  @HttpCode(200)
  outage(@Body() dto: OutageDto) {
    this.mock().simulateOutage = dto.on;
    return { data: { simulateOutage: dto.on } };
  }
}
