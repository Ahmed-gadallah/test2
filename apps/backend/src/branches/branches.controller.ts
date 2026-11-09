import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiProperty, ApiPropertyOptional, ApiTags, PartialType } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Length, Max, MaxLength, Min } from 'class-validator';
import { AdminGuard, AdminPrincipal, CurrentAdmin, Roles } from '../admin/admin-auth';
import { AuditService } from '../audit/audit.service';
import { AppError } from '../common/errors';
import { BranchRecord, normalizeBranchPhone, readBranchSheet, validateMapsUrl } from './branch-import';
import { BranchesService } from './branches.service';

/**
 * Customer-facing branch directory. Public (no login needed): it holds only the information the
 * branches already publish (name, address, phone, map link). Inactive branches are never returned.
 */
@ApiTags('branches')
@Controller('branches')
export class BranchesController {
  constructor(private readonly svc: BranchesService) {}

  @Get()
  async list() {
    return { data: await this.svc.listActive() };
  }

  @Get(':id')
  async get(@Param('id', ParseIntPipe) id: number) {
    return { data: await this.svc.getActive(id) };
  }
}

class BranchFieldsDto {
  @ApiProperty() @IsString() @Length(1, 200) nameAr: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) nameEn?: string | null;
  @ApiProperty() @IsString() @Length(1, 100) city: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) district?: string | null;
  @ApiProperty() @IsString() @Length(1, 500) addressAr: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) addressEn?: string | null;
  @ApiPropertyOptional({ description: 'The ONE branch number (calls and delivery). Empty = none.' })
  @IsOptional() @IsString() @MaxLength(32) phone?: string | null;
  @ApiPropertyOptional({ description: 'https Google Maps link, stored as supplied. Empty = none.' })
  @IsOptional() @IsString() @MaxLength(2048) mapsUrl?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) notes?: string | null;
  @ApiProperty() @IsBoolean() active: boolean;
}
class CreateBranchDto extends BranchFieldsDto {
  @ApiProperty({ description: 'Branch ID from the branches sheet / ERP branch id' })
  @IsInt() @Min(0) @Max(2_147_483_647) branchId: number;
}
class UpdateBranchDto extends PartialType(BranchFieldsDto) {}

class ImportQuery {
  @IsOptional() @IsIn(['true', 'false']) dryRun?: 'true' | 'false';
}

const blank = (v: string | null | undefined) => (v === undefined ? undefined : v === null || v.trim() === '' ? null : v.trim().replace(/\s+/g, ' '));

/** Same rules as the sheet import; invalid phone/link is a 400 here (the admin is typing it now). */
function cleanFields(dto: Partial<BranchFieldsDto>): Partial<Omit<BranchRecord, 'branchId'>> {
  const out: Partial<Omit<BranchRecord, 'branchId'>> = {};
  for (const k of ['nameAr', 'city', 'addressAr'] as const) {
    if (dto[k] !== undefined) {
      const v = blank(dto[k]);
      if (!v) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, `${k} is required`);
      out[k] = v;
    }
  }
  for (const k of ['nameEn', 'district', 'addressEn', 'notes'] as const) if (dto[k] !== undefined) out[k] = blank(dto[k]);
  if (dto.phone !== undefined) {
    const raw = blank(dto.phone);
    const phone = raw === null ? null : normalizeBranchPhone(raw);
    if (phone === undefined) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'Invalid phone number');
    out.phone = phone;
  }
  if (dto.mapsUrl !== undefined) {
    const raw = blank(dto.mapsUrl);
    const url = raw === null ? null : validateMapsUrl(raw);
    if (raw !== null && !url) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'Location must be an https Google Maps link');
    out.mapsUrl = url;
  }
  if (dto.active !== undefined) out.active = dto.active;
  return out;
}

const MAX_SHEET_BYTES = 2 * 1024 * 1024;

@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(AdminGuard)
@Roles('super_admin', 'marketing_admin')
@Controller('admin/branches')
export class AdminBranchesController {
  constructor(
    private readonly svc: BranchesService,
    private readonly audit: AuditService,
  ) {}

  @Get()
  async list() {
    return { data: await this.svc.adminList() };
  }

  @Get(':id')
  async get(@Param('id', ParseIntPipe) id: number) {
    return { data: await this.svc.adminGet(id) };
  }

  @Post()
  async create(@CurrentAdmin() a: AdminPrincipal, @Body() dto: CreateBranchDto) {
    const fields = cleanFields(dto) as Omit<BranchRecord, 'branchId'>;
    const data = await this.svc.create({
      branchId: dto.branchId,
      ...fields,
      nameEn: fields.nameEn ?? null,
      district: fields.district ?? null,
      addressEn: fields.addressEn ?? null,
      phone: fields.phone ?? null,
      mapsUrl: fields.mapsUrl ?? null,
      notes: fields.notes ?? null,
    });
    await this.audit.log({ actorType: 'admin', actorId: a.adminId, action: 'branch.create', resourceType: 'branch', resourceId: String(data.id) });
    return { data };
  }

  @Patch(':id')
  async update(@CurrentAdmin() a: AdminPrincipal, @Param('id', ParseIntPipe) id: number, @Body() dto: UpdateBranchDto) {
    const patch = cleanFields(dto);
    const data = await this.svc.update(id, patch);
    await this.audit.log({
      actorType: 'admin',
      actorId: a.adminId,
      action: 'branch.update',
      resourceType: 'branch',
      resourceId: String(id),
      metadata: { fields: Object.keys(patch) },
    });
    return { data };
  }

  /**
   * Upload the branches .xlsx. `dryRun=true` (default) only reports what would change; `dryRun=false`
   * applies it. Upsert by Branch ID, so importing the same file twice changes nothing.
   */
  @Post('import')
  @HttpCode(200)
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_SHEET_BYTES, files: 1 } }))
  async import(@CurrentAdmin() a: AdminPrincipal, @Query() q: ImportQuery, @UploadedFile() file?: { buffer: Buffer; originalname: string; size: number }) {
    if (!file?.buffer?.length) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'Attach the branches .xlsx file as "file"');
    // .xlsx is a zip archive: reject anything else before parsing.
    if (file.buffer[0] !== 0x50 || file.buffer[1] !== 0x4b) throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'The file must be an .xlsx workbook');
    let rows: unknown[][];
    try {
      rows = await readBranchSheet(file.buffer);
    } catch {
      throw new AppError('VALIDATION_FAILED', HttpStatus.BAD_REQUEST, 'Could not read the workbook — upload the branches .xlsx template');
    }
    const dryRun = q.dryRun !== 'false';
    const report = await this.svc.importRows(rows, dryRun);
    if (report.applied) {
      await this.audit.log({
        actorType: 'admin',
        actorId: a.adminId,
        action: 'branches.import',
        resourceType: 'branch',
        metadata: { file: file.originalname.slice(0, 120), created: report.created.length, updated: report.updated.length, unchanged: report.unchanged.length, warnings: report.warnings.length },
      });
    }
    return { data: report };
  }
}
