import { useInfiniteQuery, useMutation, useQuery } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { CustomerResult, InvoiceStatus } from '../api/types';
import { Badge, Card, Empty, ErrorBox, Kpi, SkeletonRows, type Tone } from '../components/ui';
import { useI18n } from '../i18n';
import { useSession } from '../session';

const invTone = (s: InvoiceStatus): Tone => ({ finished: 'ok', refunded: 'bad', partially_refunded: 'warn', cancelled: 'mute' })[s] as Tone;
const fmtMobile = (e164: string) => {
  const n = e164.startsWith('+966') ? `0${e164.slice(4)}` : e164;
  return n.length === 10 ? `${n.slice(0, 3)} ${n.slice(3, 6)} ${n.slice(6)}` : n;
};

function AccountBadge({ c }: { c: CustomerResult }) {
  const { t } = useI18n();
  if (!c.eligibleForApp) return <Badge tone="bad">{t.customers.notEligible}</Badge>;
  return c.appAccount ? <Badge tone="ok">{t.customers.registered}</Badge> : <Badge tone="mute">{t.customers.notRegistered}</Badge>;
}

export function CustomersPage() {
  const { t } = useI18n();
  const { api } = useSession();
  const nav = useNavigate();
  const [by, setBy] = useState<'mobile' | 'customerId'>('mobile');
  const [value, setValue] = useState('');
  const search = useMutation({ mutationFn: () => api.searchCustomers(by === 'mobile' ? { mobile: value } : { customerId: value.trim() }) });

  function submit(e: FormEvent) {
    e.preventDefault();
    if (value.trim()) search.mutate();
  }

  return (
    <>
      <div className="topbar"><h1 style={{ fontSize: 24 }}>{t.customers.title}</h1></div>
      <div className="content">
        <form className="card card-pad" style={{ display: 'grid', gap: 12 }} onSubmit={submit}>
          <b>{t.customers.searchBy}</b>
          <div className="row">
            <div className="tabs">
              <button type="button" className={`tab${by === 'mobile' ? ' on' : ''}`} onClick={() => setBy('mobile')}>{t.customers.mobile}</button>
              <button type="button" className={`tab${by === 'customerId' ? ' on' : ''}`} onClick={() => setBy('customerId')}>{t.customers.id}</button>
            </div>
            <input className="input" style={{ flex: 1, minWidth: 200 }} dir="ltr" inputMode="numeric" placeholder={by === 'mobile' ? '05XXXXXXXX' : '900001'} value={value} onChange={(e) => setValue(e.target.value)} aria-label={t.customers.searchBy} />
            <button className="btn btn-primary" disabled={search.isPending}>{t.customers.search}</button>
          </div>
          <span className="small muted">{t.customers.readOnly}</span>
        </form>
        {search.error ? <ErrorBox error={search.error} /> : null}
        {search.isPending && <Card><SkeletonRows rows={3} /></Card>}
        {search.data && (
          <>
            {search.data.length > 1 && <div className="alert alert-warn">{t.customers.multiple}</div>}
            <Card pad={false}>
              {!search.data.length ? <Empty>{t.customers.noResults}</Empty> : (
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>{t.customers.id}</th><th>{t.admins.name}</th><th>{t.customers.mobile}</th><th>{t.customers.appAccount}</th><th /></tr></thead>
                    <tbody>
                      {search.data.map((c) => (
                        <tr key={c.erpCustomerId} className="clickable" onClick={() => nav(`/customers/${c.erpCustomerId}`, { state: c })}>
                          <td className="num ltr">{c.erpCustomerId}</td>
                          <td style={{ fontWeight: 600 }}>{c.name ?? '—'}</td>
                          <td><span className="ltr num">{fmtMobile(c.mobileNumber)}</span></td>
                          <td><AccountBadge c={c} /></td>
                          <td><span className="btn btn-sm btn-soft">{t.customers.open}</span></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          </>
        )}
      </div>
    </>
  );
}

export function CustomerDetailPage() {
  const { id = '' } = useParams();
  const { t, num, sar, date, dateTime, back } = useI18n();
  const { api } = useSession();
  const [tab, setTab] = useState<'points' | 'invoices'>('points');
  const [openInvoice, setOpenInvoice] = useState<string | null>(null);
  const profile = useQuery({ queryKey: ['customer', id], queryFn: async () => (await api.searchCustomers({ customerId: id }))[0] ?? null });
  const points = useInfiniteQuery({
    queryKey: ['customer-points', id],
    queryFn: ({ pageParam }) => api.customerPoints(id, pageParam),
    initialPageParam: null as string | null,
    getNextPageParam: (p) => p.nextCursor,
  });
  const invoices = useInfiniteQuery({
    queryKey: ['customer-invoices', id],
    queryFn: ({ pageParam }) => api.customerInvoices(id, pageParam),
    initialPageParam: null as string | null,
    getNextPageParam: (p) => p.nextCursor,
    enabled: tab === 'invoices',
  });
  const invoice = useQuery({ queryKey: ['invoice', id, openInvoice], queryFn: () => api.customerInvoice(id, openInvoice!), enabled: !!openInvoice });
  const c = profile.data;
  const balance = points.data?.pages[0]?.balance;
  const ledger = points.data?.pages.flatMap((p) => p.history) ?? [];
  const invs = invoices.data?.pages.flatMap((p) => p.items) ?? [];

  return (
    <>
      <div className="topbar page-head">
        <div className="row">
          <Link to="/customers" className="btn btn-sm btn-ghost">{back} {t.customers.back}</Link>
          <h1>{c?.name ?? '…'}</h1>
          {c && <AccountBadge c={c} />}
        </div>
      </div>
      <div className="content">
        {profile.error ? <ErrorBox error={profile.error} onRetry={() => profile.refetch()} /> : null}
        <div className="grid-kpi">
          <Kpi hero label={t.customers.balance} value={balance ? num(balance.points) : '…'} hint={balance ? `≈ ${sar(Math.floor(balance.points / 50))} · ${dateTime(balance.asOf)}` : undefined} />
          <Kpi label={t.customers.id} value={<span className="ltr">{id}</span>} />
          <Kpi label={t.customers.mobile} value={<span className="ltr" style={{ fontSize: 22 }}>{c ? fmtMobile(c.mobileNumber) : '…'}</span>} />
        </div>
        <div className="alert alert-info small">{t.customers.readOnly}</div>
        <div className="tabs">
          <button className={`tab${tab === 'points' ? ' on' : ''}`} onClick={() => setTab('points')}>{t.customers.ledger}</button>
          <button className={`tab${tab === 'invoices' ? ' on' : ''}`} onClick={() => setTab('invoices')}>{t.customers.invoices}</button>
        </div>
        {tab === 'points' ? (
          <Card pad={false}>
            {points.isLoading ? <SkeletonRows /> : points.error ? <div className="card-pad"><ErrorBox error={points.error} /></div> : !ledger.length ? <Empty>—</Empty> : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>{t.campaigns.date}</th><th>{t.campaigns.kind}</th><th>{t.customers.points}</th><th>{t.customers.balanceAfter}</th><th>{t.customers.invoice}</th><th>{t.customers.branch}</th></tr></thead>
                  <tbody>
                    {ledger.map((e) => (
                      <tr key={e.id}>
                        <td className="small">{dateTime(e.occurredAt)}</td>
                        <td><Badge tone={e.pointsDelta > 0 ? 'ok' : 'bad'}>{t.customers.tx[e.type]}</Badge></td>
                        <td className="num ltr" style={{ fontWeight: 700, color: e.pointsDelta > 0 ? 'var(--ok)' : 'var(--bad)' }}>{e.pointsDelta > 0 ? '+' : ''}{num(e.pointsDelta)}</td>
                        <td className="num">{e.balanceAfter != null ? num(e.balanceAfter) : '—'}</td>
                        <td className="num ltr">{e.invoiceNumber ? `#${e.invoiceNumber}` : '—'}</td>
                        <td className="small">{e.branchName ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {points.hasNextPage && <div className="card-pad"><button className="btn btn-ghost" onClick={() => points.fetchNextPage()} disabled={points.isFetchingNextPage}>{t.customers.loadMore}</button></div>}
          </Card>
        ) : (
          <div className="grid-2" style={{ gridTemplateColumns: openInvoice ? 'minmax(0,1fr) minmax(320px,1fr)' : '1fr' }}>
            <Card pad={false}>
              {invoices.isLoading ? <SkeletonRows /> : invoices.error ? <div className="card-pad"><ErrorBox error={invoices.error} /></div> : !invs.length ? <Empty>—</Empty> : (
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>{t.customers.invoice}</th><th>{t.campaigns.date}</th><th>{t.customers.branch}</th><th>{t.customers.total}</th><th>{t.redemptions.status}</th></tr></thead>
                    <tbody>
                      {invs.map((i) => (
                        <tr key={i.invoiceId} className="clickable" onClick={() => setOpenInvoice(i.invoiceId)} style={i.invoiceId === openInvoice ? { background: 'var(--blue-soft)' } : undefined}>
                          <td className="num ltr" style={{ fontWeight: 700 }}>#{i.invoiceNumber}</td>
                          <td className="small">{date(i.issuedAt)}</td>
                          <td className="small">{i.branchName}</td>
                          <td className="num">{sar(i.total)}</td>
                          <td><Badge tone={invTone(i.status)}>{t.customers.inv[i.status]}</Badge></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {invoices.hasNextPage && <div className="card-pad"><button className="btn btn-ghost" onClick={() => invoices.fetchNextPage()} disabled={invoices.isFetchingNextPage}>{t.customers.loadMore}</button></div>}
            </Card>
            {openInvoice && (
              <Card title={<span>{t.customers.invoice} <span className="ltr">#{invoice.data?.invoiceNumber ?? ''}</span></span>} actions={<button className="btn btn-sm btn-ghost" onClick={() => setOpenInvoice(null)}>{t.common.close}</button>}>
                {invoice.isLoading ? <SkeletonRows rows={4} /> : invoice.error ? <ErrorBox error={invoice.error} /> : invoice.data && (
                  <div style={{ display: 'grid', gap: 10 }}>
                    <div className="row" style={{ justifyContent: 'space-between' }}>
                      <span className="muted">{invoice.data.branchName} · {dateTime(invoice.data.issuedAt)}</span>
                      <Badge tone={invTone(invoice.data.status)}>{t.customers.inv[invoice.data.status]}</Badge>
                    </div>
                    <table>
                      <thead><tr><th>{t.customers.items}</th><th>{t.customers.qty}</th><th>{t.customers.total}</th></tr></thead>
                      <tbody>
                        {invoice.data.lines.map((l, k) => (
                          <tr key={k}><td dir="ltr" style={{ textAlign: 'start' }}>{l.name}</td><td className="num">{l.quantity}</td><td className="num">{sar(l.lineTotal)}</td></tr>
                        ))}
                      </tbody>
                    </table>
                    <div className="row" style={{ justifyContent: 'space-between', fontWeight: 700 }}><span>{t.customers.total}</span><span className="num">{sar(invoice.data.total)}</span></div>
                    {invoice.data.pointsEarned != null && <div className="row" style={{ justifyContent: 'space-between' }}><span className="muted">{t.customers.pointsEarned}</span><span className="num ltr" style={{ color: 'var(--blue)', fontWeight: 700 }}>+{num(invoice.data.pointsEarned)}</span></div>}
                    {invoice.data.paymentMethod && <div className="row" style={{ justifyContent: 'space-between' }}><span className="muted">{t.customers.payment}</span><span>{t.customers.pay[invoice.data.paymentMethod]}</span></div>}
                  </div>
                )}
              </Card>
            )}
          </div>
        )}
      </div>
    </>
  );
}
