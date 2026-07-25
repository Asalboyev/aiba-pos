# AIBA POS Terminal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use flutter-craft:flutter-executing to implement this plan task-by-task.

**Goal:** An offline-first Flutter POS terminal (Windows + Android tablet) that talks to the AIBA POS backend (`/api/v2`), works fully offline via a drift cache + pending-order queue, syncs idempotently by `client_uuid`, and prints ESC/POS receipts with the fiscal QR.

**Architecture:** Clean Architecture with Riverpod. `lib/features/<feature>/{domain,data,presentation}/` + `lib/core/`.

**Dependencies:** flutter_riverpod, dio, drift + sqlite3_flutter_libs + path_provider + path, flutter_secure_storage, shared_preferences, connectivity_plus, uuid, esc_pos_utils_plus (2.0.1+6), esc_pos_printer, qr_flutter, equatable. Dev: drift_dev, build_runner.

---

## Core (cross-cutting)

- **Task C1 — App config & money utils.** `core/config/app_config.dart` (persisted base URL + terminal code via shared_preferences + secure storage for token), `core/utils/money.dart` (parse string→num tolerant, format so'm), `core/errors/failure.dart`, `core/network/api_exception.dart`.
- **Task C2 — Dio client.** `core/network/dio_client.dart` — base URL from config, bearer interceptor pulling token from secure storage, JSON.
- **Task C3 — Drift database.** `core/database/app_database.dart` with tables: `CachedCategories`, `CachedProducts`, `PendingOrders` (client_uuid PK, json payload, synced bool, fiscal status, server order id/number).

## Auth feature

- **Task A1 — Domain:** `AuthSession` entity (token, restaurant, terminal, staff, shiftId), `AuthRepository` interface.
- **Task A2 — Data:** `AuthRemoteDataSource` (POST /auth/login), `AuthRepositoryImpl`, session persistence (secure storage token + prefs session json).
- **Task A3 — Presentation:** `auth_providers.dart` (sessionProvider, authControllerProvider), `LoginScreen` with terminal/staff fields + PIN pad + auto-open-shift toggle.

## Menu / Sync feature

- **Task M1 — Domain:** `Category`, `Product` entities, `MenuRepository` interface (cached read + refresh from /sync/pull).
- **Task M2 — Data:** `SyncRemoteDataSource` (/sync/pull, /sync/push), `MenuLocalDataSource` (drift), `MenuRepositoryImpl`.

## Orders feature (the heart: offline-first)

- **Task O1 — Domain:** `CartItem`, `Cart` (with discount + totals logic — UNIT TESTED), `OrderDraft`, `PendingOrder`, `PaymentMethod` enum, `FiscalInfo`, `OrdersRepository` interface.
- **Task O2 — Data:** `OrderMapper` (cart→OrderIn json — UNIT TESTED), `OrdersRemoteDataSource` (POST /orders), `PendingOrdersLocalDataSource` (drift queue), `OrdersRepositoryImpl` (save local first, attempt sync).
- **Task O3 — Sync service:** `SyncService` provider — on connectivity change or manual, /sync/pull menu + /sync/push unsynced orders, mark synced, store fiscal.

## Presentation (screens)

- **Task P1 — POS sale screen:** category tabs + product grid + cart panel (qty +/-, remove, discount) + payment buttons + checkout → save local → immediate sync → fiscal status + QR dialog.
- **Task P2 — Shift screen:** open/close + Z-report totals (/shifts/current, /shifts/open, /shifts/close).
- **Task P3 — Today screen:** /reports/sales-summary.
- **Task P4 — Settings screen:** base URL, terminal code, printer host/port; manual sync button.
- **Task P5 — Home shell + routing + main.dart wiring.**

## Printing

- **Task PR1 — ReceiptBuilder (ESC/POS):** restaurant name, items, total, payment, MXIK note, fiscal QR via esc_pos_utils_plus.
- **Task PR2 — PrinterService:** network printer via esc_pos_printer (host/port from settings); no-printer-safe (returns preview/log).

## Tests

- **Task T1 — Cart total logic unit tests.**
- **Task T2 — Order mapping unit tests.**
- **Task T3 — Receipt preview/widget smoke (optional).**

## Quality gate

- flutter pub get, build_runner, flutter analyze (0 errors), flutter test, README.
</content>
