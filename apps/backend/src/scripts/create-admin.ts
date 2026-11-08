/**
 * Creates the first Super Admin. Usage:
 *   ADMIN_EMAIL=... ADMIN_NAME=... ADMIN_PASSWORD=... npm run seed:admin
 * Password is read from the environment so it never appears in shell history arguments.
 */
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import { hashAdminPassword } from '../admin/admin-auth';
import { adminUsers } from '../db/schema';

async function main() {
  const { DATABASE_URL, ADMIN_EMAIL, ADMIN_NAME, ADMIN_PASSWORD, ADMIN_ROLE = 'super_admin' } = process.env;
  if (!DATABASE_URL || !ADMIN_EMAIL || !ADMIN_NAME || !ADMIN_PASSWORD) {
    throw new Error('DATABASE_URL, ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD are required');
  }
  if (!/^(?=.*[A-Za-z])(?=.*\d).{12,128}$/.test(ADMIN_PASSWORD)) throw new Error('Admin password must be 12+ chars with letters and digits');
  const pool = new Pool({ connectionString: DATABASE_URL });
  const db = drizzle(pool);
  await db
    .insert(adminUsers)
    .values({ email: ADMIN_EMAIL, name: ADMIN_NAME, role: ADMIN_ROLE as 'super_admin', passwordHash: await hashAdminPassword(ADMIN_PASSWORD) })
    .onConflictDoNothing();
  await pool.end();
  console.log(`Admin ${ADMIN_EMAIL} ensured (${ADMIN_ROLE})`);
}
main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
