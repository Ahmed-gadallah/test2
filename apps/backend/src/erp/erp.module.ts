import { Global, Logger, Module } from '@nestjs/common';
import { ENV, Env } from '../config/env';
import { ErpAdapter } from './erp.adapter';
import { HttpErpAdapter } from './http/http-erp.adapter';
import { MockErpAdapter } from './mock/mock-erp.adapter';

@Global()
@Module({
  providers: [
    {
      provide: ErpAdapter,
      inject: [ENV],
      useFactory: (env: Env): ErpAdapter => {
        const logger = new Logger('ErpModule');
        if (env.ERP_ADAPTER === 'mock') {
          logger.warn('⚠️  MOCK ERP ADAPTER ACTIVE — fictional data, development/demo only.');
          return new MockErpAdapter(env.POINTS_PER_SAR);
        }
        return new HttpErpAdapter(env.ERP_BASE_URL!);
      },
    },
  ],
  exports: [ErpAdapter],
})
export class ErpModule {}
