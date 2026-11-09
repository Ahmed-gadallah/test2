import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { AppError } from '../common/errors';
import { DB, Db } from '../db/db.module';
import { branches } from '../db/schema';
import { BranchRecord, ImportIssue, parseBranchRows } from './branch-import';

export type BranchRow = typeof branches.$inferSelect;

export interface BranchView {
  id: number;
  nameAr: string;
  nameEn: string | null;
  city: string;
  district: string | null;
  addressAr: string;
  addressEn: string | null;
  phone: string | null;
  mapsUrl: string | null;
  notes: string | null;
}

export interface AdminBranchView extends BranchView {
  active: boolean;
  updatedAt: string;
}

export interface ImportReport {
  dryRun: boolean;
  applied: boolean;
  created: number[];
  updated: number[];
  unchanged: number[];
  /** Branches already in the database that are not in the file. They are left untouched (never deleted). */
  notInFile: number[];
  errors: ImportIssue[];
  warnings: ImportIssue[];
}

const collator = new Intl.Collator('ar', { numeric: true, sensitivity: 'base' });
/** Stable, human order: city, then branch name with natural numbers (صيدلية 2 before صيدلية 10). */
export const byCityThenName = (a: { city: string; nameAr: string }, b: { city: string; nameAr: string }) =>
  collator.compare(a.city, b.city) || collator.compare(a.nameAr, b.nameAr);

export function toView(r: BranchRow): BranchView {
  return {
    id: r.branchId,
    nameAr: r.nameAr,
    nameEn: r.nameEn,
    city: r.city,
    district: r.district,
    addressAr: r.addressAr,
    addressEn: r.addressEn,
    phone: r.phone,
    mapsUrl: r.mapsUrl,
    notes: r.notes,
  };
}

const toAdminView = (r: BranchRow): AdminBranchView => ({ ...toView(r), active: r.active, updatedAt: r.updatedAt.toISOString() });

const FIELDS: (keyof BranchRecord)[] = ['nameAr', 'nameEn', 'city', 'district', 'addressAr', 'addressEn', 'phone', 'mapsUrl', 'notes', 'active'];
const same = (row: BranchRow, rec: BranchRecord) => FIELDS.every((f) => row[f] === rec[f]);

@Injectable()
export class BranchesService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Customer-facing list: ACTIVE branches only. */
  async listActive(): Promise<BranchView[]> {
    const rows = await this.db.select().from(branches).where(eq(branches.active, true));
    return rows.sort(byCityThenName).map(toView);
  }

  async getActive(id: number): Promise<BranchView> {
    const [row] = await this.db.select().from(branches).where(eq(branches.branchId, id));
    if (!row || !row.active) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'Branch not found');
    return toView(row);
  }

  async adminList(): Promise<AdminBranchView[]> {
    const rows = await this.db.select().from(branches);
    return rows.sort(byCityThenName).map(toAdminView);
  }

  async adminGet(id: number): Promise<AdminBranchView> {
    const [row] = await this.db.select().from(branches).where(eq(branches.branchId, id));
    if (!row) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'Branch not found');
    return toAdminView(row);
  }

  async create(rec: BranchRecord): Promise<AdminBranchView> {
    const [exists] = await this.db.select({ id: branches.branchId }).from(branches).where(eq(branches.branchId, rec.branchId));
    if (exists) throw new AppError('VALIDATION_FAILED', HttpStatus.CONFLICT, `Branch ID ${rec.branchId} already exists`);
    const [row] = await this.db.insert(branches).values(rec).returning();
    return toAdminView(row);
  }

  async update(id: number, patch: Partial<Omit<BranchRecord, 'branchId'>>): Promise<AdminBranchView> {
    const [row] = await this.db
      .update(branches)
      .set({ ...patch, updatedAt: new Date() })
      .where(eq(branches.branchId, id))
      .returning();
    if (!row) throw new AppError('NOT_FOUND', HttpStatus.NOT_FOUND, 'Branch not found');
    return toAdminView(row);
  }

  /**
   * Idempotent import: upsert by Branch ID inside one transaction. Any row error aborts the whole
   * import (nothing written) so a half-applied sheet can never reach customers. Branches missing
   * from the file are reported, not deleted or deactivated.
   */
  async importRows(rows: unknown[][], dryRun: boolean): Promise<ImportReport> {
    const parsed = parseBranchRows(rows);
    const report: ImportReport = {
      dryRun,
      applied: false,
      created: [],
      updated: [],
      unchanged: [],
      notInFile: [],
      errors: parsed.errors,
      warnings: parsed.warnings,
    };
    const ids = parsed.records.map((r) => r.branchId);
    const existing = await this.db.select().from(branches);
    const byId = new Map(existing.map((r) => [r.branchId, r]));
    for (const rec of parsed.records) {
      const row = byId.get(rec.branchId);
      if (!row) report.created.push(rec.branchId);
      else if (same(row, rec)) report.unchanged.push(rec.branchId);
      else report.updated.push(rec.branchId);
    }
    const inFile = new Set(ids);
    report.notInFile = existing.filter((r) => !inFile.has(r.branchId)).map((r) => r.branchId).sort((a, b) => a - b);
    if (dryRun || parsed.errors.length) return report;

    const changed = new Set([...report.created, ...report.updated]);
    await this.db.transaction(async (tx) => {
      for (const rec of parsed.records) {
        if (!changed.has(rec.branchId)) continue;
        const { branchId, ...rest } = rec;
        await tx
          .insert(branches)
          .values(rec)
          .onConflictDoUpdate({ target: branches.branchId, set: { ...rest, updatedAt: new Date() } });
      }
    });
    report.applied = true;
    return report;
  }
}
