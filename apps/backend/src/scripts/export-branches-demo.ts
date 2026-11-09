/**
 * Writes the DEMO data file used by the mobile app's demo data source and the admin demo build
 * (no backend). Real builds never read it: they load branches from GET /branches.
 *   npm run export:branches-demo -- path/to/Zaad_Branches.xlsx
 * Uses the same parser as the real import, so the demo shows exactly what the import would.
 */
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { parseBranchRows, readBranchSheet } from '../branches/branch-import';
import { byCityThenName } from '../branches/branches.service';

async function main() {
  const file = process.argv[2];
  if (!file) throw new Error('Usage: npm run export:branches-demo -- <file.xlsx>');
  const r = parseBranchRows(await readBranchSheet(file));
  if (r.errors.length) throw new Error(r.errors.map((e) => `row ${e.row}: ${e.message}`).join('\n'));
  const all = [...r.records].sort(byCityThenName).map(({ branchId, ...rest }) => ({ id: branchId, ...rest }));
  const root = path.resolve(__dirname, '../../..');
  const targets = [path.join(root, 'mobile/assets/demo/branches.json'), path.join(root, 'admin/src/api/demo-branches.json')];
  // The app only ever receives active branches; the admin demo shows all of them.
  writeFileSync(targets[0], JSON.stringify(all.filter((b) => b.active).map(({ active: _a, ...b }) => b), null, 1) + '\n');
  writeFileSync(targets[1], JSON.stringify(all, null, 1) + '\n');
  console.log(`Wrote ${all.length} branches to:\n  ${targets.join('\n  ')}`);
}
main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
