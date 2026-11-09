import { useQuery } from '@tanstack/react-query';
import { Badge, Card, Empty, ErrorBox, SkeletonRows } from '../components/ui';
import { useI18n } from '../i18n';
import { useSession } from '../session';

export function AuditPage() {
  const { t, dateTime } = useI18n();
  const { api } = useSession();
  const logs = useQuery({ queryKey: ['audit'], queryFn: () => api.auditLogs() });
  const admins = useQuery({ queryKey: ['admins'], queryFn: () => api.admins() });
  const who = (type: string, id: string | null) => {
    if (type === 'system') return t.audit.system;
    if (type === 'customer') return t.audit.customer;
    return admins.data?.find((a) => a.id === id)?.name ?? id?.slice(0, 8) ?? '—';
  };

  return (
    <>
      <div className="topbar"><h1 style={{ fontSize: 24 }}>{t.audit.title}</h1></div>
      <div className="content">
        <Card pad={false}>
          {logs.isLoading ? <SkeletonRows rows={8} /> : logs.error ? <div className="card-pad"><ErrorBox error={logs.error} onRetry={() => logs.refetch()} /></div> : !logs.data?.length ? <Empty>—</Empty> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>{t.audit.when}</th><th>{t.audit.actor}</th><th>{t.audit.action}</th><th>{t.audit.resource}</th><th>IP</th></tr></thead>
                <tbody>
                  {logs.data.map((l) => (
                    <tr key={l.id}>
                      <td className="small" style={{ whiteSpace: 'nowrap' }}>{dateTime(l.createdAt)}</td>
                      <td>{who(l.actorType, l.actorId)}</td>
                      <td><Badge tone={/failed|blocked|locked/.test(l.action) ? 'bad' : 'blue'}><span className="ltr">{l.action}</span></Badge></td>
                      <td className="small"><span className="ltr">{l.resourceType}{l.resourceId ? ` · ${l.resourceId.slice(0, 13)}` : ''}</span></td>
                      <td className="small ltr">{l.ipAddress ?? '—'}</td>
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
