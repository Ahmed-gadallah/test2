/**
 * Internal ERP contract used by the backend.
 *
 * These are OUR types, not the vendor's API. They are shaped after the real
 * columns observed in the ERP database (workspace 0) via Metabase — see
 * docs/erp-integration-mapping.md — so that swapping the mock for the real
 * adapter only touches erp/http/*. Fields marked `| null` are not guaranteed
 * by the ERP and the UI must render without them (spec §11.2: never fabricate).
 */

export interface ErpCustomer {
  /** customer_0.id */
  erpCustomerId: string;
  /** customer_0.name — cashier-entered free text, may contain digits/noise */
  name: string | null;
  /** customer_0.phone_number, normalized to E.164 by the adapter */
  mobileNumber: string;
  /** Institutional / insurance / house accounts must not register (assessment G5). */
  eligibleForApp: boolean;
}

export interface ErpPointsBalance {
  /** customer_0.points */
  points: number;
  /** When the ERP produced this value; null if the API cannot tell us. */
  asOf: Date | null;
}

export type ErpPointsEntryType = 'earned' | 'redeemed' | 'refund_adjustment' | 'manual_adjustment';

export interface ErpPointsEntry {
  id: string;
  occurredAt: Date;
  type: ErpPointsEntryType;
  /** Signed, exactly as reported by the ERP. Never computed by us. */
  pointsDelta: number;
  balanceAfter: number | null;
  invoiceId: string | null;
  invoiceNumber: string | null;
  branchName: string | null;
  description: string | null;
}

export type ErpInvoiceStatus = 'finished' | 'refunded' | 'partially_refunded' | 'cancelled';

export interface ErpInvoiceSummary {
  invoiceId: string;
  /** Customer-facing number. Which ERP field this is is still OPEN (assessment G6). */
  invoiceNumber: string;
  issuedAt: Date;
  branchId: string;
  branchName: string;
  total: number;
  currency: 'SAR';
  status: ErpInvoiceStatus;
}

export interface ErpInvoiceLine {
  name: string;
  quantity: number;
  unitPrice: number;
  /** offer + voucher + invoice discounts per line (order_detail_0.item_*_discount) */
  discount: number | null;
  /** order_detail_0.item_points_discount */
  pointsDiscount: number | null;
  tax: number | null;
  lineTotal: number;
}

export interface ErpInvoiceDetail extends ErpInvoiceSummary {
  lines: ErpInvoiceLine[];
  subTotal: number | null;
  discountTotal: number | null;
  voucherDiscount: number | null;
  pointsUsed: number | null;
  pointsValue: number | null;
  taxTotal: number | null;
  /** orders_0.due_points_to_order — displayed, never computed */
  pointsEarned: number | null;
  paymentMethod: 'cash' | 'card' | 'cash_and_card' | null;
}

export type ErpRedemptionStatus = 'pending' | 'approved' | 'rejected' | 'expired' | 'completed' | 'failed';

/**
 * DOES NOT EXIST in the ERP today (assessment G1). This is the shape we will
 * ask the vendor to provide.
 */
export interface ErpRedemptionRequest {
  erpRequestId: string;
  erpCustomerId: string;
  branchId: string;
  branchName: string;
  points: number;
  discountAmount: number;
  currency: 'SAR';
  status: ErpRedemptionStatus;
  createdAt: Date;
  expiresAt: Date;
  completedAt: Date | null;
}

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

export class ErpUnavailableError extends Error {
  constructor(message = 'ERP unavailable', public readonly cause?: unknown) {
    super(message);
  }
}

export class ErpNotConfiguredError extends Error {
  constructor(capability: string) {
    super(`ERP capability not available yet: ${capability}. Pending vendor API contract.`);
  }
}

/** The ERP rejected a decision (expired, insufficient balance, already decided...). */
export class ErpDecisionRejectedError extends Error {
  constructor(public readonly reason: 'expired' | 'already_decided' | 'insufficient_balance' | 'not_found', public readonly current?: ErpRedemptionRequest) {
    super(`ERP rejected decision: ${reason}`);
  }
}
