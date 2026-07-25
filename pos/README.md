# AIBA POS service

Restaurant / cafeteria point-of-sale backend for cloud-os. FastAPI + Tortoise
ORM + Celery, mirroring the `bank` module's shape. Paired with the `aiba_pos`
Nextcloud app (UI + access control + proxy).

## What it does

- **Menu**: restaurants (tenants), categories, products (with **MXIK/IKPU** + VAT).
- **Sales**: orders (idempotent on `client_uuid`), payments (cash/card/qr), shifts (Z-report).
- **Fiscal**: on payment a `FiscalReceipt` is created and a Celery task registers
  it with the virtual cash register / OFD. Failures retry every minute, so a sale
  made **offline** still becomes a legal fiscal cheque once the connection returns.
- **Offline-first sync**: `GET /api/v2/sync/pull` (menu) + `POST /api/v2/sync/push`
  (batch upload queued orders, idempotent).
- **Reports + AI tool**: `GET /api/v2/reports/sales-summary` and `GET /api/ai/tool`
  (discovered & called by the cloud-os AI chat).

## Auth

- **Service → pos** (cloud-os): `X-Service-Secret: $AIBA_SERVICE_SECRET`.
- **Terminal → pos**: scoped JWT from `POST /api/v2/auth/login`
  (`terminal_code` + `staff_code` + `pin`). The token is pinned to one
  restaurant + terminal + role, so a terminal can never read another
  restaurant's data. Terminal codes and staff PINs are created from cloud-os.

## Run (inside cloud-os)

```bash
cd /Users/mirkhujaev/Documents/cloud-os
docker compose up -d --build pos pos-celery-worker pos-celery-beat pos-db pos-redis
```

Schema is created automatically on boot (Tortoise `generate_schemas`). Aerich
config is in `pyproject.toml` for future migrations.

## 60-second smoke test

```bash
SECRET=dev-service-secret          # = AIBA_SERVICE_SECRET in your .env
BASE=http://localhost:8005

# 1) Seed a demo restaurant + terminal + staff + menu
curl -s -X POST $BASE/api/internal/admin/seed-demo -H "X-Service-Secret: $SECRET" | jq

# 2) Log a terminal in (cashier PIN 0000) → JWT
TOKEN=$(curl -s -X POST $BASE/api/v2/auth/login -H 'Content-Type: application/json' \
  -d '{"terminal_code":"T1","staff_code":"101","pin":"0000","open_shift":true}' | jq -r .access_token)

# 3) Pull the menu (offline cache)
curl -s $BASE/api/v2/sync/pull -H "Authorization: Bearer $TOKEN" | jq '.products[0]'

# 4) Create a paid order (cash) → triggers a fiscal cheque
curl -s -X POST $BASE/api/v2/orders -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"client_uuid":"test-1","items":[{"name":"Palov","qty":2,"price":35000,"mxik_code":"10112001001000000"}],"payments":[{"method":"cash","amount":70000}]}' | jq

# 5) See it in today's sales
curl -s $BASE/api/v2/reports/sales-summary -H "Authorization: Bearer $TOKEN" | jq
```

Within ~1s the order's `fiscal.status` becomes `sent` with a `fiscal_sign` and a
`qr_url` (mock provider). Switch `FISCAL_PROVIDER=multikassa` (+ `FISCAL_API_URL`,
`FISCAL_API_TOKEN`) to register real cheques.

## E-POS Communicator integration

Real physical fiscal module (E-POS Systems, Universal Communicator 3.23.6+)
is supported via `FISCAL_PROVIDER=epos`. E-POS Communicator runs on the
cashier PC and listens on `http://localhost:8347/uzpos` (JSON-RPC style —
one endpoint, method chosen by the `method` body field).

Env variables:
```
FISCAL_PROVIDER=epos
EPOS_API_URL=http://localhost:8347/uzpos        # or integration.epos.uz for tests
EPOS_TOKEN=<per-device token from E-POS Systems>
EPOS_PORT=3448                                  # openZreport port (device-specific)
```

What the provider does:
- `sale` / `refund` / `advance` — creates fiscal cheque, returns `fiscalSign`
  + `qrCodeURL` (identical response shape to mock/multikassa)
- Sends our `FiscalReceipt.id` as **`externalID`** — E-POS is idempotent on
  it (`DUPLICATE_EXTERNAL_ID` → we fetch the existing cheque via
  `checkReceiptIfExists` and return it). Safe for celery retries.
- Amounts in tiyin (× 100), qty in millim (× 1000), VAT per line auto-computed.
- Shift open/close hooks: `POST /api/v2/shifts/open` and `/shifts/close` also
  call `openZreport` / `closeZreport` when `FISCAL_PROVIDER=epos`.

Debug endpoints (service-secret only):
```
GET /api/v2/fiscal/epos/health         # → {ok, error} — checkStatus
GET /api/v2/fiscal/epos/shift-status   # → {is_open}   — getZReportsStatus
```

Requires each `Restaurant` to have `legal_name` / `inn` / `address` populated
and each `StaffUser.full_name` — they are sent as `companyName` / `companyINN`
/ `companyAddress` / `staffName` on every cheque (E-POS majburiy).

## Layout

```
app/core/      config, database (Tortoise), celery, security (JWT/PIN), redis
app/models/    restaurant, menu, order, fiscal
app/services/  orders (business logic), fiscal/ (provider abstraction + mock + multikassa)
app/tasks/     fiscal (submit + retry-pending beat)
app/api/v2/    auth, menu, orders, sync, shifts, fiscal, reports
app/api/internal/  admin (restaurants/terminals/staff), seed-demo
app/api/ai/    AI tool endpoint
```
