import { loadEnv } from './env';

const base = {
  DATABASE_URL: 'postgres://x:y@localhost:5432/z',
  JWT_ACCESS_SECRET: 'a'.repeat(32),
  JWT_REFRESH_SECRET: 'b'.repeat(32),
  JWT_ADMIN_SECRET: 'c'.repeat(32),
  OTP_HASH_SECRET: 'd'.repeat(32),
};
const prod = { ...base, NODE_ENV: 'production', ERP_ADAPTER: 'http', ERP_BASE_URL: 'https://erp', OTP_PROVIDER: 'whatsapp', PUSH_PROVIDER: 'fcm', CORS_ORIGINS: 'https://admin.zaad.example' };

describe('environment safety rules', () => {
  it('refuses the mock ERP, console OTP/push and fixed OTP in production', () => {
    expect(() => loadEnv({ ...base, NODE_ENV: 'production', ERP_ADAPTER: 'mock' })).toThrow(/ERP_ADAPTER/);
    expect(() => loadEnv({ ...base, NODE_ENV: 'production', ERP_ADAPTER: 'http', ERP_BASE_URL: 'https://erp', OTP_PROVIDER: 'console', PUSH_PROVIDER: 'fcm' })).toThrow(/OTP_PROVIDER/);
    expect(() => loadEnv({ ...base, NODE_ENV: 'production', ERP_ADAPTER: 'http', ERP_BASE_URL: 'https://erp', OTP_PROVIDER: 'sms', PUSH_PROVIDER: 'fcm', OTP_DEV_FIXED_CODE: '123456' })).toThrow(/OTP_DEV_FIXED_CODE/);
  });

  it('accepts a production config with real providers', () => {
    expect(loadEnv(prod).ERP_ADAPTER).toBe('http');
  });

  it('refuses placeholder secrets, reused secrets, wildcard CORS and plain-HTTP ERP in production', () => {
    expect(() => loadEnv({ ...prod, JWT_ACCESS_SECRET: 'change-me-access-secret-at-least-32-chars' })).toThrow(/Placeholder/);
    expect(() => loadEnv({ ...prod, JWT_REFRESH_SECRET: 'a'.repeat(32) })).toThrow(/different/);
    expect(() => loadEnv({ ...prod, CORS_ORIGINS: '*' })).toThrow(/CORS_ORIGINS/);
    expect(() => loadEnv({ ...prod, ERP_BASE_URL: 'http://erp' })).toThrow(/HTTPS/);
  });

  it('rejects short secrets', () => {
    expect(() => loadEnv({ ...base, JWT_ACCESS_SECRET: 'short' })).toThrow(/JWT_ACCESS_SECRET/);
  });
});
