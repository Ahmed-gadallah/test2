import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { RedemptionStatus } from '../api/types';
import { Badge, Card, Empty, ErrorBox, SkeletonRows, type Tone } from '../components/ui';
import { useI18n } from '../i18n';
import { useSession } from '../session';

export const redemptionTone = (s: RedemptionStatus): Tone =>
  ({ pending: 'warn', approved: 'blue', completed: 'ok', rejected: 'mute', expired: 'mute', failed: 'bad' })[s] as Tone;

export function RedemptionsPage() {
  const { t, num, sar, dateTime } = useI18n();
  const { api } = useSession();
  const q = useQuery({ queryKey: ['redemptions'], queryFn: () => api.redemptions(), refetchInterval: 15_000 });
  const [filter, setFilter] = useState<'all' | RedemptionStatus>('all');
  const statuses: ('all' | RedemptionStatus)[] = ['all', 'pending', 'completed', 'rejected', 'expired', 'failed'];
  const list = (q.data ?? []).filter((r) => filter === 'all' || r.status === filter);

  return (
    <>
      <div className="topbar"><h1 style={{ fontSize: 24 }}>{t.redemptions.title}</h1></div>
      <div className="content">
        <div className="alert alert-info small">{t.redemptions.note}</div>
        <div className="tabs">
          {statuses.map((s) => (
            <button key={s} className={`tab${filter === s ? ' on' : ''}`} onClick={() => setFilter(s)}>
              {s === 'all' ? t.redemptions.all : t.redemptions.st[s]}
              {q.data ? ` (${q.data.filter((r) => s === 'all' || r.status === s).length})` : ''}
            </button>
          ))}
        </div>
        <Card pad={false}>
          {q.isLoading ? <SkeletonRows rows={6} /> : q.error ? <div className="card-pad"><ErrorBox error={q.error} onRetry={() => q.refetch()} /></div> : !list.length ? <Empty>{t.redemptions.empty}</Empty> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>{t.redemptions.ref}</th><th>{t.redemptions.customer}</th><th>{t.customers.branch}</th><th>{t.redemptions.points}</th><th>{t.redemptions.value}</th><th>{t.redemptions.created}</th><th>{t.redemptions.status}</th></tr></thead>
                <tbody>
                  {list.map((r) => (
                    <tr key={r.id}>
                      <td className="ltr num" style={{ fontWeight: 700 }}>{r.reference}</td>
                      <td><Link to={`/customers/${r.erpCustomerId}`} className="ltr num">{r.erpCustomerId}</Link></td>
                      <td className="small">{r.branchName}</td>
                      <td className="num">{num(r.points)}</td>
                      <td className="num">{sar(r.discountAmount)}</td>
                      <td className="small">{dateTime(r.createdAt)}</td>
                      <td>
                        <Badge tone={redemptionTone(r.status)}>{t.redemptions.st[r.status]}</Badge>
                        {r.lastErpError && <div className="small" style={{ color: 'var(--bad)', marginTop: 4 }}>{r.lastErpError}</div>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
