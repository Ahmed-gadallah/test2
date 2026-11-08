import { Controller, Get, Inject } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { sql } from 'drizzle-orm';
import { DB, Db } from './db/db.module';
import { ErpAdapter } from './erp/erp.adapter';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(@Inject(DB) private readonly db: Db, private readonly erp: ErpAdapter) {}

  @Get()
  async health() {
    let database = 'up';
    try {
      await this.db.execute(sql`select 1`);
    } catch {
      database = 'down';
    }
    return { data: { status: database === 'up' ? 'ok' : 'degraded', database, erpAdapter: this.erp.name } };
  }
}
