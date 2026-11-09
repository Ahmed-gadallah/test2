import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import type { Role } from './api/types';
import { Layout } from './components/Layout';
import { Toaster } from './components/ui';
import { I18nProvider } from './i18n';
import { AdminsPage } from './pages/Admins';
import { AuditPage } from './pages/Audit';
import { CampaignsPage } from './pages/Campaigns';
import { CustomerDetailPage, CustomersPage } from './pages/Customers';
import { LoginPage } from './pages/Login';
import { OfferFormPage, OffersPage } from './pages/Offers';
import { OverviewPage } from './pages/Overview';
import { RedemptionsPage } from './pages/Redemptions';
import { SessionProvider, useSession } from './session';
import './styles.css';

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false, staleTime: 15_000 } },
});

/** Hides routes a role cannot use. The backend rejects them anyway (403). */
function Guard({ roles, children }: { roles: Role[]; children: ReactNode }) {
  const { admin, can } = useSession();
  if (!admin) return <Navigate to="/login" replace />;
  if (!can(...roles)) return <Navigate to="/" replace />;
  return <>{children}</>;
}

function App() {
  const { admin } = useSession();
  const all: Role[] = ['super_admin', 'marketing_admin', 'customer_support'];
  const mkt: Role[] = ['super_admin', 'marketing_admin'];
  const sup: Role[] = ['super_admin', 'customer_support'];
  return (
    <Routes>
      <Route path="/login" element={admin ? <Navigate to="/" replace /> : <LoginPage />} />
      <Route element={admin ? <Layout /> : <Navigate to="/login" replace />}>
        <Route index element={<Guard roles={all}><OverviewPage /></Guard>} />
        <Route path="offers" element={<Guard roles={mkt}><OffersPage /></Guard>} />
        <Route path="offers/new" element={<Guard roles={mkt}><OfferFormPage /></Guard>} />
        <Route path="offers/:id" element={<Guard roles={mkt}><OfferFormPage /></Guard>} />
        <Route path="campaigns" element={<Guard roles={mkt}><CampaignsPage /></Guard>} />
        <Route path="customers" element={<Guard roles={sup}><CustomersPage /></Guard>} />
        <Route path="customers/:id" element={<Guard roles={sup}><CustomerDetailPage /></Guard>} />
        <Route path="redemptions" element={<Guard roles={sup}><RedemptionsPage /></Guard>} />
        <Route path="admins" element={<Guard roles={['super_admin']}><AdminsPage /></Guard>} />
        <Route path="audit" element={<Guard roles={['super_admin']}><AuditPage /></Guard>} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <I18nProvider>
        <SessionProvider>
          <HashRouter>
            <App />
            <Toaster />
          </HashRouter>
        </SessionProvider>
      </I18nProvider>
    </QueryClientProvider>
  </StrictMode>,
);
