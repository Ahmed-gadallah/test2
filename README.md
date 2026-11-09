# Zaad Pharmacies — Customer Loyalty App

Monorepo for the Zaad Pharmacies customer app (Android / iOS), its backend API and (next) the admin dashboard.

> **Status:** MVP foundation. The ERP integration runs against a **mock adapter** because the ERP vendor
> API does not exist yet. See [`docs/erp-assessment.md`](docs/erp-assessment.md) — the redemption-approval
> flow in particular requires ERP-side development (gap G1).

| Path | What | Stack |
|---|---|---|
| `apps/mobile` | Customer app (Arabic default + English, RTL/LTR) | Flutter 3.47, Riverpod, go_router, dio |
| `apps/backend` | REST API, auth, ERP adapter, redemption workflow, offers, admin RBAC | NestJS 11, Drizzle ORM, PostgreSQL 16 |
| `apps/admin` | Admin dashboard (Arabic default + English): offers, campaigns, customers, redemptions, branches, admins, audit log | React 19, Vite, TanStack Query |
| `docs/` | ERP assessment, integration mapping, architecture | — |

## Quick start (local)

```bash
# 1. database
docker compose up -d postgres

# 2. backend  → http://localhost:3000/api/v1  (Swagger: http://localhost:3000/docs)
cd apps/backend
cp .env.example .env            # dev defaults: mock ERP, console OTP (code printed in the log)
npm ci && npm run build && npm start

# 3. app (demo data inside the app — no backend needed)
cd apps/mobile
flutter pub get
flutter run --dart-define=DATA_SOURCE=demo

# 3b. app against the local backend
flutter run --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1   # Android emulator
```

### Admin dashboard

```bash
# 1. create the first super admin (backend must have run once so the tables exist)
cd apps/backend
ADMIN_EMAIL=you@zaad.example ADMIN_NAME="Your Name" ADMIN_PASSWORD=ChangeMe2026x npm run seed:admin
#    PowerShell: $env:ADMIN_EMAIL="you@zaad.example"; $env:ADMIN_NAME="Your Name"; $env:ADMIN_PASSWORD="ChangeMe2026x"; npm run seed:admin

# 2. run the dashboard → http://localhost:5173
cd ../admin
npm ci
cp .env.example .env        # PowerShell: Copy-Item .env.example .env
npm run dev
```

Roles (enforced by the backend, mirrored in the UI): **super admin** (everything), **marketing admin** (offers, campaigns, branches),
**customer support** (customers, points, invoices, redemptions — read only). Demo build without a backend:
`VITE_DATA_SOURCE=demo npm run build` (demo accounts: `super@zaad.demo`, `marketing@zaad.demo`, `support@zaad.demo`, password `Demo12345678`).

### Branch Locator (فروع زاد)

The branches Excel sheet (`Zaad_Branches_Template`) is the source of truth. Import it once, and again whenever it changes:

```bash
cd apps/backend
npm run build
npm run import:branches -- path/to/Zaad_Branches.xlsx           # dry run: lists what would be created/updated + warnings
npm run import:branches -- path/to/Zaad_Branches.xlsx --apply   # writes it
```

Or from the dashboard: **Branches → Import from Excel → Check file → Apply import** (super/marketing admins).

- Matched by **Branch ID** (= ERP `branch_0.id`): re-importing the same file creates no duplicates; branches missing from the
  file are reported, never deleted. Any row error (duplicate ID, missing name/city/address, bad active value, unreadable phone)
  aborts the whole import.
- **One phone per branch** (calls and delivery). Excel drops the leading 0 from numbers typed as numbers; the import restores it
  (`541418264` → `+966541418264`). A missing phone is allowed: the app hides *Call* and says the number is not available.
- **Location links** must be https Google Maps links and are stored exactly as supplied. The app opens that link; it never resolves
  coordinates or substitutes another location. A missing or invalid link is imported empty (warning) and *View location* is hidden.
- `GET /api/v1/branches` is public and returns **active branches only**. Inactive branches never reach the app.
- Demo builds read `apps/mobile/assets/demo/branches.json` / `apps/admin/src/api/demo-branches.json`, generated from the sheet
  with `npm run export:branches-demo -- <file.xlsx>` (same parser). Real (`DATA_SOURCE=api`) builds never read them.

### Demo accounts (mock ERP / demo mode)
| Mobile | Behaviour |
|---|---|
| `0500000001` | Regular customer, 2,500 points, 34 invoices across 4 branches (demo login password `zaad1234`) |
| `0500000002` | Registered customer with no points/invoices (empty states) |
| `0500000003` | Two ERP records share the number → registration blocked, needs support |
| `0500000004` | Institutional account → not eligible |
| any other | Not a Zaad customer |

OTP in demo/dev: `123456` (only when `OTP_DEV_FIXED_CODE` is set; refused in production).

Simulate the cashier starting a redemption: in the app → Profile → *Demo tools*, or
`POST /api/v1/dev/simulate/cashier-redemption {"mobile":"0500000001","points":1000}` (exists only with the mock ERP).

## Tests

```bash
cd apps/backend && npm test        # 81 tests: auth, loyalty, redemption, invoices, offers, admin RBAC, branch import/locator (needs Postgres)
cd apps/mobile  && flutter test    # unit + widget tests (formatting, deep links, RTL, demo flows, branch search/call/maps)
```

## Security
- Mobile release builds: see [`docs/mobile-release.md`](docs/mobile-release.md) (signing, obfuscation, what the app protects, open items).
- Backend production refuses to start with: mock ERP, console OTP/push, fixed OTP, placeholder or reused secrets,
  wildcard CORS, or a non-HTTPS ERP URL. Set `TRUST_PROXY_HOPS` to the real number of proxies in front of the API.
- The API serves plain HTTP and must sit behind a TLS-terminating proxy/load balancer (HSTS header is already sent).

## Non-negotiable rules (from the spec)
- The ERP is the only source of truth for customers, invoices and **all** points arithmetic. The backend never stores balances and never deducts/adjusts points.
- The mock ERP and console OTP/push providers are **refused at startup** when `NODE_ENV=production`.
- Authorization is enforced in the backend, never only in the UI.

## Assumptions to confirm
- Numbers use Western digits (0-9) in both languages (common on Saudi receipts).
- Redeemable SAR value is shown floored to whole riyals: ERP data shows `point_to_cash` is an integer (50 points = 1 SAR).
- Customer greeting uses the ERP name as-is; falls back to a neutral greeting when empty (ERP names are cashier-typed — gap G4).
- The placeholder wordmark must be replaced by the official logo asset (not provided yet).
