# Zaad Pharmacies — Customer Loyalty App

Monorepo for the Zaad Pharmacies customer app (Android / iOS), its backend API and (next) the admin dashboard.

> **Status:** MVP foundation. The ERP integration runs against a **mock adapter** because the ERP vendor
> API does not exist yet. See [`docs/erp-assessment.md`](docs/erp-assessment.md) — the redemption-approval
> flow in particular requires ERP-side development (gap G1).

| Path | What | Stack |
|---|---|---|
| `apps/mobile` | Customer app (Arabic default + English, RTL/LTR) | Flutter 3.47, Riverpod, go_router, dio |
| `apps/backend` | REST API, auth, ERP adapter, redemption workflow, offers, admin RBAC | NestJS 11, Drizzle ORM, PostgreSQL 16 |
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
cd apps/backend && npm test        # 56 tests: auth, loyalty, redemption, invoices, offers, admin RBAC (needs Postgres)
cd apps/mobile  && flutter test    # unit + widget tests (formatting, deep links, RTL, demo flows)
```

## Non-negotiable rules (from the spec)
- The ERP is the only source of truth for customers, invoices and **all** points arithmetic. The backend never stores balances and never deducts/adjusts points.
- The mock ERP and console OTP/push providers are **refused at startup** when `NODE_ENV=production`.
- Authorization is enforced in the backend, never only in the UI.

## Assumptions to confirm
- Numbers use Western digits (0-9) in both languages (common on Saudi receipts).
- Redeemable SAR value is shown floored to whole riyals: ERP data shows `point_to_cash` is an integer (50 points = 1 SAR).
- Customer greeting uses the ERP name as-is; falls back to a neutral greeting when empty (ERP names are cashier-typed — gap G4).
- The placeholder wordmark must be replaced by the official logo asset (not provided yet).
