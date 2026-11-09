import { useState, type FormEvent } from 'react';
import logo from '../assets/zaad_logo.png';
import { ErrorBox } from '../components/ui';
import { useI18n } from '../i18n';
import { isDemo, useSession } from '../session';

const DEMO = ['super@zaad.demo', 'marketing@zaad.demo', 'support@zaad.demo'] as const;

export function LoginPage() {
  const { t, lang, setLang } = useI18n();
  const { login } = useSession();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  async function submit(e?: FormEvent, override?: { email: string; password: string }) {
    e?.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(override?.email ?? email, override?.password ?? password);
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login">
      <form className="login-card" onSubmit={submit}>
        <img className="logo" src={logo} alt="" />
        <div style={{ display: 'grid', gap: 4 }}>
          <h1>{t.signInTitle}</h1>
          <p className="muted small" style={{ margin: 0, textAlign: 'center' }}>{t.signInSub}</p>
        </div>
        {isDemo && <div className="alert alert-warn small">{t.demoBanner}</div>}
        {error != null && <ErrorBox error={error} />}
        <div className="field">
          <label htmlFor="email">{t.email}</label>
          <input id="email" className="input ltr" style={{ display: 'block' }} type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="password">{t.password}</label>
          <input id="password" className="input" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>
        <button className="btn btn-primary" style={{ height: 46 }} disabled={busy}>{t.signIn}</button>
        {isDemo && (
          <div className="demo-accounts">
            <span className="small muted">{t.demoAccounts}</span>
            {DEMO.map((d, i) => (
              <button key={d} type="button" className="btn btn-ghost btn-sm" onClick={() => submit(undefined, { email: d, password: 'Demo12345678' })}>
                {t.roles[(['super_admin', 'marketing_admin', 'customer_support'] as const)[i]]} · <span className="ltr">{d}</span>
              </button>
            ))}
          </div>
        )}
        <button type="button" className="btn btn-sm btn-ghost" style={{ justifySelf: 'center' }} onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}>{t.language}</button>
      </form>
    </div>
  );
}
