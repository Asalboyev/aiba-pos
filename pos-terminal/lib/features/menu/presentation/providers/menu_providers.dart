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

/// Qidiruv matni (mahsulot nomi bo'yicha).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Qidiruv satridan MIQDOR qismini olib tashlab, sof atamani qaytaradi:
/// "rec*10" → "rec", "3*cola" → "cola", "rec*" → "rec".
/// Jonli filtr ham, Enter ham shundan foydalanadi — kassir "kod*10" deb
/// yozayotganda grid BO'SHAB QOLMAYDI (avval butun satr bilan qidirilardi).
String searchTermOf(String raw) {
  var r = raw.trim();
  final m1 = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[*xх]\s*(.*)$').firstMatch(r);
  if (m1 != null) return m1.group(2)!.trim();
  final m2 = RegExp(r'^(.+?)\s*[*xх]\s*(\d*(?:[.,]\d+)?)$').firstMatch(r);
  if (m2 != null) return m2.group(1)!.trim();
  return r;
}

/// Qidiruvda klaviatura bilan TANLANGAN natija indeksi (↑↓ yuradi,
/// Enter — shu tanlanganini savatga qo'shadi). Qidiruv matni o'zgarsa 0 ga
/// qaytadi (provider searchQueryProvider'ni kuzatgani uchun avtomatik).
final searchSelProvider = StateProvider<int>((ref) {
  ref.watch(searchQueryProvider);
  return 0;
});

/// Products filtered by the selected category AND the search query.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).maybeWhen(
        data: (p) => p,
        orElse: () => const <Product>[],
      );
  final selected = ref.watch(selectedCategoryProvider);
  final q = searchTermOf(ref.watch(searchQueryProvider)).toLowerCase();
  // MARKIROVKALI mahsulotlar menyuda KO'RINMAYDI: ular faqat F2 (skaner)
  // orqali qo'shiladi — kassir DataMatrix kodni o'qiydi, mahsulot avtomatik
  // savatga tushadi va kod soliqqa ketadi. Menyudan bosib qo'shsa kod
  // bo'lmaydi va chek soliqda rad etiladi.
  var list = products.where((p) => !p.markingRequired).toList();
  if (selected != null) {
    list = list.where((p) => p.categoryId == selected).toList();
  }
  if (q.isNotEmpty) {
    // Nom + kod (SKU) + MXIK bo'yicha qidiramiz — kassir kodni tersa
    // mahsulot darrov topiladi (tez ishlash uchun).
    // Saralash: kassir KO'RGAN birinchi katak = Enter qo'shadigan mahsulot.
    // ANIQ kod mosligi > kod boshlanishi > nom boshlanishi > ichida uchraydi.
    int rank(Product p) {
      final sku = (p.sku ?? '').toLowerCase();
      if (sku == q) return 0;
      if (sku.isNotEmpty && sku.startsWith(q)) return 1;
      if (p.name.toLowerCase().startsWith(q)) return 2;
      return 3;
    }

    list = list.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      final sku = (p.sku ?? '').toLowerCase();
      if (sku.isNotEmpty && sku.contains(q)) return true;
      final mxik = (p.mxikCode ?? '').toLowerCase();
      if (mxik.isNotEmpty && mxik.contains(q)) return true;
      return false;
    }).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
  }
  return list;
});

/// Har kategoriyadagi mahsulotlar soni ("N xil" uchun).
final categoryCountsProvider = Provider<Map<String?, int>>((ref) {
  // Markirovkali mahsulotlar menyuda ko'rinmaydi — sanoqda ham hisoblanmaydi.
  final products = ref
      .watch(productsProvider)
      .maybeWhen(data: (p) => p, orElse: () => const <Product>[])
      .where((p) => !p.markingRequired)
      .toList();
  final counts = <String?, int>{null: products.length};
  for (final p in products) {
    counts[p.categoryId] = (counts[p.categoryId] ?? 0) + 1;
  }
  return counts;
});
