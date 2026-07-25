import '../../../../core/network/dio_client.dart';
import '../models/menu_models.dart';

/// Talks to `/sync/pull` and `/sync/push`. Used by both the menu repository
/// (pull) and the orders sync service (push).
class SyncRemoteDataSource {
  SyncRemoteDataSource(this._client);
  final DioClient _client;

  Future<SyncPullResult> pull() async {
    final res = await _client.get<Map<String, dynamic>>('/api/v2/pos-terminal/sync/pull');
    return SyncPullResult.fromJson(res.data ?? const {});
  }

  /// Push a batch of OrderIn payloads. Returns the `results` array.
  Future<List<Map<String, dynamic>>> push(
    List<Map<String, dynamic>> orders,
  ) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/v2/pos-terminal/sync/push',
      data: {'orders': orders},
    );
    final results = (res.data?['results'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return results;
  }
}
