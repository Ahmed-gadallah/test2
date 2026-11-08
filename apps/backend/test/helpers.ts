import 'reflect-metadata';
import { INestApplication } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import request from 'supertest';
import { hashAdminPassword } from '../src/admin/admin-auth';
import { createApp } from '../src/bootstrap';
import { loadEnv } from '../src/config/env';
import { DB, Db } from '../src/db/db.module';
import { runMigrations } from '../src/db/migrate';
import { adminUsers } from '../src/db/schema';
import { ErpAdapter } from '../src/erp/erp.adapter';
import { MockErpAdapter } from '../src/erp/mock/mock-erp.adapter';

export interface TestCtx {
  app: INestApplication;
  db: Db;
  erp: MockErpAdapter;
  http: () => ReturnType<typeof request>;
}

export async function setupApp(): Promise<TestCtx> {
  const env = loadEnv();
  await runMigrations(env.DATABASE_URL);
  const app = await createApp(env);
  await app.init();
  const db = app.get<Db>(DB);
  await db.execute(
    sql`truncate table push_deliveries, notifications, campaigns, offers, device_tokens, redemption_requests, refresh_sessions, otp_requests, users, admin_users, audit_logs restart identity cascade`,
  );
  return { app, db, erp: app.get(ErpAdapter) as MockErpAdapter, http: () => request(app.getHttpServer()) };
}

export const DEVICE = { deviceId: 'test-device-0001', platform: 'android' as const };

export async function registerCustomer(ctx: TestCtx, mobile = '0500000001', password = 'zaad1234') {
  await ctx.http().post('/api/v1/auth/send-otp').send({ mobile, purpose: 'register' }).expect(200);
  const v = await ctx.http().post('/api/v1/auth/verify-otp').send({ mobile, purpose: 'register', code: '123456' }).expect(200);
  const r = await ctx.http().post('/api/v1/auth/register').send({ verificationToken: v.body.data.verificationToken, password, ...DEVICE }).expect(201);
  return r.body.data as { accessToken: string; refreshToken: string };
}

export async function createAdmin(ctx: TestCtx, role: 'super_admin' | 'marketing_admin' | 'customer_support') {
  const email = `${role}@zaad.test`;
  const password = 'AdminPass12345';
  await ctx.db.insert(adminUsers).values({ name: role, email, role, passwordHash: await hashAdminPassword(password) }).onConflictDoNothing();
  const r = await ctx.http().post('/api/v1/admin/auth/login').send({ email, password }).expect(200);
  return r.body.data.accessToken as string;
}

export const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
