import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../menu/data/datasources/sync_remote_datasource.dart';
import '../../domain/entities/checkout_result.dart';
import '../../domain/entities/fiscal_info.dart';
import '../../domain/entities/order_draft.dart';
import '../../domain/entities/pending_order.dart';
import '../../domain/repositories/orders_repository.dart';
import '../datasources/orders_remote_datasource.dart';
import '../datasources/pending_orders_local_datasource.dart';
import '../models/order_mapper.dart';
import '../offline_fiscal_service.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl({
    required OrdersRemoteDataSource remote,
    required SyncRemoteDataSource sync,
    required PendingOrdersLocalDataSource local,
    required OfflineFiscalService offlineFiscal,
    required RestaurantInfo? Function() restaurant,
    required String? Function() staffName,
  })  : _remote = remote,
        _sync = sync,
        _local = local,
        _offlineFiscal = offlineFiscal,
        _restaurant = restaurant,
        _staffName = staffName;

  final OrdersRemoteDataSource _remote;
  final SyncRemoteDataSource _sync;
  final PendingOrdersLocalDataSource _local;
  final OfflineFiscalService _offlineFiscal;
  final RestaurantInfo? Function() _restaurant;
  final String? Function() _staffName;

  /// Server yetib bo'lmaganda: chekni KASSADAGI Communicator orqali darhol
  /// fiskalizatsiya qilishga urinamiz (internet uzilgani soliqqa to'siq emas —
  /// Communicator lokal). Muvaffaqiyatda natija payload'ga yoziladi (sync'da
  /// serverga boradi, ikkinchi fiskalizatsiya bo'lmaydi) va chekka QR chiqadi.
  Future<FiscalInfo?> _tryOfflineFiscal(
    String clientUuid,
    Map<String, dynamic> payload,
  ) async {
    try {
      final r = _restaurant();
      if (r == null || !r.fiscalViaTerminal) return null;
      final result = await _offlineFiscal.fiscalize(
        orderIn: payload,
        restaurant: r,
        staffName: _staffName(),
      );
      if (result == null) return null;
      payload['offline_fiscal'] = result;
      await _local.updatePayload(clientUuid: clientUuid, payload: payload);
      await _local.updateFiscal(
        clientUuid: clientUuid,
        fiscalStatus: 'sent',
        fiscalQrUrl: result['qr_url']?.toString(),
      );
      return FiscalInfo(
        status: 'sent',
        provider: 'epos_terminal',
        fiscalSign: result['fiscal_sign']?.toString(),
        fiscalId: result['fiscal_id']?.toString(),
        qrUrl: result['qr_url']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CheckoutResult> checkout(OrderDraft draft) async {
    final payload = OrderMapper.draftToOrderIn(draft);

    // 1) Always write locally first — this is what makes the POS offline-first.
    await _local.insert(
      clientUuid: draft.clientUuid,
      payload: payload,
      total: draft.total,
    );

    // 2) Attempt an immediate online checkout.
    try {
      final response = await _remote.createOrder(payload);
      final fiscalMap = OrderMapper.fiscalMap(response);
      final fiscal = FiscalInfo.fromJson(fiscalMap);
      await _local.markSynced(
        clientUuid: draft.clientUuid,
        serverOrderId: OrderMapper.orderId(response),
        orderNumber: OrderMapper.orderNumber(response),
        fiscalStatus: fiscal?.status,
        fiscalQrUrl: fiscal?.qrUrl,
      );
      return CheckoutResult(
        clientUuid: draft.clientUuid,
        synced: true,
        total: draft.total,
        orderId: OrderMapper.orderId(response),
        orderNumber: OrderMapper.orderNumber(response),
        fiscal: fiscal,
      );
    } on ServerFailure catch (e) {
      // 4xx (400/422) — bu client xatosi (validatsiya). Retry qilib foyda yo'q,
      // kassir choralar ko'rishi kerak: markirovka skanerlash, MXIK tuzatish
      // va h.k. Lokal queue'dan ham olib tashlaymiz — takrorlanmasin.
      final code = e.statusCode ?? 0;
      if (code >= 400 && code < 500) {
        await _local.removeByClientUuid(draft.clientUuid);
        return CheckoutResult(
          clientUuid: draft.clientUuid,
          synced: false,
          total: draft.total,
          orderNumber: draft.number,
          clientError: e.message,
        );
      }
      // 5xx yoki boshqa server xatosi — offline queue'ga qo'shildi, keyin retry.
      return CheckoutResult(
        clientUuid: draft.clientUuid,
        synced: false,
        total: draft.total,
        orderNumber: draft.number,
        savedOffline: true,
        fiscal: await _tryOfflineFiscal(draft.clientUuid, payload),
      );
    } on Failure {
      // Tarmoq xatosi — offline queue'ga qo'shildi, keyin retry qilinadi.
      // Fiskal esa kutmaydi: lokal Communicator orqali darhol yuboriladi.
      return CheckoutResult(
        clientUuid: draft.clientUuid,
        synced: false,
        total: draft.total,
        orderNumber: draft.number,
        savedOffline: true,
        fiscal: await _tryOfflineFiscal(draft.clientUuid, payload),
      );
    } catch (_) {
      return CheckoutResult(
        clientUuid: draft.clientUuid,
        synced: false,
        total: draft.total,
        orderNumber: draft.number,
        savedOffline: true,
        fiscal: await _tryOfflineFiscal(draft.clientUuid, payload),
      );
    }
  }

  @override
  Future<int> syncPending() async {
    final pending = await _local.unsynced();
    if (pending.isEmpty) return 0;

    final orders = pending.map((e) => e.payload).toList();
    List<Map<String, dynamic>> results;
    try {
      results = await _sync.push(orders);
    } on Failure {
      return 0;
    } catch (_) {
      return 0;
    }

    var synced = 0;
    for (final r in results) {
      final clientUuid = r['client_uuid']?.toString();
      if (clientUuid == null) continue;
      if (r['error'] != null) continue; // leave it queued for next round
      final fiscal = (r['fiscal'] as Map?)?.cast<String, dynamic>();
      await _local.markSynced(
        clientUuid: clientUuid,
        serverOrderId: r['order_id']?.toString(),
        orderNumber: null,
        fiscalStatus: fiscal?['status']?.toString(),
        fiscalQrUrl: fiscal?['qr_url']?.toString(),
      );
      synced++;
    }
    return synced;
  }

  @override
  Future<List<PendingOrder>> recentOrders({int limit = 50}) =>
      _local.recent(limit: limit);

  @override
  Future<int> unsyncedCount() => _local.unsyncedCount();

  @override
  Future<void> fiscalize(String orderId) => _remote.fiscalize(orderId);

  @override
  Future<List<Map<String, dynamic>>> listUnfiscalized() =>
      _remote.listUnfiscalized();

  @override
  Future<Map<String, dynamic>> fetchOrderDetail(String orderId) =>
      _remote.fetchOrder(orderId);

  @override
  Future<FiscalInfo?> fetchFiscal(String orderId) async {
    try {
      final response = await _remote.fetchOrder(orderId);
      // GET /orders/{id} qaytaradi: {..., "fiscal": {...}}
      final fiscal = (response['fiscal'] as Map?)?.cast<String, dynamic>();
      return FiscalInfo.fromJson(fiscal);
    } catch (_) {
      return null;
    }
  }
}
