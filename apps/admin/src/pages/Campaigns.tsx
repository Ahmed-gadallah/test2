import { useQuery } from '@tanstack/react-query';
import { Badge, Card, Empty, ErrorBox, Kpi, SkeletonRows } from '../components/ui';
import { useI18n } from '../i18n';
import { useSession } from '../session';

export function CampaignsPage() {
  const { t, num, dateTime } = useI18n();
  const { api } = useSession();
  const campaigns = useQuery({ queryKey: ['campaigns'], queryFn: () => api.campaigns() });
  const offers = useQuery({ queryKey: ['offers'], queryFn: () => api.offers() });
  const title = (id: string) => offers.data?.find((o) => o.id === id)?.titleAr ?? '—';
  const list = campaigns.data ?? [];
  const sum = (k: 'recipients' | 'providerAccepted' | 'providerFailed' | 'opened') => list.reduce((s, c) => s + c[k], 0);
  const accepted = sum('providerAccepted');

  return (
    <>
      <div className="topbar"><h1 style={{ fontSize: 24 }}>{t.campaigns.title}</h1></div>
      <div className="content">
        <div className="grid-kpi">
          <Kpi label={t.nav.campaigns} value={num(list.length)} />
          <Kpi label={t.campaigns.recipients} value={num(sum('recipients'))} />
          <Kpi label={t.campaigns.accepted} value={num(accepted)} hint={`${num(sum('providerFailed'))} ${t.campaigns.failed}`} />
          <Kpi label={t.campaigns.opened} value={num(sum('opened'))} hint={`${t.campaigns.openRate}: ${accepted ? Math.round((sum('opened') / accepted) * 100) : 0}%`} />
        </div>
        <div className="alert alert-info small">{t.campaigns.note}</div>
        <Card pad={false}>
          {campaigns.isLoading ? <SkeletonRows rows={6} /> : campaigns.error ? <div className="card-pad"><ErrorBox error={campaigns.error} onRetry={() => campaigns.refetch()} /></div> : !list.length ? <Empty>{t.campaigns.empty}</Empty> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>{t.campaigns.offer}</th><th>{t.campaigns.kind}</th><th>{t.campaigns.date}</th><th>{t.campaigns.recipients}</th><th>{t.campaigns.accepted}</th><th>{t.campaigns.failed}</th><th>{t.campaigns.opened}</th><th>{t.campaigns.openRate}</th></tr></thead>
                <tbody>
                  {list.map((c) => {
                    const rate = c.providerAccepted ? Math.round((c.opened / c.providerAccepted) * 100) : 0;
                    return (
                      <tr key={c.id}>
                        <td style={{ fontWeight: 600 }}>{title(c.offerId)}</td>
                        <td><Badge tone={c.kind === 'publish' ? 'blue' : 'warn'}>{c.kind === 'publish' ? t.campaigns.publishKind : t.campaigns.resendKind}</Badge></td>
                        <td className="small">{dateTime(c.createdAt)}</td>
                        <td className="num">{num(c.recipients)}</td>
                        <td className="num">{num(c.providerAccepted)}</td>
                        <td className="num" style={{ color: c.providerFailed ? 'var(--bad)' : undefined }}>{num(c.providerFailed)}</td>
                        <td className="num">{num(c.opened)}</td>
                        <td><div className="row" style={{ gap: 8, flexWrap: 'nowrap' }}><div className="bar" style={{ flex: 1 }}><span style={{ width: `${rate}%` }} /></div><span className="num small">{rate}%</span></div></td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
