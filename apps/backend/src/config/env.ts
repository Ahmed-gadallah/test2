import { z } from 'zod';

/**
 * All configuration comes from environment variables. Every variable is
 * documented in apps/backend/.env.example.
 *
 * Safety rules enforced here (startup fails if violated):
 *  - ERP_ADAPTER=mock is refused when NODE_ENV=production.
 *  - OTP_PROVIDER=console and OTP_DEV_FIXED_CODE are refused in production.
 *  - JWT secrets must be at least 32 characters.
 */
const schema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    DATABASE_URL: z.string().url(),
    CORS_ORIGINS: z.string().default('*'),

    JWT_ACCESS_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    JWT_ADMIN_SECRET: z.string().min(32),
    ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(60),
    VERIFICATION_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(600),

    OTP_PROVIDER: z.enum(['console', 'whatsapp', 'sms']).default('console'),
    OTP_FALLBACK_PROVIDER: z.enum(['none', 'sms']).default('none'),
    OTP_TTL_SECONDS: z.coerce.number().int().positive().default(300),
    OTP_MAX_VERIFY_ATTEMPTS: z.coerce.number().int().positive().default(5),
    OTP_RESEND_COOLDOWN_SECONDS: z.coerce.number().int().nonnegative().default(60),
    OTP_MAX_PER_HOUR: z.coerce.number().int().positive().default(5),
    OTP_DEV_FIXED_CODE: z.string().regex(/^\d{6}$/).optional(),

    ERP_ADAPTER: z.enum(['mock', 'http']).default('mock'),
    ERP_BASE_URL: z.string().url().optional(),
    ERP_TIMEOUT_MS: z.coerce.number().int().positive().default(8000),

    PUSH_PROVIDER: z.enum(['console', 'fcm']).default('console'),

    /** Display-only conversion agreed with the business (spec §8.1). Verified in ERP data: point_used / point_to_cash = 50. */
    POINTS_PER_SAR: z.coerce.number().int().positive().default(50),
    /** Short cache for the balance shown on screen. ERP stays authoritative. */
    BALANCE_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(30),
    ONLINE_STORE_URL: z.string().url().default('https://zaadonline.com'),
  })
  .superRefine((env, ctx) => {
    if (env.NODE_ENV === 'production') {
      if (env.ERP_ADAPTER === 'mock') {
        ctx.addIssue({ code: 'custom', path: ['ERP_ADAPTER'], message: 'Mock ERP adapter is forbidden in production' });
      }
      if (env.OTP_PROVIDER === 'console') {
        ctx.addIssue({ code: 'custom', path: ['OTP_PROVIDER'], message: 'Console OTP provider is forbidden in production' });
      }
      if (env.OTP_DEV_FIXED_CODE) {
        ctx.addIssue({ code: 'custom', path: ['OTP_DEV_FIXED_CODE'], message: 'Fixed OTP code is forbidden in production' });
      }
      if (env.PUSH_PROVIDER === 'console') {
        ctx.addIssue({ code: 'custom', path: ['PUSH_PROVIDER'], message: 'Console push provider is forbidden in production' });
      }
    }
    if (env.ERP_ADAPTER === 'http' && !env.ERP_BASE_URL) {
      ctx.addIssue({ code: 'custom', path: ['ERP_BASE_URL'], message: 'ERP_BASE_URL is required when ERP_ADAPTER=http' });
    }
  });

export type Env = z.infer<typeof schema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = schema.safeParse(source);
  if (!parsed.success) {
    const details = parsed.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
    throw new Error(`Invalid environment configuration:\n${details}`);
  }
  return parsed.data;
}

export const ENV = Symbol('ENV');
