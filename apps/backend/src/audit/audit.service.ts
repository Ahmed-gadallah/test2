import { Global, Inject, Injectable, Module } from '@nestjs/common';
import { DB, Db } from '../db/db.module';
import { auditLogs } from '../db/schema';

export interface AuditEntry {
  actorType: 'admin' | 'customer' | 'system';
  actorId?: string | null;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  metadata?: Record<string, unknown>;
  ipAddress?: string | null;
}

/** Append-only audit trail. Never put passwords, OTPs or tokens in metadata. */
@Injectable()
export class AuditService {
  constructor(@Inject(DB) private readonly db: Db) {}
  async log(e: AuditEntry) {
    await this.db.insert(auditLogs).values({
      actorType: e.actorType,
      actorId: e.actorId ?? null,
      action: e.action,
      resourceType: e.resourceType,
      resourceId: e.resourceId ?? null,
      metadata: e.metadata ?? null,
      ipAddress: e.ipAddress ?? null,
    });
  }
}

@Global()
@Module({ providers: [AuditService], exports: [AuditService] })
export class AuditModule {}
