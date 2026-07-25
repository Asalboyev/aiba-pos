import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/menu_local_datasource.dart';
import '../../data/datasources/sync_remote_datasource.dart';
import '../../data/repositories/menu_repository_impl.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/menu_repository.dart';

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>((ref) {
  return SyncRemoteDataSource(ref.watch(dioClientProvider));
});

final menuLocalDataSourceProvider = Provider<MenuLocalDataSource>((ref) {
  return MenuLocalDataSource(ref.watch(appDatabaseProvider));
});

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepositoryImpl(
    remote: ref.watch(syncRemoteDataSourceProvider),
    local: ref.watch(menuLocalDataSourceProvider),
  );
});

/// Categories from the local cache. Refresh by invalidating this provider.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(menuRepositoryProvider).cachedCategories();
});

/// Products from the local cache.
final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(menuRepositoryProvider).cachedProducts();
});

/// Currently selected category id (null = "All").
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Products filtered by the selected category.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).maybeWhen(
        data: (p) => p,
        orElse: () => const <Product>[],
      );
  final selected = ref.watch(selectedCategoryProvider);
  if (selected == null) return products;
  return products.where((p) => p.categoryId == selected).toList();
});
