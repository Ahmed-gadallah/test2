import { NavLink, Outlet } from 'react-router-dom';
import logo from '../assets/zaad_logo.png';
import type { Role } from '../api/types';
import { useI18n } from '../i18n';
import { isDemo, useSession } from '../session';
import { Icon } from './ui';

/** Navigation entries and which roles see them. The backend enforces the same rules. */
export const NAV: { to: string; key: 'overview' | 'offers' | 'campaigns' | 'customers' | 'redemptions' | 'branches' | 'admins' | 'audit'; roles: Role[] }[] = [
  { to: '/', key: 'overview', roles: ['super_admin', 'marketing_admin', 'customer_support'] },
  { to: '/offers', key: 'offers', roles: ['super_admin', 'marketing_admin'] },
  { to: '/campaigns', key: 'campaigns', roles: ['super_admin', 'marketing_admin'] },
  { to: '/customers', key: 'customers', roles: ['super_admin', 'customer_support'] },
  { to: '/redemptions', key: 'redemptions', roles: ['super_admin', 'customer_support'] },
  { to: '/branches', key: 'branches', roles: ['super_admin', 'marketing_admin'] },
  { to: '/admins', key: 'admins', roles: ['super_admin'] },
  { to: '/audit', key: 'audit', roles: ['super_admin'] },
];

export function Layout() {
  const { t, lang, setLang } = useI18n();
  const { admin, can, logout } = useSession();
  const items = NAV.filter((n) => can(...n.roles));
  return (
    <>
      {isDemo && <div className="demo">{t.demoBanner}</div>}
      <div className="shell">
        <aside className="sidebar">
          <div className="brand">
            <img src={logo} alt="" />
            <b>{t.appName}</b>
          </div>
          <nav className="nav">
            {items.map((n) => (
              <NavLink key={n.to} to={n.to} end={n.to === '/'}>
                {Icon[n.key]}
                {t.nav[n.key]}
              </NavLink>
            ))}
          </nav>
          <div className="spacer" />
          <div className="me">
            <div className="who">
              <div style={{ fontWeight: 700 }}>{admin?.name}</div>
              <div className="small muted">{admin && t.roles[admin.role]}</div>
            </div>
            <div className="row">
              <button className="btn btn-sm btn-ghost" onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}>{t.language}</button>
              <button className="btn btn-sm btn-ghost" onClick={logout}>{t.logout}</button>
            </div>
          </div>
        </aside>
        <div className="main">
          <nav className="mobile-nav">
            {items.map((n) => (
              <NavLink key={n.to} to={n.to} end={n.to === '/'}>{t.nav[n.key]}</NavLink>
            ))}
            <button className="btn btn-sm btn-ghost" onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}>{t.language}</button>
            <button className="btn btn-sm btn-ghost" onClick={logout}>{t.logout}</button>
          </nav>
          <Outlet />
        </div>
      </div>
    </>
  );
}
