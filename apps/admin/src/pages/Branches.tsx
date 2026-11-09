import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState, type FormEvent } from 'react';
import type { Branch, BranchImportReport, BranchInput, ImportIssue } from '../api/types';
import { Badge, Card, Empty, ErrorBox, Kpi, SkeletonRows, toast } from '../components/ui';
import { errorText, useI18n } from '../i18n';
import { useSession } from '../session';

type Filter = 'all' | 'active' | 'inactive' | 'missing';
type FormState = { branchId: string } & { [K in keyof Omit<BranchInput, 'active'>]: string } & { active: boolean };

const EMPTY: FormState = { branchId: '', nameAr: '', nameEn: '', city: '', district: '', addressAr: '', addressEn: '', phone: '', mapsUrl: '', notes: '', active: true };

/** Same folding as the app's search: alef/ta marbuta/ya variants, diacritics, Arabic digits, case. */
function norm(s: string) {
  return s
    .toLowerCase()
    .replace(/[ً-ْـٰ]/g, '')
    .replace(/[أإآٱ]/g, 'ا').replace(/ة/g, 'ه').replace(/[ىئ]/g, 'ي').replace(/ؤ/g, 'و')
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/\s+/g, ' ')
    .trim();
}

/** +9665XXXXXXXX → 05X XXX XXXX (display only). */
export function displayPhone(p: string | null) {
  if (!p) return '';
  const n = p.startsWith('+966') ? `0${p.slice(4)}` : p;
  return n.length === 10 ? `${n.slice(0, 3)} ${n.slice(3, 6)} ${n.slice(6)}` : n;
}

export function BranchesPage() {
  const { t, num } = useI18n();
  const { api } = useSession();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['branches'], queryFn: () => api.branches() });
  const [filter, setFilter] = useState<Filter>('all');
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<{ form: FormState; isNew: boolean } | null>(null);
  const [importOpen, setImportOpen] = useState(false);

  const list = q.data ?? [];
  const counts = useMemo(() => ({
    total: list.length,
    active: list.filter((b) => b.active).length,
    noPhone: list.filter((b) => !b.phone).length,
    noLocation: list.filter((b) => !b.mapsUrl).length,
  }), [list]);

  const shown = useMemo(() => {
    const words = norm(search).split(' ').filter(Boolean);
    return list.filter((b) => {
      if (filter === 'active' && !b.active) return false;
      if (filter === 'inactive' && b.active) return false;
      if (filter === 'missing' && b.phone && b.mapsUrl) return false;
      if (!words.length) return true;
      const hay = norm([b.id, b.nameAr, b.nameEn, b.city, b.district, b.addressAr, b.addressEn].filter((x) => x !== null).join(' '));
      return words.every((w) => hay.includes(w));
    });
  }, [list, filter, search]);

  const toggle = useMutation({
    mutationFn: (b: Branch) => api.updateBranch(b.id, { active: !b.active }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['branches'] }),
    onError: (e) => toast(errorText(t, e)),
  });

  const openEdit = (b: Branch) =>
    setEditing({
      isNew: false,
      form: {
        branchId: String(b.id), nameAr: b.nameAr, nameEn: b.nameEn ?? '', city: b.city, district: b.district ?? '', addressAr: b.addressAr,
        addressEn: b.addressEn ?? '', phone: displayPhone(b.phone), mapsUrl: b.mapsUrl ?? '', notes: b.notes ?? '', active: b.active,
      },
    });

  const filters: [Filter, string][] = [['all', t.branches.all], ['active', t.branches.active], ['inactive', t.branches.inactive], ['missing', t.branches.missing]];

  return (
    <>
      <div className="topbar page-head">
        <div>
          <h1>{t.branches.title}</h1>
          <div className="small muted">{t.branches.sub}</div>
        </div>
        <div className="row">
          <button className="btn btn-soft" onClick={() => { setImportOpen((v) => !v); setEditing(null); }}>{t.branches.import}</button>
          <button className="btn btn-primary" onClick={() => { setEditing({ isNew: true, form: { ...EMPTY } }); setImportOpen(false); }}>+ {t.branches.add}</button>
        </div>
      </div>
      <div className="content">
        <div className="grid-kpi">
          <Kpi hero label={t.branches.total} value={q.data ? num(counts.total) : '…'} hint={q.data ? `${num(counts.active)} ${t.branches.active} · ${num(counts.total - counts.active)} ${t.branches.inactive}` : undefined} />
          <Kpi label={t.branches.active} value={q.data ? num(counts.active) : '…'} />
          <Kpi label={t.branches.noPhone} value={q.data ? num(counts.noPhone) : '…'} />
          <Kpi label={t.branches.noLocation} value={q.data ? num(counts.noLocation) : '…'} />
        </div>

        {importOpen && <ImportPanel onClose={() => setImportOpen(false)} />}
        {editing && <BranchForm key={editing.form.branchId || 'new'} initial={editing.form} isNew={editing.isNew} onClose={() => setEditing(null)} />}

        <Card pad={false}>
          <div className="card-pad row" style={{ gap: 10, flexWrap: 'wrap' }}>
            <input className="input" style={{ flex: '1 1 260px' }} placeholder={t.branches.search} value={search} onChange={(e) => setSearch(e.target.value)} aria-label={t.branches.search} />
            <div className="tabs">
              {filters.map(([f, label]) => (
                <button key={f} className={`btn btn-sm ${filter === f ? 'btn-primary' : 'btn-ghost'}`} onClick={() => setFilter(f)}>{label}</button>
              ))}
            </div>
          </div>
          {q.isLoading ? <SkeletonRows /> : q.error ? <div className="card-pad"><ErrorBox error={q.error} onRetry={() => q.refetch()} /></div> : !list.length ? <Empty>{t.branches.empty}</Empty> : !shown.length ? <Empty>{t.branches.noResults}</Empty> : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr><th>{t.branches.id}</th><th>{t.branches.nameAr}</th><th>{t.branches.city}</th><th>{t.branches.phone}</th><th>{t.branches.location}</th><th>{t.branches.status}</th><th>{t.common.actions}</th></tr>
                </thead>
                <tbody>
                  {shown.map((b) => (
                    <tr key={b.id}>
                      <td className="num">{b.id}</td>
                      <td>
                        <div style={{ fontWeight: 600 }}>{b.nameAr}</div>
                        {b.nameEn && <div className="small muted" dir="ltr" style={{ textAlign: 'start' }}>{b.nameEn}</div>}
                      </td>
                      <td>
                        <div>{b.city}</div>
                        {b.district && b.district !== b.city && <div className="small muted">{b.district}</div>}
                      </td>
                      <td>{b.phone ? <span className="ltr num">{displayPhone(b.phone)}</span> : <Badge tone="warn">{t.branches.noPhone}</Badge>}</td>
                      <td>{b.mapsUrl ? <a href={b.mapsUrl} target="_blank" rel="noopener noreferrer">{t.branches.open} ↗</a> : <Badge tone="warn">{t.branches.noLocation}</Badge>}</td>
                      <td><Badge tone={b.active ? 'ok' : 'mute'}>{b.active ? t.branches.active : t.branches.inactive}</Badge></td>
                      <td>
                        <div className="row" style={{ gap: 6, flexWrap: 'nowrap' }}>
                          <button className="btn btn-sm btn-ghost" onClick={() => { openEdit(b); setImportOpen(false); window.scrollTo({ top: 0, behavior: 'smooth' }); }}>{t.branches.edit}</button>
                          <button className={`btn btn-sm ${b.active ? 'btn-danger' : 'btn-soft'}`} disabled={toggle.isPending} onClick={() => toggle.mutate(b)}>
                            {b.active ? t.branches.deactivate : t.branches.activate}
                          </button>
                        </div>
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

function BranchForm({ initial, isNew, onClose }: { initial: FormState; isNew: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const { api } = useSession();
  const qc = useQueryClient();
  const [f, setF] = useState<FormState>(initial);
  const set = (k: keyof FormState) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value });

  const save = useMutation({
    mutationFn: () => {
      const { branchId, ...rest } = f;
      return isNew ? api.createBranch({ ...rest, branchId: Number(branchId) } as BranchInput & { branchId: number }) : api.updateBranch(Number(branchId), rest as unknown as BranchInput);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['branches'] });
      toast(isNew ? t.branches.created : t.branches.saved);
      onClose();
    },
  });
  const submit = (e: FormEvent) => {
    e.preventDefault();
    save.mutate();
  };
  const field = (k: keyof FormState, label: string, opts: { required?: boolean; ltr?: boolean; hint?: string; area?: boolean } = {}) => (
    <div className="field">
      <label htmlFor={`b-${k}`}>{label}{opts.required ? ' *' : ''}</label>
      {opts.area ? (
        <textarea id={`b-${k}`} className="input" value={f[k] as string} onChange={set(k)} required={opts.required} />
      ) : (
        <input id={`b-${k}`} className="input" dir={opts.ltr ? 'ltr' : undefined} value={f[k] as string} onChange={set(k)} required={opts.required} />
      )}
      {opts.hint && <span className="small muted">{opts.hint}</span>}
    </div>
  );

  return (
    <form className="card card-pad" style={{ display: 'grid', gap: 14 }} onSubmit={submit}>
      <h3 style={{ margin: 0 }}>{isNew ? t.branches.add : `${t.branches.edit} — ${initial.nameAr}`}</h3>
      {save.error ? <ErrorBox error={save.error} /> : null}
      <div className="form-grid">
        {isNew ? (
          <div className="field">
            <label htmlFor="b-id">{t.branches.id} *</label>
            <input id="b-id" className="input" dir="ltr" inputMode="numeric" pattern="\d{1,9}" required value={f.branchId} onChange={set('branchId')} />
            <span className="small muted">{t.branches.idHint}</span>
          </div>
        ) : null}
        {field('nameAr', t.branches.nameAr, { required: true })}
        {field('nameEn', t.branches.nameEn, { ltr: true })}
        {field('city', t.branches.city, { required: true })}
        {field('district', t.branches.district)}
        {field('addressAr', t.branches.addressAr, { required: true })}
        {field('addressEn', t.branches.addressEn, { ltr: true })}
        {field('phone', t.branches.phone, { ltr: true, hint: t.branches.phoneHint })}
        {field('mapsUrl', t.branches.maps, { ltr: true, hint: t.branches.mapsHint })}
        {field('notes', t.branches.notes, { area: true })}
        <div className="field">
          <label htmlFor="b-active">{t.branches.status}</label>
          <select id="b-active" className="input" value={f.active ? '1' : '0'} onChange={(e) => setF({ ...f, active: e.target.value === '1' })}>
            <option value="1">{t.branches.active}</option>
            <option value="0">{t.branches.inactive}</option>
          </select>
        </div>
      </div>
      <div className="row" style={{ justifyContent: 'flex-end' }}>
        <button type="button" className="btn btn-ghost" onClick={onClose}>{t.common.cancel}</button>
        <button className="btn btn-primary" disabled={save.isPending}>{isNew ? t.common.create : t.offers.saveChanges}</button>
      </div>
    </form>
  );
}

function ImportPanel({ onClose }: { onClose: () => void }) {
  const { t, num } = useI18n();
  const { api } = useSession();
  const qc = useQueryClient();
  const [file, setFile] = useState<File | null>(null);
  const [report, setReport] = useState<BranchImportReport | null>(null);

  const check = useMutation({ mutationFn: (f: File) => api.importBranches(f, true), onSuccess: setReport, onError: () => setReport(null) });
  const apply = useMutation({
    mutationFn: (f: File) => api.importBranches(f, false),
    onSuccess: (r) => {
      setReport(r);
      qc.invalidateQueries({ queryKey: ['branches'] });
      if (r.applied) toast(t.branches.applied);
    },
  });
  const err = check.error ?? apply.error;
  const canApply = !!file && !!report && report.dryRun && !report.errors.length && report.created.length + report.updated.length > 0;

  return (
    <Card title={t.branches.importTitle} actions={<button className="btn btn-sm btn-ghost" onClick={onClose}>{t.common.close}</button>}>
      <div style={{ display: 'grid', gap: 12 }}>
        <div className="small muted">{t.branches.importNote}</div>
        <div className="row" style={{ gap: 10, flexWrap: 'wrap' }}>
          <input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" aria-label={t.branches.chooseFile}
            onChange={(e) => { setFile(e.target.files?.[0] ?? null); setReport(null); check.reset(); apply.reset(); }} />
          <button className="btn btn-soft" disabled={!file || check.isPending} onClick={() => file && check.mutate(file)}>{t.branches.check}</button>
          <button className="btn btn-primary" disabled={!canApply || apply.isPending} onClick={() => file && apply.mutate(file)}>{t.branches.apply}</button>
        </div>
        {err ? <div className="alert alert-bad small">{errorText(t, err)}</div> : null}
        {report && (
          <>
            <div className="grid-kpi">
              <Kpi label={t.branches.willCreate} value={num(report.created.length)} />
              <Kpi label={t.branches.willUpdate} value={num(report.updated.length)} hint={report.updated.length ? report.updated.join(', ') : undefined} />
              <Kpi label={t.branches.unchanged} value={num(report.unchanged.length)} />
              <Kpi label={t.branches.notInFile} value={num(report.notInFile.length)} hint={report.notInFile.length ? report.notInFile.join(', ') : undefined} />
            </div>
            {report.applied && <div className="alert alert-info small">{t.branches.applied}</div>}
            {report.updated.length > 0 && !report.applied && <div className="small muted">{t.branches.reimportNote}</div>}
            <Issues title={t.branches.errors} items={report.errors} tone="err" />
            <Issues title={t.branches.warnings} items={report.warnings} tone="warn" />
          </>
        )}
      </div>
    </Card>
  );
}

function Issues({ title, items, tone }: { title: string; items: ImportIssue[]; tone: 'err' | 'warn' }) {
  const { t } = useI18n();
  if (!items.length) return null;
  return (
    <details open={tone === 'err'}>
      <summary style={{ cursor: 'pointer', fontWeight: 600 }}>
        <Badge tone={tone === 'err' ? 'bad' : 'warn'}>{items.length}</Badge> {title}
      </summary>
      <div className="table-wrap" style={{ marginTop: 8 }}>
        <table>
          <thead><tr><th>{t.branches.row}</th><th>{t.branches.id}</th><th>{t.branches.status}</th></tr></thead>
          <tbody>
            {items.map((i, k) => (
              <tr key={k}><td className="num">{i.row}</td><td className="num">{i.branchId ?? '—'}</td><td dir="ltr" style={{ textAlign: 'start' }}>{i.message}</td></tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  );
}
