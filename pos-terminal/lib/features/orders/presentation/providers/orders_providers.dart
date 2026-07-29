import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../../data/datasources/orders_remote_datasource.dart';
import '../../data/datasources/pending_orders_local_datasource.dart';
import '../../data/fiscal_bridge_service.dart';
import '../../data/offline_fiscal_service.dart';
import '../../data/repositories/orders_repository_impl.dart';
import '../../domain/entities/pending_order.dart';
import '../../domain/repositories/orders_repository.dart';

final ordersRemoteDataSourceProvider = Provider<OrdersRemoteDataSource>((ref) {
  return OrdersRemoteDataSource(ref.watch(dioClientProvider));
});

final pendingOrdersLocalDataSourceProvider =
    Provider<PendingOrdersLocalDataSource>((ref) {
  return PendingOrdersLocalDataSource(ref.watch(appDatabaseProvider));
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepositoryImpl(
    remote: ref.watch(ordersRemoteDataSourceProvider),
    sync: ref.watch(syncRemoteDataSourceProvider),
    local: ref.watch(pendingOrdersLocalDataSourceProvider),
    // Oflayn fiskal: server yetib bo'lmasa chek kassadagi Communicator
    // orqali darhol fiskalizatsiya qilinadi (rejim epos_terminal bo'lsa).
    offlineFiscal: OfflineFiscalService(ref.watch(appConfigProvider)),
    restaurant: () => ref.read(sessionProvider)?.restaurant,
    staffName: () => ref.read(sessionProvider)?.staff.name,
  );
});

/// Fiskal ko'prik — "E-POS (kassa orqali)" rejimida navbatdagi cheklarni
/// lokal Communicator orqali soliqqa yuboradi.
final fiscalBridgeProvider = Provider<FiscalBridgeService>((ref) {
  return FiscalBridgeService(
    ref.watch(dioClientProvider),
    ref.watch(appConfigProvider),
  );
});

/// Recent orders for the orders list (offline-aware).
final recentOrdersProvider = FutureProvider<List<PendingOrder>>((ref) {
  return ref.watch(ordersRepositoryProvider).recentOrders();
});

/// Number of orders still waiting to sync — shown as a badge.
final unsyncedCountProvider = FutureProvider<int>((ref) {
  return ref.watch(ordersRepositoryProvider).unsyncedCount();
});
