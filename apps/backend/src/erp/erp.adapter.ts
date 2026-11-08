import {
  ErpCustomer,
  ErpInvoiceDetail,
  ErpInvoiceSummary,
  ErpPointsBalance,
  ErpPointsEntry,
  ErpRedemptionRequest,
  Page,
} from './erp.types';

/**
 * The only door between the backend and the ERP (spec rule 24.20).
 * No other module may talk to the ERP.
 *
 * Every method that takes erpCustomerId MUST scope results to that customer;
 * callers pass the id taken from the authenticated session, never from input.
 */
export abstract class ErpAdapter {
  abstract readonly name: string;

  /** May return 0, 1 or many records. Many → registration must stop (spec §5.1). */
  abstract findCustomersByMobile(e164: string): Promise<ErpCustomer[]>;
  abstract getCustomer(erpCustomerId: string): Promise<ErpCustomer | null>;
  abstract getPointsBalance(erpCustomerId: string): Promise<ErpPointsBalance>;
  abstract getPointsHistory(erpCustomerId: string, cursor: string | null, limit: number): Promise<Page<ErpPointsEntry>>;
  abstract listInvoices(erpCustomerId: string, cursor: string | null, limit: number): Promise<Page<ErpInvoiceSummary>>;
  /** Returns null when the invoice does not exist OR belongs to another customer. */
  abstract getInvoice(erpCustomerId: string, invoiceId: string): Promise<ErpInvoiceDetail | null>;

  abstract listPendingRedemptions(erpCustomerId: string): Promise<ErpRedemptionRequest[]>;
  abstract getRedemption(erpCustomerId: string, erpRequestId: string): Promise<ErpRedemptionRequest | null>;
  /**
   * Must be idempotent on `idempotencyKey`: repeating the call returns the same
   * outcome and never deducts twice. The ERP validates expiry and live balance.
   */
  abstract submitRedemptionDecision(
    erpCustomerId: string,
    erpRequestId: string,
    decision: 'approve' | 'reject',
    idempotencyKey: string,
  ): Promise<ErpRedemptionRequest>;
}
