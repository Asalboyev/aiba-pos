import '../../../../core/utils/money.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';

class CategoryModel {
  static Category fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        sortOrder: (j['sort_order'] is num)
            ? (j['sort_order'] as num).toInt()
            : int.tryParse('${j['sort_order']}') ?? 0,
        imageUrl: j['image_url']?.toString(),
      );
}

class ProductModel {
  static Product fromJson(Map<String, dynamic> j) => Product(
        id: (j['id'] ?? '').toString(),
        categoryId: j['category_id']?.toString(),
        name: (j['name'] ?? '').toString(),
        sku: j['sku']?.toString(),
        price: Money.parse(j['price']),
        mxikCode: j['mxik_code']?.toString(),
        packageCode: j['package_code']?.toString(),
        vatPercent: Money.parse(j['vat_percent']),
        unit: (j['unit'] ?? 'dona').toString(),
        imageUrl: j['image_url']?.toString(),
        isActive: j['is_active'] == null ? true : j['is_active'] == true,
        markingRequired: j['marking_required'] == true,
        trackStock: j['track_stock'] == true,
        stockQty: Money.parse(j['stock_qty']),
        lowStockThreshold: Money.parse(j['low_stock_threshold']),
      );
}

/// The full `/sync/pull` response.
class SyncPullResult {
  final List<Category> categories;
  final List<Product> products;
  final String? serverTime;

  const SyncPullResult({
    required this.categories,
    required this.products,
    this.serverTime,
  });

  static SyncPullResult fromJson(Map<String, dynamic> j) {
    final cats = (j['categories'] as List? ?? const [])
        .map((e) => CategoryModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final prods = (j['products'] as List? ?? const [])
        .map((e) => ProductModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return SyncPullResult(
      categories: cats,
      products: prods,
      serverTime: j['server_time']?.toString(),
    );
  }
}
