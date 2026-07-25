import 'package:aiba_pos_terminal/core/database/app_database.dart';
import 'package:aiba_pos_terminal/features/orders/data/datasources/pending_orders_local_datasource.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PendingOrdersLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = PendingOrdersLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('inserted order starts unsynced and is counted', () async {
    await ds.insert(
      clientUuid: 'u1',
      payload: {'client_uuid': 'u1', 'items': []},
      total: 12000,
    );
    expect(await ds.unsyncedCount(), 1);
    final pending = await ds.unsynced();
    expect(pending.length, 1);
    expect(pending.first.clientUuid, 'u1');
    expect(pending.first.payload['client_uuid'], 'u1');
  });

  test('insert is idempotent on client_uuid (re-insert ignored)', () async {
    await ds.insert(clientUuid: 'u1', payload: {'v': 1}, total: 1000);
    await ds.insert(clientUuid: 'u1', payload: {'v': 2}, total: 9999);
    expect(await ds.unsyncedCount(), 1);
    final pending = await ds.unsynced();
    expect(pending.first.payload['v'], 1); // original kept
  });

  test('markSynced moves order out of the unsynced set and stores fiscal',
      () async {
    await ds.insert(clientUuid: 'u1', payload: {}, total: 5000);
    await ds.markSynced(
      clientUuid: 'u1',
      serverOrderId: 'srv-1',
      orderNumber: 'NUM1',
      fiscalStatus: 'success',
      fiscalQrUrl: 'https://qr/1',
    );
    expect(await ds.unsyncedCount(), 0);
    final recent = await ds.recent();
    expect(recent.first.synced, isTrue);
    expect(recent.first.serverOrderId, 'srv-1');
    expect(recent.first.fiscalStatus, 'success');
    expect(recent.first.fiscalQrUrl, 'https://qr/1');
  });

  test('recent returns newest first', () async {
    await ds.insert(clientUuid: 'a', payload: {}, total: 1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await ds.insert(clientUuid: 'b', payload: {}, total: 2);
    final recent = await ds.recent();
    expect(recent.first.clientUuid, 'b');
  });
}
