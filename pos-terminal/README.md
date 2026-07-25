# AIBA POS Terminal

Offline-first point-of-sale terminal for the AIBA POS backend, built with
Flutter (Clean Architecture + Riverpod). Targets **Windows desktop** and
**Android tablets**; also builds for macOS for local development.

The terminal caches the menu locally, writes every sale to a local queue
**first**, then syncs to the backend idempotently. It prints ESC/POS receipts
with the fiscal QR over a network printer (and degrades gracefully when no
printer is configured).

---

## Quick start

```bash
cd pos-terminal
flutter pub get
dart run build_runner build            # generates drift code (app_database.g.dart)

# Run on the targets:
flutter run -d windows                 # Windows desktop
flutter run -d <android-device-id>     # Android tablet (see: flutter devices)
flutter run -d macos                   # macOS (dev convenience)
```

> If you edit any drift table or other generated code, re-run
> `dart run build_runner build`.

### Build release artifacts

```bash
flutter build windows                  # build/windows/.../aiba_pos_terminal.exe
flutter build apk                      # build/app/outputs/flutter-apk/app-release.apk
```

---

## Pointing it at the backend

The base URL and terminal code are **configurable and persisted** (no rebuild
needed):

1. On the login screen, tap the gear icon (top-right) to open **Settings**.
2. Set **Base URL** (dev default `http://localhost:8005`) and **Terminal kodi**.
3. (Optional) Set the **Printer IP** + **port** (default `9100`) for a network
   ESC/POS printer. Leave the IP blank to run without a printer.

Settings live in `shared_preferences`; the JWT access token is stored in
`flutter_secure_storage`.

### Demo credentials

After running `POST /api/internal/admin/seed-demo` on the backend:

| Field         | Value         |
| ------------- | ------------- |
| Terminal code | `T1`          |
| Cashier       | staff `101`, PIN `0000` |
| Manager       | staff `100`, PIN `1234` |

On login you can toggle **"Kirishda smenani ochish"** (auto-open shift) and set
the opening cash.

---

## Offline-first + sync flow

```
Checkout
  └─► 1. Write order to local drift queue (pending_orders) with a uuid v4
          client_uuid + synced=false                       ← always succeeds
      2. Attempt immediate POST /api/v2/orders
          ├─ online  → mark synced, store backend order id + fiscal status/QR
          └─ offline → leave queued; show "Oflayn saqlandi"

Background sync (SyncService)
  └─ Triggered on connectivity regained (connectivity_plus) or the manual
     sync button in the app bar:
       • GET  /api/v2/sync/pull   → refresh cached categories + products
       • POST /api/v2/sync/push   → re-send ALL unsynced orders in one batch
     Idempotent: the backend dedupes on client_uuid, so re-sending the whole
     queue after a flaky connection is safe. Synced rows store the returned
     fiscal status/QR.
```

The app bar shows an orange badge with the count of orders still waiting to
sync. The menu refreshes automatically on first launch after login and on every
successful sync.

### Money

All amounts are **so'm** (no tiyin). The backend serializes decimals as strings
(e.g. `"12000.00"`); `core/utils/money.dart` parses these tolerantly and formats
with thousands separators (`25 000 so'm`).

---

## Fiscal receipt + printing

- On checkout the result dialog shows the order number, total, fiscal status
  chip, and the **fiscal QR** (rendered on-screen with `qr_flutter`).
- **Print** builds an 80mm ESC/POS receipt (`esc_pos_utils_plus`) with the
  restaurant name, line items, totals, payment method, an MXIK note, and the
  fiscal QR, then sends it to the configured network printer
  (`esc_pos_printer`, raw TCP to `host:port`).
- **No-printer-safe:** if no printer IP is set (or it is unreachable), printing
  returns a non-fatal report and logs a text preview — checkout still completes.

---

## Architecture

Clean Architecture per feature: `lib/features/<feature>/{domain,data,presentation}/`.

```
lib/
├── core/
│   ├── config/        AppConfig (prefs + secure token)
│   ├── database/      drift AppDatabase (cached menu + pending_orders queue)
│   ├── errors/        Failure types
│   ├── network/       DioClient (base URL + bearer interceptor)
│   ├── providers/     core Riverpod providers (DI)
│   ├── theme/         AppTheme
│   └── utils/         Money
├── features/
│   ├── auth/          terminal+staff login, PIN pad, JWT, auto-open shift
│   ├── menu/          categories + products (cache + /sync/pull)
│   ├── orders/        Cart, OrderDraft, offline queue, checkout, SyncService
│   ├── shift/         open/close shift, Z-report
│   ├── reports/       today's sales summary
│   ├── printing/      ReceiptBuilder (ESC/POS) + PrinterService
│   ├── settings/      base URL / terminal / printer config
│   └── home/          navigation shell (rail / bottom bar)
└── main.dart          ProviderScope, session restore, login↔home routing
```

State management: **Riverpod**. Repository pattern: domain interfaces with
data-layer implementations (remote = dio, local = drift).

### Backend endpoints used (`/api/v2`)

`auth/login`, `sync/pull`, `sync/push`, `orders` (create/list/get/pay),
`fiscal/receipt`, `shifts/open|current|close`, `reports/sales-summary`.

---

## Tests

```bash
flutter analyze     # 0 errors
flutter test        # all green
```

Coverage focuses on the load-bearing logic:

- `test/features/orders/domain/cart_test.dart` — cart subtotal/total/discount,
  qty merge, immutability, out-of-range guards.
- `test/features/orders/data/order_mapper_test.dart` — domain → `OrderIn` JSON
  mapping and response parsing (id / number / fiscal).
- `test/features/orders/data/pending_orders_local_datasource_test.dart` —
  in-memory drift queue: insert, idempotency, mark-synced, newest-first.
- `test/features/orders/widgets/cart_panel_test.dart` — cart panel widget.
- `test/core/money_test.dart` — money parsing/formatting.

---

## Known TODOs / nice-to-haves

- **Receipt re-print / queue screen:** the offline queue is stored and synced,
  but there's no dedicated UI list to re-open/re-print past orders yet (the
  data layer `recentOrders()` already supports it).
- **Multi-payment split** at checkout (UI currently takes one payment; the
  data model + backend already accept a list of payments).
- **Token refresh:** the JWT is long-lived per the backend; there is no refresh
  flow. A 401 surfaces as an auth error — re-login to get a fresh token.
- **Background periodic sync timer** (currently sync runs on connectivity
  change + manual button + post-checkout nudge; a timer could be added).
