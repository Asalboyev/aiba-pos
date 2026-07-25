import '../../../../core/network/dio_client.dart';

/// POST /orders for an immediate online checkout.
class OrdersRemoteDataSource {
  OrdersRemoteDataSource(this._client);
  final DioClient _client;

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderIn,
  ) async {
    final res =
        await _client.post<Map<String, dynamic>>('/api/v2/pos-terminal/orders', data: orderIn);
    return res.data ?? const {};
  }

  /// GET /api/v2/orders/{id} — re-fetch after checkout to see if the fiscal
  /// receipt has transitioned from `pending` to `sent`.
  Future<Map<String, dynamic>> fetchOrder(String orderId) async {
    final res =
        await _client.get<Map<String, dynamic>>('/api/v2/pos-terminal/orders/$orderId');
    return res.data ?? const {};
  }
}
