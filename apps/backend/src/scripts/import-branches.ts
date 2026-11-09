/**
 * Imports the branches sheet into the app database. Idempotent (upsert by Branch ID).
 *   npm run import:branches -- path/to/Zaad_Branches.xlsx            # dry run: shows what would change
 *   npm run import:branches -- path/to/Zaad_Branches.xlsx --apply    # writes it
 * Any row error aborts the import; warnings (missing phone / link) are imported with the field empty.
 */
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from '../db/schema';
import type { Db } from '../db/db.module';
import { readBranchSheet } from '../branches/branch-import';
import { BranchesService } from '../branches/branches.service';

async function main() {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith('--'));
  const apply = args.includes('--apply');
  if (!process.env.DATABASE_URL || !file) throw new Error('Usage: DATABASE_URL=... npm run import:branches -- <file.xlsx> [--apply]');
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const svc = new BranchesService(drizzle(pool, { schema }) as unknown as Db);
    const r = await svc.importRows(await readBranchSheet(file), !apply);
    const list = (ids: number[]) => (ids.length ? ids.join(', ') : '—');
    console.log(`Created (${r.created.length}): ${list(r.created)}`);
    console.log(`Updated (${r.updated.length}): ${list(r.updated)}`);
    console.log(`Unchanged (${r.unchanged.length})`);
    if (r.notInFile.length) console.log(`In database but not in file — left untouched (${r.notInFile.length}): ${list(r.notInFile)}`);
    for (const w of r.warnings) console.log(`WARN  row ${w.row} (ID ${w.branchId ?? '?'}): ${w.message}`);
    for (const e of r.errors) console.log(`ERROR row ${e.row} (ID ${e.branchId ?? '?'}): ${e.message}`);
    if (r.errors.length) {
      console.log('\nNothing was imported: fix the errors above and run again.');
      process.exitCode = 1;
    } else console.log(r.applied ? '\nImport applied.' : '\nDry run only — re-run with --apply to write these changes.');
  } finally {
    await pool.end();
  }
}
main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
