import { Injectable } from '@nestjs/common';

/** Short-lived cache of the displayed balance (per process). Invalidated after any redemption decision. */
@Injectable()
export class BalanceCache {
  private readonly map = new Map<string, { points: number; asOf: Date; cachedAt: number }>();
  get(id: string, ttlMs: number) {
    const v = this.map.get(id);
    return v && Date.now() - v.cachedAt < ttlMs ? v : null;
  }
  set(id: string, points: number, asOf: Date) {
    this.map.set(id, { points, asOf, cachedAt: Date.now() });
  }
  invalidate(id: string) {
    this.map.delete(id);
  }
}
