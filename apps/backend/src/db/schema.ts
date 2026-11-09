import { sql } from 'drizzle-orm';
import {
  pgTable,
  pgEnum,
  uuid,
  text,
  timestamp,
  integer,
  boolean,
  jsonb,
  numeric,
  uniqueIndex,
  index,
} from 'drizzle-orm/pg-core';

/**
 * Application database. Rule (spec §16): this database is NOT a second source of
 * truth. It never stores points balances, invoice contents or ledger entries.
 * It stores app accounts, sessions, OTPs, offers, notifications, redemption
 * workflow references and audit logs only.
 */

export const accountStatus = pgEnum('account_status', ['active', 'suspended']);
export const otpPurpose = pgEnum('otp_purpose', ['register', 'reset_password']);
export const otpChannel = pgEnum('otp_channel', ['console', 'whatsapp', 'sms']);
export const platform = pgEnum('platform', ['android', 'ios', 'web']);
export const offerStatus = pgEnum('offer_status', ['draft', 'scheduled', 'active', 'expired', 'archived']);
export const notificationType = pgEnum('notification_type', [
  'offer',
  'redemption_request',
  'redemption_completed',
  'redemption_rejected',
  'redemption_expired',
  'points_earned',
  'invoice_issued',
]);
export const redemptionStatus = pgEnum('redemption_status', [
  'pending',
  'approved',
  'rejected',
  'expired',
  'completed',
  'failed',
]);
export const adminRole = pgEnum('admin_role', ['super_admin', 'marketing_admin', 'customer_support']);

const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
};

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    erpCustomerId: text('erp_customer_id').notNull(),
    mobileNumber: text('mobile_number').notNull(),
    passwordHash: text('password_hash').notNull(),
    preferredLanguage: text('preferred_language').notNull().default('ar'),
    accountStatus: accountStatus('account_status').notNull().default('active'),
    failedLoginCount: integer('failed_login_count').notNull().default(0),
    lockedUntil: timestamp('locked_until', { withTimezone: true }),
    lastLoginAt: timestamp('last_login_at', { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    // One app account per ERP customer, and one per mobile number (spec §5.1).
    uniqueIndex('users_erp_customer_id_uq').on(t.erpCustomerId),
    uniqueIndex('users_mobile_number_uq').on(t.mobileNumber),
  ],
);

export const refreshSessions = pgTable(
  'refresh_sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    deviceIdentifier: text('device_identifier').notNull(),
    devicePlatform: platform('device_platform').notNull(),
    refreshTokenHash: text('refresh_token_hash').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    lastUsedAt: timestamp('last_used_at', { withTimezone: true }),
  },
  (t) => [index('refresh_sessions_user_idx').on(t.userId), uniqueIndex('refresh_sessions_hash_uq').on(t.refreshTokenHash)],
);

export const otpRequests = pgTable(
  'otp_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    mobileNumber: text('mobile_number').notNull(),
    purpose: otpPurpose('purpose').notNull(),
    otpHash: text('otp_hash').notNull(),
    deliveryChannel: otpChannel('delivery_channel').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    attempts: integer('attempts').notNull().default(0),
    verifiedAt: timestamp('verified_at', { withTimezone: true }),
    consumedAt: timestamp('consumed_at', { withTimezone: true }),
    requestIp: text('request_ip'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('otp_requests_mobile_created_idx').on(t.mobileNumber, t.createdAt)],
);

export const adminUsers = pgTable(
  'admin_users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    email: text('email').notNull(),
    passwordHash: text('password_hash').notNull(),
    role: adminRole('role').notNull(),
    active: boolean('active').notNull().default(true),
    failedLoginCount: integer('failed_login_count').notNull().default(0),
    lockedUntil: timestamp('locked_until', { withTimezone: true }),
    ...timestamps,
  },
  (t) => [uniqueIndex('admin_users_email_uq').on(sql`lower(${t.email})`)],
);

export const offers = pgTable(
  'offers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    titleAr: text('title_ar').notNull(),
    titleEn: text('title_en').notNull(),
    descriptionAr: text('description_ar').notNull(),
    descriptionEn: text('description_en').notNull(),
    imageUrl: text('image_url'),
    ctaLabelAr: text('cta_label_ar'),
    ctaLabelEn: text('cta_label_en'),
    destinationUrl: text('destination_url'),
    startAt: timestamp('start_at', { withTimezone: true }).notNull(),
    endAt: timestamp('end_at', { withTimezone: true }).notNull(),
    status: offerStatus('status').notNull().default('draft'),
    createdBy: uuid('created_by').references(() => adminUsers.id),
    publishedAt: timestamp('published_at', { withTimezone: true }),
    /** Set once when the mandatory publish notification is dispatched. Prevents duplicates on edit/republish. */
    notificationDispatchedAt: timestamp('notification_dispatched_at', { withTimezone: true }),
    ...timestamps,
  },
  (t) => [index('offers_status_window_idx').on(t.status, t.startAt, t.endAt)],
);

/** One row per explicit dispatch (initial publish or an admin-requested resend). */
export const campaigns = pgTable(
  'campaigns',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    offerId: uuid('offer_id')
      .notNull()
      .references(() => offers.id),
    triggeredBy: uuid('triggered_by').references(() => adminUsers.id),
    kind: text('kind').notNull(), // 'publish' | 'resend'
    recipients: integer('recipients').notNull().default(0),
    providerAccepted: integer('provider_accepted').notNull().default(0),
    providerFailed: integer('provider_failed').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('campaigns_offer_idx').on(t.offerId)],
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    type: notificationType('type').notNull(),
    offerId: uuid('offer_id').references(() => offers.id),
    campaignId: uuid('campaign_id').references(() => campaigns.id),
    redemptionId: uuid('redemption_id'),
    titleAr: text('title_ar').notNull(),
    titleEn: text('title_en').notNull(),
    bodyAr: text('body_ar').notNull(),
    bodyEn: text('body_en').notNull(),
    deepLink: text('deep_link').notNull(),
    readAt: timestamp('read_at', { withTimezone: true }),
    openedAt: timestamp('opened_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index('notifications_user_created_idx').on(t.userId, t.createdAt),
    // One in-app record per user per campaign → resends never duplicate silently.
    uniqueIndex('notifications_user_campaign_uq').on(t.userId, t.campaignId),
  ],
);

/** Push deliveries are tracked separately from in-app records (spec §13.3), linked by notification id. */
export const pushDeliveries = pgTable(
  'push_deliveries',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    notificationId: uuid('notification_id')
      .notNull()
      .references(() => notifications.id, { onDelete: 'cascade' }),
    deviceTokenId: uuid('device_token_id').notNull(),
    /** 'accepted' = provider accepted the message. This is NOT 'delivered'. */
    status: text('status').notNull(),
    providerMessageId: text('provider_message_id'),
    error: text('error'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('push_deliveries_notification_idx').on(t.notificationId)],
);

export const deviceTokens = pgTable(
  'device_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    deviceToken: text('device_token').notNull(),
    platform: platform('platform').notNull(),
    active: boolean('active').notNull().default(true),
    ...timestamps,
  },
  (t) => [uniqueIndex('device_tokens_token_uq').on(t.deviceToken), index('device_tokens_user_idx').on(t.userId)],
);

/**
 * Workflow mirror of ERP redemption requests. Stores references and the customer's
 * decision for audit + idempotency. The ERP decides the final outcome and
 * performs every deduction.
 */
export const redemptionRequests = pgTable(
  'redemption_requests',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    erpRequestId: text('erp_request_id').notNull(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id),
    erpCustomerId: text('erp_customer_id').notNull(),
    branchId: text('branch_id').notNull(),
    branchName: text('branch_name').notNull(),
    pointsRequested: integer('points_requested').notNull(),
    discountAmount: numeric('discount_amount', { precision: 12, scale: 2 }).notNull(),
    currency: text('currency').notNull().default('SAR'),
    status: redemptionStatus('status').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    customerDecision: text('customer_decision'), // 'approve' | 'reject'
    customerDecisionAt: timestamp('customer_decision_at', { withTimezone: true }),
    decisionIdempotencyKey: text('decision_idempotency_key'),
    erpCompletedAt: timestamp('erp_completed_at', { withTimezone: true }),
    lastErpError: text('last_erp_error'),
    ...timestamps,
  },
  (t) => [uniqueIndex('redemption_requests_erp_id_uq').on(t.erpRequestId), index('redemption_user_status_idx').on(t.userId, t.status)],
);

export const auditLogs = pgTable(
  'audit_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    actorType: text('actor_type').notNull(), // 'admin' | 'customer' | 'system'
    actorId: text('actor_id'),
    action: text('action').notNull(),
    resourceType: text('resource_type').notNull(),
    resourceId: text('resource_id'),
    metadata: jsonb('metadata').$type<Record<string, unknown>>(),
    ipAddress: text('ip_address'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('audit_logs_created_idx').on(t.createdAt), index('audit_logs_resource_idx').on(t.resourceType, t.resourceId)],
);
