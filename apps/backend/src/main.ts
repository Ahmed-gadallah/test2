import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { createApp } from './bootstrap';
import { loadEnv } from './config/env';
import { runMigrations } from './db/migrate';

async function main() {
  const env = loadEnv();
  await runMigrations(env.DATABASE_URL);
  const app = await createApp(env);
  await app.listen(env.PORT, '0.0.0.0');
  Logger.log(`Zaad API on :${env.PORT}  (docs: /docs, ERP adapter: ${env.ERP_ADAPTER})`, 'Bootstrap');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
