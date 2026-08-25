import '../entities/checkout_result.dart';
import '../entities/fiscal_info.dart';
import '../entities/order_draft.dart';
import '../entities/pending_order.dart';

abstract class OrdersRepository {
  /// Save the order to the local queue FIRST, then attempt an immediate sync.
  /// Always succeeds locally; [CheckoutResult.synced] reflects the backend.
  Future<CheckoutResult> checkout(OrderDraft draft);

  /// Push all unsynced orders to `/sync/push`. Returns how many got synced.
  Future<int> syncPending();

  /// All locally-known orders, newest first.
  Future<List<PendingOrder>> recentOrders({int limit = 50});

  /// Count of orders still waiting to sync.
  Future<int> unsyncedCount();

  /// Re-fetch fiscal info for an order (used to poll after checkout while the
  /// backend celery worker is registering the cheque with the OFD).
  Future<FiscalInfo?> fetchFiscal(String orderId);

  /// Naqd chekni talab bo'yicha fiskal qilish (F12) — server navbatga qo'yadi.
  Future<void> fiscalize(String orderId);
}
