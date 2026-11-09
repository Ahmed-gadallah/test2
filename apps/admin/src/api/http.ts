import type {
  Admin,
  AdminApi,
  AuditEntry,
  Branch,
  BranchImportReport,
  BranchInput,
  CampaignResult,
  CampaignStat,
  CustomerPoints,
  CustomerResult,
  Dashboard,
  InvoiceDetail,
  InvoiceSummary,
  Offer,
  OfferInput,
  Redemption,
  Role,
} from './types';
import { ApiError } from './types';

/** Real backend client. Token lives in sessionStorage (cleared when the tab closes). */
export class HttpAdminApi implements AdminApi {
  readonly demo = false;
  private readonly baseUrl: string;
  private readonly getToken: () => string | null;
  private readonly onUnauthorized: () => void;
  constructor(baseUrl: string, getToken: () => string | null, onUnauthorized: () => void) {
    this.baseUrl = baseUrl;
    this.getToken = getToken;
    this.onUnauthorized = onUnauthorized;
  }

  private async req<T>(method: string, path: string, body?: unknown, auth = true): Promise<{ data: T; meta?: Record<string, unknown> }> {
    let res: Response;
    const form = body instanceof FormData;
    try {
      res = await fetch(this.baseUrl + path, {
        method,
        headers: {
          ...(body !== undefined && !form ? { 'Content-Type': 'application/json' } : {}),
          ...(auth && this.getToken() ? { Authorization: `Bearer ${this.getToken()}` } : {}),
        },
        body: form ? body : body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch {
      throw new ApiError('NETWORK', 0);
    }
    const json = await res.json().catch(() => null);
    if (!res.ok) {
      if (res.status === 401 && auth) this.onUnauthorized();
      throw new ApiError(json?.error?.code ?? 'INTERNAL', res.status, json?.error?.message);
    }
    return json;
  }

  private async data<T>(method: string, path: string, body?: unknown, auth = true) {
    return (await this.req<T>(method, path, body, auth)).data;
  }

  login(email: string, password: string) {
    return this.data<{ accessToken: string; admin: Admin }>('POST', '/admin/auth/login', { email, password }, false);
  }
  me() { return this.data<Admin>('GET', '/admin/me'); }
  dashboard() { return this.data<Dashboard>('GET', '/admin/dashboard'); }

  offers() { return this.data<Offer[]>('GET', '/admin/offers'); }
  createOffer(input: OfferInput) { return this.data<Offer>('POST', '/admin/offers', clean(input)); }
  updateOffer(id: string, input: Partial<OfferInput>) { return this.data<Offer>('PATCH', `/admin/offers/${id}`, clean(input)); }
  publishOffer(id: string) { return this.data<Offer>('POST', `/admin/offers/${id}/publish`); }
  archiveOffer(id: string) { return this.data<Offer>('POST', `/admin/offers/${id}/archive`); }
  resendOffer(id: string) { return this.data<CampaignResult>('POST', `/admin/offers/${id}/resend-notification`); }
  campaigns() { return this.data<CampaignStat[]>('GET', '/admin/offers/campaigns/stats'); }

  searchCustomers(q: { mobile?: string; customerId?: string }) {
    const qs = new URLSearchParams(Object.entries(q).filter(([, v]) => v) as [string, string][]).toString();
    return this.data<CustomerResult[]>('GET', `/admin/customers?${qs}`);
  }
  async customerPoints(id: string, cursor?: string | null): Promise<CustomerPoints> {
    const r = await this.req<{ balance: CustomerPoints['balance']; history: CustomerPoints['history'] }>(
      'GET',
      `/admin/customers/${encodeURIComponent(id)}/points?limit=30${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
    );
    return { ...r.data, nextCursor: (r.meta?.nextCursor as string | null) ?? null };
  }
  async customerInvoices(id: string, cursor?: string | null) {
    const r = await this.req<InvoiceSummary[]>('GET', `/admin/customers/${encodeURIComponent(id)}/invoices?limit=20${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    return { items: r.data, nextCursor: (r.meta?.nextCursor as string | null) ?? null };
  }
  customerInvoice(id: string, invoiceId: string) {
    return this.data<InvoiceDetail>('GET', `/admin/customers/${encodeURIComponent(id)}/invoices/${encodeURIComponent(invoiceId)}`);
  }

  redemptions() { return this.data<Redemption[]>('GET', '/admin/redemptions'); }
  auditLogs() { return this.data<AuditEntry[]>('GET', '/admin/audit-logs'); }
  admins() { return this.data<Admin[]>('GET', '/admin/admins'); }
  createAdmin(input: { name: string; email: string; password: string; role: Role }) { return this.data<Admin>('POST', '/admin/admins', input); }
  updateAdmin(id: string, patch: { role?: Role; active?: boolean }) { return this.data<Admin>('PATCH', `/admin/admins/${id}`, patch); }

  branches() { return this.data<Branch[]>('GET', '/admin/branches'); }
  // Empty strings are sent as-is: the backend stores them as "not provided" (null).
  createBranch(input: BranchInput & { branchId: number }) { return this.data<Branch>('POST', '/admin/branches', input); }
  updateBranch(id: number, patch: Partial<BranchInput>) { return this.data<Branch>('PATCH', `/admin/branches/${id}`, patch); }
  importBranches(file: File, dryRun: boolean) {
    const fd = new FormData();
    fd.append('file', file);
    return this.data<BranchImportReport>('POST', `/admin/branches/import?dryRun=${dryRun}`, fd);
  }
}

/** Drop empty optional strings so the backend's validators don't reject "" as a URL. */
function clean<T extends object>(o: T): T {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== '' && v !== undefined)) as T;
}
