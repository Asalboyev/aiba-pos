import '../entities/category.dart';
import '../entities/product.dart';

abstract class MenuRepository {
  /// Read categories from the local cache (works offline).
  Future<List<Category>> cachedCategories();

  /// Read products from the local cache (works offline).
  Future<List<Product>> cachedProducts();

  /// Fetch the latest menu from `/sync/pull` and replace the local cache.
  /// Returns true on success.
  Future<bool> refreshFromServer();
}
