import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../../data/datasources/orders_remote_datasource.dart';
import '../../data/datasources/pending_orders_local_datasource.dart';
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
