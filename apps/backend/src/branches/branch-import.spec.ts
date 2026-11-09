import path from 'node:path';
import { normalizeBranchPhone, parseActive, parseBranchRows, readBranchSheet, validateMapsUrl } from './branch-import';

const HEADER = ['كود الفرع (Branch ID)', 'اسم الفرع بالعربي *', 'اسم الفرع بالإنجليزي', 'المدينة *', 'المنطقة / الحي', 'العنوان بالتفصيل بالعربي *', 'العنوان بالإنجليزي', 'رقم هاتف الفرع *', 'Location', 'الفرع نشط؟ * (نعم/لا)'];
const row = (o: Partial<Record<string, unknown>> = {}) => [
  o.id ?? 7, o.nameAr ?? 'صيدلية زاد 2', o.nameEn ?? 'zaad pharmacy 2', o.city ?? 'حائل', o.district ?? 'الحوطي', o.addressAr ?? 'الحوطي', o.addressEn ?? 'Al-Hawti',
  'phone' in o ? o.phone : 555162783, 'url' in o ? o.url : 'https://maps.app.goo.gl/yuVmY2zjZyLK6M2m8', o.active ?? 'نعم',
];

describe('branch sheet parsing', () => {
  it('reads the real Zaad sheet: 53 branches, one phone each, Excel-dropped leading zero restored', async () => {
    const rows = await readBranchSheet(path.join(__dirname, '../../test/fixtures/zaad-branches.xlsx'));
    const r = parseBranchRows(rows);
    expect(r.errors).toEqual([]);
    expect(r.records).toHaveLength(53);
    expect(new Set(r.records.map((b) => b.branchId)).size).toBe(53);
    const b0 = r.records.find((b) => b.branchId === 0)!; // Branch ID 0 is a real branch (ERP Zad48 Baqaa)
    expect(b0).toMatchObject({ nameAr: 'صيدلية زاد الدوائية 48', city: 'بقعاء', phone: '+966541418264', mapsUrl: 'https://maps.app.goo.gl/BB8rfs9zdyUzd7a38', active: true });
    // 11 branches have no phone in the sheet: imported with phone = null and a warning, never invented.
    const noPhone = r.records.filter((b) => b.phone === null).map((b) => b.branchId).sort((a, b) => a - b);
    expect(noPhone).toEqual([7, 21, 23, 26, 27, 32, 37, 38, 46, 50, 60]);
    expect(r.warnings.filter((w) => w.field === 'phone')).toHaveLength(11);
    expect(r.records.every((b) => b.mapsUrl?.startsWith('https://'))).toBe(true);
  });

  it('maps columns by header text, not position, and accepts an optional Notes column', () => {
    const header = [...HEADER].reverse().concat('ملاحظات');
    const data = [...row()].reverse().concat('  مفتوح 24 ساعة ');
    const r = parseBranchRows([header, data]);
    expect(r.errors).toEqual([]);
    expect(r.records[0]).toMatchObject({ branchId: 7, city: 'حائل', notes: 'مفتوح 24 ساعة', phone: '+966555162783' });
  });

  it('rejects duplicate Branch IDs and missing required values (whole sheet, nothing partial)', () => {
    const r = parseBranchRows([HEADER, row({ id: 1 }), row({ id: 1 }), row({ id: 2, nameAr: ' ' }), row({ id: 'x' })]);
    expect(r.errors.map((e) => e.message)).toEqual([
      'Duplicate Branch ID (also on row 2)',
      'Arabic name is required',
      'Branch ID is missing or not a whole number',
    ]);
  });

  it('missing required column is a sheet-level error', () => {
    const r = parseBranchRows([HEADER.filter((h) => h !== 'Location'), row().slice(0, 9)]);
    expect(r.errors[0].message).toContain('mapsUrl');
    expect(r.records).toEqual([]);
  });

  it('active flag: نعم/لا (and yes/no); anything else is an error, never assumed', () => {
    expect([parseActive('نعم'), parseActive('لا'), parseActive('Yes'), parseActive(false), parseActive('ربما'), parseActive(null)]).toEqual([true, false, true, false, null, null]);
    const r = parseBranchRows([HEADER, row({ active: 'لا' }), row({ id: 8, active: '' })]);
    expect(r.records[0].active).toBe(false);
    expect(r.errors[0]).toMatchObject({ row: 3, field: 'active' });
  });

  it('phone: one number, normalised; unknown formats are errors, empty is allowed', () => {
    expect(normalizeBranchPhone(541418264)).toBe('+966541418264');
    expect(normalizeBranchPhone('055 516 2783')).toBe('+966555162783');
    expect(normalizeBranchPhone('+966 55 516 2783')).toBe('+966555162783');
    expect(normalizeBranchPhone('0165321234')).toBe('+966165321234');
    expect(normalizeBranchPhone('920012345')).toBe('920012345');
    expect(normalizeBranchPhone(null)).toBeNull();
    expect(normalizeBranchPhone('')).toBeNull();
    expect(normalizeBranchPhone('12345')).toBeUndefined();
    expect(normalizeBranchPhone(5.5)).toBeUndefined();
    const r = parseBranchRows([HEADER, row({ phone: 'call us' })]);
    expect(r.errors[0]).toMatchObject({ field: 'phone' });
  });

  it('maps links: kept exactly as supplied when they are https Google Maps; otherwise null + warning (no substitution)', () => {
    for (const ok of ['https://maps.app.goo.gl/BB8rfs9zdyUzd7a38', 'https://goo.gl/maps/ZkBvcHuGJmrkSdAo6', 'https://www.google.com/maps/place/Zaad/@27.5,41.7,17z', 'https://maps.google.com/?q=27.5,41.7']) {
      expect(validateMapsUrl(ok)).toBe(ok);
    }
    for (const bad of ['http://maps.app.goo.gl/x', 'https://goo.gl/abc', 'https://evil.example/maps', 'https://www.google.com/search?q=x', 'javascript:alert(1)', 'not a url', 'https://user:pw@maps.google.com/']) {
      expect(validateMapsUrl(bad)).toBeNull();
    }
    const r = parseBranchRows([HEADER, row({ url: 'https://example.com/where' }), row({ id: 8, url: null })]);
    expect(r.errors).toEqual([]);
    expect(r.records.map((b) => b.mapsUrl)).toEqual([null, null]);
    expect(r.warnings.filter((w) => w.field === 'mapsUrl')).toHaveLength(2);
  });

  it('skips blank rows', () => {
    const r = parseBranchRows([HEADER, [null, null, '', null], row()]);
    expect(r.records).toHaveLength(1);
  });
});
