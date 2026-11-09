import { normalizeSaudiMobile } from '../common/phone';

/**
 * Pure parsing + validation of the branches sheet (Zaad_Branches_Template). No I/O here so it is
 * shared by the CLI import, the admin upload and the tests.
 *
 * Rules (from the Branch Locator brief):
 *  - The sheet is the source of truth: values are trimmed, nothing is invented or "corrected"
 *    beyond restoring the leading 0 Excel drops from phone numbers stored as numbers.
 *  - Branch ID is the unique key (it matches ERP branch_0.id). Duplicate IDs abort the import.
 *  - ONE phone per branch. A missing phone is allowed (warning); an unrecognisable one is an error.
 *  - A missing or non-Google-Maps link is stored as null (warning) — never substituted.
 */

export interface BranchRecord {
  branchId: number;
  nameAr: string;
  nameEn: string | null;
  city: string;
  district: string | null;
  addressAr: string;
  addressEn: string | null;
  phone: string | null;
  mapsUrl: string | null;
  notes: string | null;
  active: boolean;
}

export interface ImportIssue {
  /** 1-based sheet row (header = row 1). 0 = whole sheet. */
  row: number;
  branchId?: number;
  field?: keyof BranchRecord;
  message: string;
}

export interface ParseResult {
  records: BranchRecord[];
  errors: ImportIssue[];
  warnings: ImportIssue[];
}

type Field = keyof BranchRecord;

/** Header recognition. Order matters: the first matching rule wins for each header cell. */
const HEADER_RULES: { field: Field; test: (h: string) => boolean }[] = [
  { field: 'branchId', test: (h) => h.includes('branch id') || h.includes('كود الفرع') || h === 'id' },
  { field: 'nameAr', test: (h) => h.includes('اسم') && h.includes('عرب') },
  { field: 'nameEn', test: (h) => (h.includes('اسم') && h.includes('انجليز')) || h === 'name (en)' || h === 'name en' },
  { field: 'addressAr', test: (h) => h.includes('عنوان') && h.includes('عرب') },
  { field: 'addressEn', test: (h) => h.includes('عنوان') && h.includes('انجليز') },
  { field: 'district', test: (h) => h.includes('الحي') || h.includes('المنطقة') || h.includes('district') },
  { field: 'city', test: (h) => h.includes('المدينة') || h === 'city' },
  { field: 'phone', test: (h) => h.includes('هاتف') || h.includes('جوال') || h.includes('phone') },
  { field: 'mapsUrl', test: (h) => h.includes('location') || h.includes('الموقع') || h.includes('خرائط') || h.includes('maps') },
  { field: 'active', test: (h) => h.includes('نشط') || h.includes('active') },
  { field: 'notes', test: (h) => h.includes('ملاحظات') || h.includes('notes') },
];
const REQUIRED_COLUMNS: Field[] = ['branchId', 'nameAr', 'city', 'addressAr', 'phone', 'mapsUrl', 'active'];

/** Normalises header text: lowercase, unify alef forms (الإنجليزي → الانجليزي), collapse spaces. */
function normHeader(v: unknown): string {
  return String(v ?? '')
    .toLowerCase()
    .replace(/[إأآ]/g, 'ا')
    .replace(/\s+/g, ' ')
    .trim();
}

function text(v: unknown, max: number): string | null {
  if (v === null || v === undefined) return null;
  const s = (v instanceof Date ? v.toISOString() : String(v)).replace(/\s+/g, ' ').trim();
  if (!s) return null;
  return s.length > max ? s.slice(0, max) : s;
}

const TRUE_VALUES = new Set(['نعم', 'yes', 'y', 'true', '1', 'active', 'نشط']);
const FALSE_VALUES = new Set(['لا', 'no', 'n', 'false', '0', 'inactive', 'غير نشط']);

export function parseActive(v: unknown): boolean | null {
  if (typeof v === 'boolean') return v;
  const s = text(v, 20)?.toLowerCase();
  if (!s) return null;
  if (TRUE_VALUES.has(s)) return true;
  if (FALSE_VALUES.has(s)) return false;
  return null;
}

/**
 * One branch phone. Accepts what the sheet contains: numbers with the leading 0 dropped by Excel
 * (541418264), 05XXXXXXXX, +9665..., Saudi landlines (01XXXXXXXX → +9661XXXXXXX) and 92XXXXXXX
 * unified numbers. Returns undefined when the value is present but not a recognisable number.
 */
export function normalizeBranchPhone(v: unknown): string | null | undefined {
  if (v === null || v === undefined) return null;
  const raw = typeof v === 'number' ? (Number.isInteger(v) ? String(v) : '') : String(v).trim();
  if (!raw) return typeof v === 'number' ? undefined : null;
  const mobile = normalizeSaudiMobile(raw);
  if (mobile) return mobile;
  const digits = raw
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/\D/g, '');
  if (/^92\d{7}$/.test(digits)) return digits; // unified number, dialled as-is
  if (/^800\d{7}$/.test(digits)) return digits; // toll free
  let national = digits.startsWith('966') ? digits.slice(3) : digits;
  if (national.startsWith('0')) national = national.slice(1);
  if (/^1[1-7]\d{7}$/.test(national)) return `+966${national}`; // landline: 01X area code + 7 digits
  return undefined;
}

const MAPS_HOSTS = new Set(['maps.app.goo.gl', 'maps.google.com', 'www.google.com', 'google.com', 'goo.gl', 'www.google.com.sa', 'google.com.sa']);

/**
 * Accepts only https Google Maps links (short or long form) and returns them unchanged.
 * Does NOT resolve the link or extract coordinates: many share links carry none, and the
 * app opens the link itself, so Google resolves it to the exact place the branch saved.
 */
export function validateMapsUrl(v: unknown): string | null {
  const s = text(v, 2048);
  if (!s) return null;
  let u: URL;
  try {
    u = new URL(s);
  } catch {
    return null;
  }
  if (u.protocol !== 'https:' || u.username || u.password || u.port) return null;
  const host = u.hostname.toLowerCase();
  if (!MAPS_HOSTS.has(host)) return null;
  if (host === 'goo.gl' && !u.pathname.startsWith('/maps/')) return null;
  if ((host.endsWith('google.com') || host.endsWith('google.com.sa')) && host !== 'maps.google.com' && !u.pathname.startsWith('/maps')) return null;
  if (host === 'maps.app.goo.gl' && u.pathname.length < 2) return null;
  return s;
}

function parseBranchId(v: unknown): number | null {
  if (typeof v === 'number') return Number.isInteger(v) && v >= 0 && v <= 2_147_483_647 ? v : null;
  const s = text(v, 12);
  if (s && /^\d{1,9}$/.test(s)) return Number(s);
  return null;
}

/** Parses the first sheet (rows[0] = header). */
export function parseBranchRows(rows: unknown[][]): ParseResult {
  const errors: ImportIssue[] = [];
  const warnings: ImportIssue[] = [];
  const records: BranchRecord[] = [];
  if (!rows.length) return { records, errors: [{ row: 0, message: 'The sheet is empty' }], warnings };

  const col = new Map<Field, number>();
  rows[0].forEach((cell, i) => {
    const h = normHeader(cell);
    if (!h) return;
    const rule = HEADER_RULES.find((r) => !col.has(r.field) && r.test(h));
    if (rule) col.set(rule.field, i);
  });
  const missing = REQUIRED_COLUMNS.filter((f) => !col.has(f));
  if (missing.length) {
    return { records, errors: [{ row: 1, message: `Missing required column(s): ${missing.join(', ')}` }], warnings };
  }
  const cell = (r: unknown[], f: Field) => (col.has(f) ? r[col.get(f)!] : undefined);

  const seen = new Map<number, number>();
  for (let i = 1; i < rows.length; i++) {
    const r = rows[i] ?? [];
    const rowNo = i + 1;
    if (r.every((c) => c === null || c === undefined || String(c).trim() === '')) continue;

    const rowErrors: ImportIssue[] = [];
    const branchId = parseBranchId(cell(r, 'branchId'));
    const at = (field: Field, message: string): ImportIssue => ({ row: rowNo, branchId: branchId ?? undefined, field, message });
    if (branchId === null) rowErrors.push(at('branchId', 'Branch ID is missing or not a whole number'));
    else if (seen.has(branchId)) rowErrors.push(at('branchId', `Duplicate Branch ID (also on row ${seen.get(branchId)})`));
    else seen.set(branchId, rowNo);

    const nameAr = text(cell(r, 'nameAr'), 200);
    const city = text(cell(r, 'city'), 100);
    const addressAr = text(cell(r, 'addressAr'), 500);
    if (!nameAr) rowErrors.push(at('nameAr', 'Arabic name is required'));
    if (!city) rowErrors.push(at('city', 'City is required'));
    if (!addressAr) rowErrors.push(at('addressAr', 'Arabic address is required'));

    const active = parseActive(cell(r, 'active'));
    if (active === null) rowErrors.push(at('active', 'Active must be نعم or لا'));

    const phone = normalizeBranchPhone(cell(r, 'phone'));
    if (phone === undefined) rowErrors.push(at('phone', `Unrecognised phone number "${String(cell(r, 'phone'))}"`));
    else if (phone === null) warnings.push(at('phone', 'No phone number — the Call button will be hidden'));

    const rawUrl = text(cell(r, 'mapsUrl'), 2048);
    const mapsUrl = validateMapsUrl(rawUrl);
    if (!rawUrl) warnings.push(at('mapsUrl', 'No location link — "View location" will be hidden'));
    else if (!mapsUrl) warnings.push(at('mapsUrl', `Not a valid https Google Maps link, not imported: "${rawUrl}"`));

    if (rowErrors.length) {
      errors.push(...rowErrors);
      continue;
    }
    records.push({
      branchId: branchId!,
      nameAr: nameAr!,
      nameEn: text(cell(r, 'nameEn'), 200),
      city: city!,
      district: text(cell(r, 'district'), 100),
      addressAr: addressAr!,
      addressEn: text(cell(r, 'addressEn'), 500),
      phone: phone ?? null,
      mapsUrl,
      notes: text(cell(r, 'notes'), 1000),
      active: active!,
    });
  }
  if (!records.length && !errors.length) errors.push({ row: 0, message: 'The sheet has no branch rows' });
  return { records, errors, warnings };
}

/** Reads the first worksheet of an .xlsx (path or Buffer). */
export async function readBranchSheet(input: string | Buffer): Promise<unknown[][]> {
  // read-excel-file ships CJS under its "./node" export; required at runtime (this project uses node10 resolution).
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { readSheet } = require('read-excel-file/node') as { readSheet: (i: string | Buffer, sheet?: number) => Promise<unknown[][]> };
  return readSheet(input, 1);
}
