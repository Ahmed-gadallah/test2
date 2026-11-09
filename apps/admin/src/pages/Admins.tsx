import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import type { Role } from '../api/types';
import { Badge, Card, ErrorBox, SkeletonRows, toast } from '../components/ui';
import { errorText, useI18n } from '../i18n';
import { useSession } from '../session';

const ROLES: Role[] = ['super_admin', 'marketing_admin', 'customer_support'];

export function AdminsPage() {
  const { t, date } = useI18n();
  const { api, admin: me } = useSession();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['admins'], queryFn: () => api.admins() });
  const [form, setForm] = useState({ name: '', email: '', password: '', role: 'customer_support' as Role });
  const [showForm, setShowForm] = useState(false);

  const create = useMutation({
    mutationFn: () => api.createAdmin(form),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admins'] });
      toast(t.admins.created);
      setForm({ name: '', email: '', password: '', role: 'customer_support' });
      setShowForm(false);
    },
  });
  const update = useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: { role?: Role; active?: boolean } }) => api.updateAdmin(id, patch),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admins'] }),
    onError: (e) => toast(errorText(t, e)),
  });

  function submit(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  return (
    <>
      <div className="topbar page-head">
        <h1>{t.admins.title}</h1>
        <button className="btn btn-primary" onClick={() => setShowForm((v) => !v)}>+ {t.admins.add}</button>
      </div>
      <div className="content">
        <div className="grid-kpi">
          {ROLES.map((r) => (
            <div key={r} className="card kpi">
              <span className="label">{t.roles[r]}</span>
              <span className="small">{t.admins.permissions[r]}</span>
            </div>
          ))}
        </div>
        {showForm && (
          <form className="card card-pad" style={{ display: 'grid', gap: 14 }} onSubmit={submit}>
            {create.error ? <ErrorBox error={create.error} /> : null}
            <div className="form-grid">
              <div className="field"><label htmlFor="an">{t.admins.name}</label><input id="an" className="input" required minLength={2} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
              <div className="field"><label htmlFor="ae">{t.email}</label><input id="ae" className="input" dir="ltr" type="email" required value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></div>
              <div className="field"><label htmlFor="ap">{t.password}</label><input id="ap" className="input" type="password" required minLength={12} value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /><span className="small muted">{t.admins.pwRule}</span></div>
              <div className="field"><label htmlFor="ar">{t.admins.role}</label>
                <select id="ar" className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}>
                  {ROLES.map((r) => <option key={r} value={r}>{t.roles[r]}</option>)}
                </select>
              </div>
            </div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button type="button" className="btn btn-ghost" onClick={() => setShowForm(false)}>{t.common.cancel}</button>
              <button className="btn btn-primary" disabled={create.isPending}>{t.common.create}</button>
            </div>
          </form>
        )}
        <Card pad={false}>
          {q.isLoading ? <SkeletonRows /> : q.error ? <div className="card-pad"><ErrorBox error={q.error} onRetry={() => q.refetch()} /></div> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>{t.admins.name}</th><th>{t.email}</th><th>{t.admins.role}</th><th>{t.admins.status}</th><th>{t.campaigns.date}</th><th>{t.common.actions}</th></tr></thead>
                <tbody>
                  {q.data?.map((a) => {
                    const self = a.id === me?.id;
                    return (
                      <tr key={a.id}>
                        <td style={{ fontWeight: 600 }}>{a.name} {self && <span className="small muted">{t.admins.you}</span>}</td>
                        <td><span className="ltr">{a.email}</span></td>
                        <td>
                          <select className="input" style={{ minHeight: 34, padding: '4px 8px', width: 'auto' }} value={a.role} disabled={self || update.isPending} aria-label={t.admins.role}
                            onChange={(e) => update.mutate({ id: a.id, patch: { role: e.target.value as Role } })}>
                            {ROLES.map((r) => <option key={r} value={r}>{t.roles[r]}</option>)}
                          </select>
                        </td>
                        <td><Badge tone={a.active ? 'ok' : 'mute'}>{a.active ? t.admins.active : t.admins.inactive}</Badge></td>
                        <td className="small">{date(a.createdAt)}</td>
                        <td>
                          {!self && (
                            <button className={`btn btn-sm ${a.active ? 'btn-danger' : 'btn-soft'}`} disabled={update.isPending} onClick={() => update.mutate({ id: a.id, patch: { active: !a.active } })}>
                              {a.active ? t.admins.deactivate : t.admins.activate}
                            </button>
                          )}
                        </td>
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
