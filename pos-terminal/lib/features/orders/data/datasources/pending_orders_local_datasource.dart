import 'dart:convert';

import 'package:drift/drift.dart';

// The generated drift code defines a data class also named `PendingOrder`
// (from the PendingOrders table), so hide it to avoid colliding with our
// domain entity of the same name.
import '../../../../core/database/app_database.dart' hide PendingOrder;
import '../../domain/entities/pending_order.dart';

/// The offline order queue, backed by the `PendingOrders` drift table.
class PendingOrdersLocalDataSource {
  PendingOrdersLocalDataSource(this._db);
  final AppDatabase _db;

  /// Insert a freshly-created (unsynced) order.
  Future<void> insert({
    required String clientUuid,
    required Map<String, dynamic> payload,
    required num total,
  }) async {
    await _db.into(_db.pendingOrders).insert(
          PendingOrdersCompanion.insert(
            clientUuid: clientUuid,
            payloadJson: jsonEncode(payload),
            total: Value(total.round()),
          ),
          mode: InsertMode.insertOrIgnore, // idempotent on client_uuid
        );
  }

  /// All orders not yet accepted by the backend, with their payloads.
  Future<List<({String clientUuid, Map<String, dynamic> payload})>>
      unsynced() async {
    final rows = await (_db.select(_db.pendingOrders)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
        .get();
    return rows
        .map((r) => (
              clientUuid: r.clientUuid,
              payload: (jsonDecode(r.payloadJson) as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  /// Delete a queued order (used when backend rejects with 4xx — retry won't help).
  Future<void> removeByClientUuid(String clientUuid) async {
    await (_db.delete(_db.pendingOrders)
          ..where((t) => t.clientUuid.equals(clientUuid)))
        .go();
  }

  Future<int> unsyncedCount() async {
    final count = _db.pendingOrders.clientUuid.count();
    final query = _db.selectOnly(_db.pendingOrders)
      ..addColumns([count])
      ..where(_db.pendingOrders.synced.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Mark an order synced and store backend metadata.
  Future<void> markSynced({
    required String clientUuid,
    String? serverOrderId,
    String? orderNumber,
    String? fiscalStatus,
    String? fiscalQrUrl,
  }) async {
    await (_db.update(_db.pendingOrders)
          ..where((t) => t.clientUuid.equals(clientUuid)))
        .write(
      PendingOrdersCompanion(
        synced: const Value(true),
        serverOrderId: Value(serverOrderId),
        orderNumber: Value(orderNumber),
        fiscalStatus: Value(fiscalStatus),
        fiscalQrUrl: Value(fiscalQrUrl),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Payload'ni qayta yozish — oflayn fiskal natijasi (`offline_fiscal`)
  /// qo'shilganda, sync push serverga o'sha natija bilan yetib borishi uchun.
  Future<void> updatePayload({
    required String clientUuid,
    required Map<String, dynamic> payload,
  }) async {
    await (_db.update(_db.pendingOrders)
          ..where((t) => t.clientUuid.equals(clientUuid)))
        .write(PendingOrdersCompanion(payloadJson: Value(jsonEncode(payload))));
  }

  /// Update only the fiscal fields (e.g. after an online checkout response).
  Future<void> updateFiscal({
    required String clientUuid,
    String? fiscalStatus,
    String? fiscalQrUrl,
  }) async {
    await (_db.update(_db.pendingOrders)
          ..where((t) => t.clientUuid.equals(clientUuid)))
        .write(
      PendingOrdersCompanion(
        fiscalStatus: Value(fiscalStatus),
        fiscalQrUrl: Value(fiscalQrUrl),
      ),
    );
  }

  Future<List<PendingOrder>> recent({int limit = 50}) async {
    final rows = await (_db.select(_db.pendingOrders)
          ..orderBy([
            (t) => OrderingTerm(expression: t.seq, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows
        .map((r) => PendingOrder(
              clientUuid: r.clientUuid,
              total: r.total,
              synced: r.synced,
              serverOrderId: r.serverOrderId,
              orderNumber: r.orderNumber,
              fiscalStatus: r.fiscalStatus,
              fiscalQrUrl: r.fiscalQrUrl,
              createdAt: r.createdAt,
            ))
        .toList();
  }
}
