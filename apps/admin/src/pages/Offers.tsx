import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { Offer, OfferInput, OfferStatus } from '../api/types';
import { Badge, Card, Confirm, Empty, ErrorBox, SkeletonRows, toast, type Tone } from '../components/ui';
import { errorText, useI18n } from '../i18n';
import { useSession } from '../session';

export const offerTone = (s: OfferStatus): Tone => ({ draft: 'mute', scheduled: 'blue', active: 'ok', expired: 'warn', archived: 'mute' })[s] as Tone;

type Action = { kind: 'publish' | 'archive' | 'resend'; offer: Offer } | null;

/** Shared confirm-and-run for publish / archive / resend. */
function useOfferActions() {
  const { t, num } = useI18n();
  const { api } = useSession();
  const qc = useQueryClient();
  const [action, setAction] = useState<Action>(null);
  const run = useMutation({
    mutationFn: async (a: NonNullable<Action>) => {
      if (a.kind === 'publish') return { offer: await api.publishOffer(a.offer.id) };
      if (a.kind === 'archive') return { offer: await api.archiveOffer(a.offer.id) };
      return { campaign: await api.resendOffer(a.offer.id) };
    },
    onSuccess: (r, a) => {
      qc.invalidateQueries({ queryKey: ['offers'] });
      qc.invalidateQueries({ queryKey: ['campaigns'] });
      qc.invalidateQueries({ queryKey: ['dashboard'] });
      if ('campaign' in r && r.campaign) toast(t.offers.sent.replace('{n}', num(r.campaign.recipients)));
      else toast(a.kind === 'publish' ? t.offers.published : t.offers.archived);
      setAction(null);
    },
    onError: (e) => toast(errorText(t, e)),
  });
  const scheduled = action?.offer && Date.parse(action.offer.startAt) > Date.now();
  const dialog = (
    <Confirm
      open={!!action}
      busy={run.isPending}
      danger={action?.kind === 'archive'}
      title={action?.kind === 'publish' ? t.offers.publishConfirm : action?.kind === 'archive' ? t.offers.archiveConfirm : t.offers.resendConfirm}
      body={action?.kind === 'publish' ? (scheduled ? t.offers.publishBodyLater : t.offers.publishBodyNow) : action?.kind === 'archive' ? t.offers.archiveBody : t.offers.resendBody}
      confirmLabel={action?.kind === 'publish' ? t.offers.publish : action?.kind === 'archive' ? t.offers.archive : t.offers.resend}
      onConfirm={() => action && run.mutate(action)}
      onClose={() => setAction(null)}
    />
  );
  return { ask: setAction, dialog };
}

function OfferActions({ o, ask, onForm }: { o: Offer; ask: (a: Action) => void; onForm?: boolean }) {
  const { t } = useI18n();
  return (
    <div className="row" style={{ gap: 6, flexWrap: 'nowrap' }}>
      {o.storedStatus === 'draft' && <button className="btn btn-sm btn-primary" onClick={() => ask({ kind: 'publish', offer: o })}>{t.offers.publish}</button>}
      {o.status === 'active' && o.notificationDispatchedAt && <button className="btn btn-sm btn-soft" onClick={() => ask({ kind: 'resend', offer: o })}>{t.offers.resend}</button>}
      {o.status !== 'archived' && !onForm && <Link className="btn btn-sm btn-ghost" to={`/offers/${o.id}`}>{t.offers.edit}</Link>}
      {o.status !== 'archived' && <button className="btn btn-sm btn-danger" onClick={() => ask({ kind: 'archive', offer: o })}>{t.offers.archive}</button>}
    </div>
  );
}

export function OffersPage() {
  const { t, date, dateTime } = useI18n();
  const { api } = useSession();
  const q = useQuery({ queryKey: ['offers'], queryFn: () => api.offers() });
  const [filter, setFilter] = useState<'all' | OfferStatus>('all');
  const { ask, dialog } = useOfferActions();
  const list = (q.data ?? []).filter((o) => filter === 'all' || o.status === filter);
  const statuses: ('all' | OfferStatus)[] = ['all', 'active', 'scheduled', 'draft', 'expired', 'archived'];

  return (
    <>
      <div className="topbar page-head">
        <h1>{t.offers.title}</h1>
        <Link className="btn btn-primary" to="/offers/new">+ {t.offers.new}</Link>
      </div>
      <div className="content">
        <div className="tabs">
          {statuses.map((s) => (
            <button key={s} className={`tab${filter === s ? ' on' : ''}`} onClick={() => setFilter(s)}>
              {s === 'all' ? t.offers.all : t.status[s]}
              {q.data ? ` (${q.data.filter((o) => s === 'all' || o.status === s).length})` : ''}
            </button>
          ))}
        </div>
        <Card pad={false}>
          {q.isLoading ? <SkeletonRows rows={6} /> : q.error ? <div className="card-pad"><ErrorBox error={q.error} onRetry={() => q.refetch()} /></div> : !list.length ? <Empty>{t.offers.empty}</Empty> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>{t.offers.titleAr}</th><th>{t.offers.validity}</th><th>{t.campaigns.kind}</th><th>{t.common.actions}</th></tr></thead>
                <tbody>
                  {list.map((o) => (
                    <tr key={o.id}>
                      <td>
                        <div style={{ fontWeight: 700 }}>{o.titleAr}</div>
                        <div className="small muted" dir="ltr" style={{ textAlign: 'start' }}>{o.titleEn}</div>
                      </td>
                      <td className="small">{date(o.startAt)} – {date(o.endAt)}</td>
                      <td>
                        <Badge tone={offerTone(o.status)}>{t.status[o.status]}</Badge>
                        <div className="small muted" style={{ marginTop: 4 }}>{o.notificationDispatchedAt ? `${t.offers.notified} · ${dateTime(o.notificationDispatchedAt)}` : t.offers.notNotified}</div>
                      </td>
                      <td><OfferActions o={o} ask={ask} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
      {dialog}
    </>
  );
}

const toLocal = (isoStr: string) => {
  const d = new Date(isoStr);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};

export function OfferFormPage() {
  const { id } = useParams();
  const { t, date, back } = useI18n();
  const { api } = useSession();
  const qc = useQueryClient();
  const nav = useNavigate();
  const list = useQuery({ queryKey: ['offers'], queryFn: () => api.offers(), enabled: !!id });
  const existing = useMemo(() => list.data?.find((o) => o.id === id), [list.data, id]);
  const { ask, dialog } = useOfferActions();
  const [lang, setLang] = useState<'ar' | 'en'>('ar');
  const [form, setForm] = useState<OfferInput | null>(null);
  const [error, setError] = useState<unknown>(null);

  const initial: OfferInput = existing
    ? { titleAr: existing.titleAr, titleEn: existing.titleEn, descriptionAr: existing.descriptionAr, descriptionEn: existing.descriptionEn, imageUrl: existing.imageUrl ?? '', ctaLabelAr: existing.ctaLabelAr ?? '', ctaLabelEn: existing.ctaLabelEn ?? '', destinationUrl: existing.destinationUrl ?? '', startAt: toLocal(existing.startAt), endAt: toLocal(existing.endAt) }
    : { titleAr: '', titleEn: '', descriptionAr: '', descriptionEn: '', imageUrl: '', ctaLabelAr: '', ctaLabelEn: '', destinationUrl: '', startAt: toLocal(new Date().toISOString()), endAt: toLocal(new Date(Date.now() + 14 * 86_400_000).toISOString()) };
  const f = form ?? initial;
  const set = (k: keyof OfferInput) => (e: { target: { value: string } }) => setForm({ ...f, [k]: e.target.value });

  const save = useMutation({
    mutationFn: async () => {
      const body = { ...f, startAt: new Date(f.startAt).toISOString(), endAt: new Date(f.endAt).toISOString() };
      return id ? api.updateOffer(id, body) : api.createOffer(body);
    },
    onSuccess: (o) => {
      qc.invalidateQueries({ queryKey: ['offers'] });
      qc.invalidateQueries({ queryKey: ['dashboard'] });
      toast(t.offers.saved);
      if (!id) nav(`/offers/${o.id}`, { replace: true });
      setForm(null);
    },
    onError: setError,
  });

  if (id && list.isLoading) return <div className="content"><Card><SkeletonRows /></Card></div>;
  if (id && !existing) return <div className="content"><ErrorBox error={{ code: 'NOT_FOUND' }} /></div>;

  function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    save.mutate();
  }

  const title = lang === 'ar' ? f.titleAr : f.titleEn;
  const desc = lang === 'ar' ? f.descriptionAr : f.descriptionEn;
  const cta = (lang === 'ar' ? f.ctaLabelAr : f.ctaLabelEn) || (lang === 'ar' ? 'عرض التفاصيل' : 'View details');

  return (
    <>
      <div className="topbar page-head">
        <div className="row">
          <Link to="/offers" className="btn btn-sm btn-ghost">{back} {t.customers.back}</Link>
          <h1>{id ? t.offers.edit : t.offers.new}</h1>
          {existing && <Badge tone={offerTone(existing.status)}>{t.status[existing.status]}</Badge>}
        </div>
        {existing && <OfferActions o={existing} ask={ask} onForm />}
      </div>
      <div className="content">
        {existing?.notificationDispatchedAt && <div className="alert alert-info small">{t.offers.editNote}</div>}
        <div className="grid-2" style={{ gridTemplateColumns: 'minmax(0, 1.4fr) minmax(300px, 1fr)' }}>
          <form className="card card-pad" style={{ display: 'grid', gap: 14 }} onSubmit={submit}>
            {error != null && <ErrorBox error={error} />}
            <div className="form-grid">
              <div className="field"><label htmlFor="tAr">{t.offers.titleAr}</label><input id="tAr" className="input" dir="rtl" required maxLength={120} value={f.titleAr} onChange={set('titleAr')} /></div>
              <div className="field"><label htmlFor="tEn">{t.offers.titleEn}</label><input id="tEn" className="input" dir="ltr" required maxLength={120} value={f.titleEn} onChange={set('titleEn')} /></div>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="dAr">{t.offers.descAr}</label><textarea id="dAr" className="input" dir="rtl" required maxLength={2000} value={f.descriptionAr} onChange={set('descriptionAr')} /></div>
              <div className="field"><label htmlFor="dEn">{t.offers.descEn}</label><textarea id="dEn" className="input" dir="ltr" required maxLength={2000} value={f.descriptionEn} onChange={set('descriptionEn')} /></div>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="st">{t.offers.start}</label><input id="st" className="input" type="datetime-local" required value={f.startAt} onChange={set('startAt')} /></div>
              <div className="field"><label htmlFor="en">{t.offers.end}</label><input id="en" className="input" type="datetime-local" required value={f.endAt} onChange={set('endAt')} /></div>
            </div>
            <div className="field"><label htmlFor="img">{t.offers.image}</label><input id="img" className="input" dir="ltr" type="url" placeholder="https://zaadonline.com/…" value={f.imageUrl} onChange={set('imageUrl')} /></div>
            <div className="form-grid">
              <div className="field"><label htmlFor="cAr">{t.offers.ctaAr}</label><input id="cAr" className="input" dir="rtl" maxLength={40} value={f.ctaLabelAr} onChange={set('ctaLabelAr')} /></div>
              <div className="field"><label htmlFor="cEn">{t.offers.ctaEn}</label><input id="cEn" className="input" dir="ltr" maxLength={40} value={f.ctaLabelEn} onChange={set('ctaLabelEn')} /></div>
            </div>
            <div className="field"><label htmlFor="url">{t.offers.link}</label><input id="url" className="input" dir="ltr" type="url" placeholder="https://zaadonline.com/…" value={f.destinationUrl} onChange={set('destinationUrl')} /></div>
            <p className="small muted" style={{ margin: 0 }}>{t.offers.hostsNote}</p>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn btn-primary" disabled={save.isPending || (!!id && !form)}>{id ? t.offers.saveChanges : t.offers.save}</button>
            </div>
          </form>
          <div style={{ display: 'grid', gap: 10, justifyItems: 'center' }}>
            <div className="row" style={{ justifyContent: 'space-between', width: 300, maxWidth: '100%' }}>
              <b>{t.offers.preview}</b>
              <div className="tabs">
                <button type="button" className={`tab${lang === 'ar' ? ' on' : ''}`} onClick={() => setLang('ar')}>ع</button>
                <button type="button" className={`tab${lang === 'en' ? ' on' : ''}`} onClick={() => setLang('en')}>EN</button>
              </div>
            </div>
            <div className="phone" dir={lang === 'ar' ? 'rtl' : 'ltr'}>
              <div className="phone-screen">
                <div className="banner">
                  {f.imageUrl ? <img src={f.imageUrl} alt="" onError={(e) => ((e.target as HTMLImageElement).style.display = 'none')} /> : null}
                  <h4>{title || '—'}</h4>
                  <p>{desc || '—'}</p>
                  <span className="pill">{cta} {lang === 'ar' ? '‹' : '›'}</span>
                  <p style={{ fontSize: 11 }}>{date(new Date(f.endAt).toISOString())}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {dialog}
    </>
  );
}
