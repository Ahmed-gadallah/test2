import { Logger } from '@nestjs/common';
import { ErpAdapter } from '../erp.adapter';
import { ErpNotConfiguredError } from '../erp.types';

/**
 * Production adapter — INTENTIONALLY NOT IMPLEMENTED.
 *
 * There is no ERP API documentation yet (docs/erp-assessment.md §0). Per the
 * spec we do not invent endpoint names or response fields. Each method throws
 * ErpNotConfiguredError, which the API maps to a clear 503 for the app.
 *
 * When the vendor delivers the contract:
 *   1. implement each method here with timeouts (ERP_TIMEOUT_MS), retries only
 *      for idempotent reads, response validation (zod), and error mapping;
 *   2. add contract tests against the vendor staging environment;
 *   3. update docs/erp-integration-mapping.md status column.
 */
export class HttpErpAdapter extends ErpAdapter {
  readonly name = 'http';
  private readonly logger = new Logger(HttpErpAdapter.name);

  constructor(private readonly baseUrl: string) {
    super();
    this.logger.warn(`HTTP ERP adapter selected (${baseUrl}) but no vendor contract is implemented yet.`);
  }

  private notYet(capability: string): never {
    throw new ErpNotConfiguredError(capability);
  }

  findCustomersByMobile(): never { return this.notYet('customer lookup by mobile'); }
  getCustomer(): never { return this.notYet('customer profile'); }
  getPointsBalance(): never { return this.notYet('points balance'); }
  getPointsHistory(): never { return this.notYet('structured points ledger'); }
  listInvoices(): never { return this.notYet('invoice list'); }
  getInvoice(): never { return this.notYet('invoice details'); }
  listPendingRedemptions(): never { return this.notYet('redemption requests (does not exist in ERP)'); }
  getRedemption(): never { return this.notYet('redemption status'); }
  submitRedemptionDecision(): never { return this.notYet('redemption decision'); }
}
