import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { DemoAdminApi } from './api/demo';
import { HttpAdminApi } from './api/http';
import type { Admin, AdminApi, Role } from './api/types';

/**
 * Data source is chosen at build time:
 *   VITE_DATA_SOURCE=api (default) → real backend at VITE_API_BASE_URL
 *   VITE_DATA_SOURCE=demo          → in-browser sample data (for showing the dashboard without a server)
 */
const DATA_SOURCE = (import.meta.env.VITE_DATA_SOURCE as string | undefined) ?? 'api';
const API_BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:3000/api/v1';
const KEY = 'zaad.admin.session';

interface Stored {
  token: string;
  admin: Admin;
}

function read(): Stored | null {
  try {
    const s = sessionStorage.getItem(KEY);
    return s ? (JSON.parse(s) as Stored) : null;
  } catch {
    return null;
  }
}

interface Session {
  api: AdminApi;
  admin: Admin | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  can: (...roles: Role[]) => boolean;
}

const Ctx = createContext<Session | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [stored, setStored] = useState<Stored | null>(read);

  const logout = useCallback(() => {
    try {
      sessionStorage.removeItem(KEY);
    } catch {
      /* ignore */
    }
    setStored(null);
  }, []);

  const api = useMemo<AdminApi>(() => {
    if (DATA_SOURCE === 'demo') {
      const d = new DemoAdminApi();
      const s = read();
      if (s) d.restore(s.token);
      return d;
    }
    // Token lives in sessionStorage: it is gone when the tab closes, and expires server-side after 4h.
    return new HttpAdminApi(API_BASE, () => read()?.token ?? null, logout);
  }, [logout]);

  const login = useCallback(
    async (email: string, password: string) => {
      const r = await api.login(email, password);
      const s = { token: r.accessToken, admin: r.admin };
      try {
        sessionStorage.setItem(KEY, JSON.stringify(s));
      } catch {
        /* private mode: session lasts until reload */
      }
      setStored(s);
    },
    [api],
  );

  const value = useMemo<Session>(
    () => ({
      api,
      admin: stored?.admin ?? null,
      login,
      logout,
      // UI convenience only — the backend enforces every permission.
      can: (...roles) => !!stored && roles.includes(stored.admin.role),
    }),
    [api, stored, login, logout],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useSession() {
  const v = useContext(Ctx);
  if (!v) throw new Error('SessionProvider missing');
  return v;
}

export const isDemo = DATA_SOURCE === 'demo';
