import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Menu categories cached from `/sync/pull`.
class CachedCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Products cached from `/sync/pull`.
class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0))();
  TextColumn get mxikCode => text().nullable()();
  TextColumn get packageCode => text().nullable()();
  RealColumn get vatPercent => real().withDefault(const Constant(12))();
  TextColumn get unit => text().withDefault(const Constant('dona'))();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get markingRequired => boolean().withDefault(const Constant(false))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  RealColumn get stockQty => real().withDefault(const Constant(0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(10))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The offline order queue. Every checkout is written here FIRST with a
/// generated [clientUuid]; sync re-sends unsynced rows idempotently.
class PendingOrders extends Table {
  /// Monotonic insertion sequence — gives a deterministic newest-first order
  /// even when several orders land within the same clock second.
  IntColumn get seq => integer().autoIncrement()();

  /// uuid v4 — idempotency key shared with the backend.
  TextColumn get clientUuid => text().unique()();

  /// Full OrderIn JSON payload (items, payments, discount, table_no, note).
  TextColumn get payloadJson => text()();

  /// Whether the backend has accepted this order.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// Backend order id once synced.
  TextColumn get serverOrderId => text().nullable()();

  /// Human-readable backend order number once synced.
  TextColumn get orderNumber => text().nullable()();

  /// Latest fiscal status string (pending/success/failed/null).
  TextColumn get fiscalStatus => text().nullable()();

  /// Fiscal QR URL once available.
  TextColumn get fiscalQrUrl => text().nullable()();

  /// Cached total so'm for offline listing.
  IntColumn get total => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [CachedCategories, CachedProducts, PendingOrders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Inject a connection for tests (e.g. in-memory NativeDatabase.memory()).
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2 → cached_products'ga marking_required ustuni qo'shildi
            // (markirovka mahsulotlarni ajratish uchun).
            await m.addColumn(cachedProducts, cachedProducts.markingRequired);
          }
          if (from < 3) {
            // v3 → ombor/inventar maydonlari
            await m.addColumn(cachedProducts, cachedProducts.trackStock);
            await m.addColumn(cachedProducts, cachedProducts.stockQty);
            await m.addColumn(cachedProducts, cachedProducts.lowStockThreshold);
          }
          if (from < 4) {
            // v4 → kategoriya rasmi (admin panelda o'rnatiladi)
            await m.addColumn(cachedCategories, cachedCategories.imageUrl);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'aiba_pos.db'));
    return NativeDatabase.createInBackground(file);
  });
}
