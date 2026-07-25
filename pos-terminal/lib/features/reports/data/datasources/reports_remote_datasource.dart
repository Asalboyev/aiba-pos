import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sales_summary.dart';

class ReportsRemoteDataSource {
  ReportsRemoteDataSource(this._client);
  final DioClient _client;

  Future<SalesSummary> salesSummary() async {
    final res = await _client
        .get<Map<String, dynamic>>('/api/v2/pos-terminal/reports/sales-summary');
    final j = res.data ?? const {};
    final tops = (j['top_products'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .map((m) => TopProduct(
              name: (m['name'] ?? '').toString(),
              qty: Money.parse(m['qty']),
              total: Money.parse(m['total']),
            ))
        .toList();
    return SalesSummary(
      ordersCount: (j['orders_count'] is num)
          ? (j['orders_count'] as num).toInt()
          : int.tryParse('${j['orders_count']}') ?? 0,
      totalSales: Money.parse(j['total_sales']),
      totalCash: Money.parse(j['total_cash']),
      totalCard: Money.parse(j['total_card']),
      topProducts: tops,
    );
  }
}
