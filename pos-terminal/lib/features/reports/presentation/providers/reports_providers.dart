import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/reports_remote_datasource.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/repositories/reports_repository.dart';

final reportsRemoteDataSourceProvider = Provider<ReportsRemoteDataSource>((ref) {
  return ReportsRemoteDataSource(ref.watch(dioClientProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(ref.watch(reportsRemoteDataSourceProvider));
});

/// autoDispose: ekrandan chiqilganda holat tashlanadi — qayta kirilganda
/// yangidan so'raladi. Xato holati "yopishib" qolmaydi.
final salesSummaryProvider = FutureProvider.autoDispose<SalesSummary>((ref) {
  return ref.watch(reportsRepositoryProvider).salesSummary();
});

/// Bugungi eng ko'p sotilgan mahsulotlar (Ish vaqti "Top mahsulotlar" paneli).
class TopProduct {
  const TopProduct(
      {required this.name,
      required this.qty,
      required this.amount,
      this.imageUrl});
  final String name;
  final num qty;
  final num amount;
  final String? imageUrl;
}

final topProductsProvider =
    FutureProvider.autoDispose<List<TopProduct>>((ref) async {
  final base = ref.read(appConfigProvider).baseUrl;
  final res = await ref
      .watch(dioClientProvider)
      .get('/api/v2/pos-terminal/reports/top-products');
  final data = res.data;
  final items = (data is Map ? data['items'] : null) as List? ?? const [];
  String? abs(String? u) {
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http')) return u;
    return base.replaceAll(RegExp(r'/+$'), '') +
        (u.startsWith('/') ? u : '/$u');
  }

  return items.map((e) {
    final m = (e as Map);
    return TopProduct(
      name: (m['name'] ?? '').toString(),
      qty: num.tryParse('${m['qty']}') ?? 0,
      amount: num.tryParse('${m['amount']}') ?? 0,
      imageUrl: abs(m['image_url']?.toString()),
    );
  }).toList();
});

/// Bugungi bekor qilingan / xato urilgan cheklar (Ish vaqti — "Amalga
/// oshmagan buyurtmalar" bo'limi, Figma).
class FailedOrder {
  const FailedOrder({
    required this.number,
    required this.total,
    required this.createdAt,
    required this.cancelled,
    this.note,
  });
  final String number;
  final num total;
  final DateTime? createdAt;

  /// true = bekor qilingan (qizil), false = xato urilgan (sariq).
  final bool cancelled;
  final String? note;
}

/// Bugungi keldi-ketdi (VIP comp) cheklar soni — Ish vaqti ko'rsatkichi.
final keldiKetdiTodayProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref
      .watch(dioClientProvider)
      .get('/api/v2/pos-terminal/keldi-ketdi/recent?limit=200');
  final items =
      ((res.data is Map ? res.data['items'] : null) as List?) ?? const [];
  final now = DateTime.now();
  var n = 0;
  for (final e in items) {
    final t = DateTime.tryParse('${(e as Map)['event_time']}');
    if (t != null &&
        t.toLocal().year == now.year &&
        t.toLocal().month == now.month &&
        t.toLocal().day == now.day) {
      n++;
    }
  }
  return n;
});

final failedOrdersProvider =
    FutureProvider.autoDispose<List<FailedOrder>>((ref) async {
  final res = await ref
      .watch(dioClientProvider)
      .get('/api/v2/pos-terminal/reports/failed-orders');
  final data = res.data;
  final items = (data is Map ? data['items'] : null) as List? ?? const [];
  return items.map((e) {
    final m = (e as Map);
    return FailedOrder(
      number: (m['number'] ?? '').toString(),
      total: num.tryParse('${m['total']}') ?? 0,
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
      cancelled: (m['kind'] ?? '') == 'cancelled',
      note: m['note']?.toString(),
    );
  }).toList();
});
