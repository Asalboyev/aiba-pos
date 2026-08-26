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

  /// GET /orders-unfiscalized — bugungi fiskal qilinmagan naqd cheklar
  /// (F12 ro'yxati): id, number, total, created_at.
  Future<List<Map<String, dynamic>>> listUnfiscalized() async {
    // noLogout: server eski bo'lsa (endpoint yo'q) kassir logout bo'lmasin.
    final res = await _client.get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/orders-unfiscalized',
        noLogout: true);
    final items = (res.data?['items'] as List?) ?? const [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// POST /orders/{id}/fiscalize — NAQD chekni talab bo'yicha fiskal qilish
  /// (mijoz chek so'radi, kassir F12 bosdi). Server navbatga qo'yadi.
  Future<void> fiscalize(String orderId) async {
    await _client.post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/orders/$orderId/fiscalize',
        noLogout: true);
  }

  /// GET /api/v2/orders/{id} — re-fetch after checkout to see if the fiscal
  /// receipt has transitioned from `pending` to `sent`.
  Future<Map<String, dynamic>> fetchOrder(String orderId) async {
    final res =
        await _client.get<Map<String, dynamic>>('/api/v2/pos-terminal/orders/$orderId');
    return res.data ?? const {};
  }
}
