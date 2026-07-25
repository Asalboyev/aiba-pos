import '../../../../core/errors/failure.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/menu_repository.dart';
import '../datasources/menu_local_datasource.dart';
import '../datasources/sync_remote_datasource.dart';

class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl({
    required SyncRemoteDataSource remote,
    required MenuLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final SyncRemoteDataSource _remote;
  final MenuLocalDataSource _local;

  @override
  Future<List<Category>> cachedCategories() => _local.categories();

  @override
  Future<List<Product>> cachedProducts() => _local.products();

  @override
  Future<bool> refreshFromServer() async {
    try {
      final pull = await _remote.pull();
      await _local.replaceMenu(pull.categories, pull.products);
      return true;
    } on Failure {
      // Offline / server error — keep the existing cache.
      return false;
    } catch (_) {
      return false;
    }
  }
}
