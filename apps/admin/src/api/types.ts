// Shapes returned by the Zaad backend admin API (apps/backend). Keep in sync with it.

export type Role = 'super_admin' | 'marketing_admin' | 'customer_support';

export interface Admin {
  id: string;
  name: string;
  email: string;
  role: Role;
  active?: boolean;
  createdAt?: string;
}

export interface Dashboard {
  registeredCustomers: number;
  newCustomers7d: number;
  redemptionsPending: number;
  redemptionsCompleted: number;
  offersActive: number;
  offersScheduled: number;
  offersDraft: number;
}

export type OfferStatus = 'draft' | 'scheduled' | 'active' | 'expired' | 'archived';

export interface OfferInput {
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  imageUrl?: string;
  ctaLabelAr?: string;
  ctaLabelEn?: string;
  destinationUrl?: string;
  startAt: string;
  endAt: string;
}

export interface Offer extends OfferInput {
  id: string;
  status: OfferStatus; // effective (window-aware)
  storedStatus: OfferStatus;
  publishedAt: string | null;
  notificationDispatchedAt: string | null;
}

export interface CampaignResult {
  campaignId: string;
  recipients: number;
  providerAccepted: number;
  providerFailed: number;
}

export interface CampaignStat {
  id: string;
  offerId: string;
  kind: 'publish' | 'resend';
  createdAt: string;
  recipients: number;
  providerAccepted: number;
  providerFailed: number;
  opened: number;
}

export interface CustomerResult {
  erpCustomerId: string;
  name: string | null;
  mobileNumber: string;
  eligibleForApp: boolean;
  appAccount: { status: string; createdAt: string } | null;
}

export interface PointsEntry {
  id: string;
  occurredAt: string;
  type: 'earned' | 'redeemed' | 'refund_adjustment' | 'manual_adjustment';
  pointsDelta: number;
  balanceAfter: number | null;
  invoiceNumber: string | null;
  branchName: string | null;
}

export interface CustomerPoints {
  balance: { points: number; asOf: string | null };
  history: PointsEntry[];
  nextCursor: string | null;
}

export type InvoiceStatus = 'finished' | 'refunded' | 'partially_refunded' | 'cancelled';

export interface InvoiceSummary {
  invoiceId: string;
  invoiceNumber: string;
  issuedAt: string;
  branchName: string;
  total: number;
  status: InvoiceStatus;
}

export interface InvoiceDetail extends InvoiceSummary {
  lines: { name: string; quantity: number; unitPrice: number; discount: number | null; lineTotal: number }[];
  subTotal: number | null;
  discountTotal: number | null;
  taxTotal: number | null;
  pointsEarned: number | null;
  paymentMethod: 'cash' | 'card' | 'cash_and_card' | null;
}

export type RedemptionStatus = 'pending' | 'approved' | 'rejected' | 'expired' | 'completed' | 'failed';

export interface Redemption {
  id: string;
  reference: string;
  branchName: string;
  points: number;
  discountAmount: number;
  status: RedemptionStatus;
  createdAt: string;
  expiresAt: string;
  customerDecision: string | null;
  completedAt: string | null;
  erpCustomerId: string;
  lastErpError: string | null;
}

export interface AuditEntry {
  id: string;
  actorType: string;
  actorId: string | null;
  action: string;
  resourceType: string;
  resourceId: string | null;
  metadata: Record<string, unknown> | null;
  ipAddress: string | null;
  createdAt: string;
}

/** Branch directory (Branch Locator). `id` is the sheet's Branch ID (= ERP branch id). ONE phone per branch. */
export interface BranchInput {
  nameAr: string;
  nameEn: string | null;
  city: string;
  district: string | null;
  addressAr: string;
  addressEn: string | null;
  phone: string | null;
  mapsUrl: string | null;
  notes: string | null;
  active: boolean;
}
export interface Branch extends BranchInput {
  id: number;
  updatedAt?: string;
}
export interface ImportIssue {
  row: number;
  branchId?: number;
  field?: string;
  message: string;
}
export interface BranchImportReport {
  dryRun: boolean;
  applied: boolean;
  created: number[];
  updated: number[];
  unchanged: number[];
  notInFile: number[];
  errors: ImportIssue[];
  warnings: ImportIssue[];
}

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, status: number, message?: string) {
    super(message ?? code);
    this.code = code;
    this.status = status;
  }
}

/** Everything the dashboard can ask of the backend. Implemented by HttpAdminApi and DemoAdminApi. */
export interface AdminApi {
  readonly demo: boolean;
  login(email: string, password: string): Promise<{ accessToken: string; admin: Admin }>;
  me(): Promise<Admin>;
  dashboard(): Promise<Dashboard>;

  offers(): Promise<Offer[]>;
  createOffer(input: OfferInput): Promise<Offer>;
  updateOffer(id: string, input: Partial<OfferInput>): Promise<Offer>;
  publishOffer(id: string): Promise<Offer>;
  archiveOffer(id: string): Promise<Offer>;
  resendOffer(id: string): Promise<CampaignResult>;
  campaigns(): Promise<CampaignStat[]>;

  searchCustomers(q: { mobile?: string; customerId?: string }): Promise<CustomerResult[]>;
  customerPoints(id: string, cursor?: string | null): Promise<CustomerPoints>;
  customerInvoices(id: string, cursor?: string | null): Promise<{ items: InvoiceSummary[]; nextCursor: string | null }>;
  customerInvoice(id: string, invoiceId: string): Promise<InvoiceDetail>;

  redemptions(): Promise<Redemption[]>;
  auditLogs(): Promise<AuditEntry[]>;
  admins(): Promise<Admin[]>;
  createAdmin(input: { name: string; email: string; password: string; role: Role }): Promise<Admin>;
  updateAdmin(id: string, patch: { role?: Role; active?: boolean }): Promise<Admin>;

  branches(): Promise<Branch[]>;
  createBranch(input: BranchInput & { branchId: number }): Promise<Branch>;
  updateBranch(id: number, patch: Partial<BranchInput>): Promise<Branch>;
  importBranches(file: File, dryRun: boolean): Promise<BranchImportReport>;
}
