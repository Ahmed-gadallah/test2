import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { Badge, Card, Empty, ErrorBox, Kpi, SkeletonRows } from '../components/ui';
import { useI18n } from '../i18n';
import { useSession } from '../session';
import { redemptionTone } from './Redemptions';

export function OverviewPage() {
  const { t, num, sar, dateTime, fwd } = useI18n();
  const { api, can } = useSession();
  const dash = useQuery({ queryKey: ['dashboard'], queryFn: () => api.dashboard() });
  const marketing = can('super_admin', 'marketing_admin');
  const support = can('super_admin', 'customer_support');
  const campaigns = useQuery({ queryKey: ['campaigns'], queryFn: () => api.campaigns(), enabled: marketing });
  const offers = useQuery({ queryKey: ['offers'], queryFn: () => api.offers(), enabled: marketing });
  const redemptions = useQuery({ queryKey: ['redemptions'], queryFn: () => api.redemptions(), enabled: support });
  const title = (id: string) => offers.data?.find((o) => o.id === id)?.titleAr ?? '—';

  return (
    <>
      <div className="topbar"><h1 style={{ fontSize: 24 }}>{t.overview.title}</h1></div>
      <div className="content">
        {dash.error ? <ErrorBox error={dash.error} onRetry={() => dash.refetch()} /> : null}
        <div className="grid-kpi">
          <Kpi hero label={t.overview.registered} value={dash.data ? num(dash.data.registeredCustomers) : '…'} hint={dash.data ? `+${num(dash.data.newCustomers7d)} ${t.overview.new7d}` : undefined} />
          <Kpi label={t.overview.activeOffers} value={dash.data ? num(dash.data.offersActive) : '…'} hint={dash.data ? `${num(dash.data.offersScheduled)} ${t.overview.scheduled} · ${num(dash.data.offersDraft)} ${t.overview.drafts}` : undefined} />
          <Kpi label={t.overview.pendingRedemptions} value={dash.data ? num(dash.data.redemptionsPending) : '…'} />
          <Kpi label={t.overview.completedRedemptions} value={dash.data ? num(dash.data.redemptionsCompleted) : '…'} />
        </div>
        <div className="alert alert-info small">{t.overview.erpNote}</div>
        <div className="grid-2">
          {marketing && (
            <Card title={t.overview.recentCampaigns} pad={false} actions={<Link to="/campaigns" className="small">{t.nav.campaigns} {fwd}</Link>}>
              {campaigns.isLoading ? <SkeletonRows /> : campaigns.error ? <div className="card-pad"><ErrorBox error={campaigns.error} /></div> : !campaigns.data?.length ? <Empty>{t.campaigns.empty}</Empty> : (
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>{t.campaigns.offer}</th><th>{t.campaigns.recipients}</th><th>{t.campaigns.openRate}</th></tr></thead>
                    <tbody>
                      {campaigns.data.slice(0, 5).map((c) => {
                        const rate = c.providerAccepted ? c.opened / c.providerAccepted : 0;
                        return (
                          <tr key={c.id}>
                            <td><div style={{ fontWeight: 600 }}>{title(c.offerId)}</div><div className="small muted">{dateTime(c.createdAt)}</div></td>
                            <td className="num">{num(c.recipients)}</td>
                            <td><div className="row" style={{ gap: 8, flexWrap: 'nowrap' }}><div className="bar" style={{ flex: 1 }}><span style={{ width: `${Math.round(rate * 100)}%` }} /></div><span className="num small">{Math.round(rate * 100)}%</span></div></td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          )}
          {support && (
            <Card title={t.overview.recentRedemptions} pad={false} actions={<Link to="/redemptions" className="small">{t.nav.redemptions} {fwd}</Link>}>
              {redemptions.isLoading ? <SkeletonRows /> : redemptions.error ? <div className="card-pad"><ErrorBox error={redemptions.error} /></div> : !redemptions.data?.length ? <Empty>{t.redemptions.empty}</Empty> : (
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>{t.redemptions.ref}</th><th>{t.redemptions.value}</th><th>{t.redemptions.status}</th></tr></thead>
                    <tbody>
                      {redemptions.data.slice(0, 5).map((r) => (
                        <tr key={r.id}>
                          <td><span className="ltr" style={{ fontWeight: 600 }}>{r.reference}</span><div className="small muted">{r.branchName}</div></td>
                          <td className="num">{sar(r.discountAmount)}<div className="small muted">{num(r.points)} pts</div></td>
                          <td><Badge tone={redemptionTone(r.status)}>{t.redemptions.st[r.status]}</Badge></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          )}
        </div>
      </div>
    </>
  );
}
