import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/category.dart' as domain;
import '../../domain/entities/product.dart' as domain;

/// Reads/writes the cached menu in the local drift database.
class MenuLocalDataSource {
  MenuLocalDataSource(this._db);
  final AppDatabase _db;

  Future<List<domain.Category>> categories() async {
    final rows = await (_db.select(_db.cachedCategories)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .get();
    return rows
        .map((r) => domain.Category(
            id: r.id, name: r.name, sortOrder: r.sortOrder, imageUrl: r.imageUrl))
        .toList();
  }

  Future<List<domain.Product>> products() async {
    final rows = await (_db.select(_db.cachedProducts)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    return rows
        .map((r) => domain.Product(
              id: r.id,
              categoryId: r.categoryId,
              name: r.name,
              sku: r.sku,
              price: r.price,
              mxikCode: r.mxikCode,
              packageCode: r.packageCode,
              vatPercent: r.vatPercent,
              unit: r.unit,
              imageUrl: r.imageUrl,
              isActive: r.isActive,
              markingRequired: r.markingRequired,
              trackStock: r.trackStock,
              stockQty: r.stockQty,
              lowStockThreshold: r.lowStockThreshold,
            ))
        .toList();
  }

  /// Atomically replace the cached menu with a fresh pull.
  Future<void> replaceMenu(
    List<domain.Category> categories,
    List<domain.Product> products,
  ) async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedCategories).go();
      await _db.delete(_db.cachedProducts).go();
      await _db.batch((b) {
        b.insertAll(
          _db.cachedCategories,
          categories.map(
            (c) => CachedCategoriesCompanion.insert(
              id: c.id,
              name: c.name,
              sortOrder: Value(c.sortOrder),
              imageUrl: Value(c.imageUrl),
            ),
          ),
        );
        b.insertAll(
          _db.cachedProducts,
          products.map(
            (p) => CachedProductsCompanion.insert(
              id: p.id,
              categoryId: Value(p.categoryId),
              name: p.name,
              sku: Value(p.sku),
              price: Value(p.price.toDouble()),
              mxikCode: Value(p.mxikCode),
              packageCode: Value(p.packageCode),
              vatPercent: Value(p.vatPercent.toDouble()),
              unit: Value(p.unit),
              imageUrl: Value(p.imageUrl),
              isActive: Value(p.isActive),
              markingRequired: Value(p.markingRequired),
              trackStock: Value(p.trackStock),
              stockQty: Value(p.stockQty.toDouble()),
              lowStockThreshold: Value(p.lowStockThreshold.toDouble()),
            ),
          ),
        );
      });
    });
  }
}
