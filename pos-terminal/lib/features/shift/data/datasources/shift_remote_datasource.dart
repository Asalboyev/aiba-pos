import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/shift.dart';

class ShiftRemoteDataSource {
  ShiftRemoteDataSource(this._client, {this.onEposRelay});
  final DioClient _client;

  /// "E-POS (kassa orqali)" rejimida server smena ochish/yopish uchun
  /// Communicator payload'ini qaytaradi — uni lokal yuborish uchun chaqiriladi
  /// (fire-and-forget, fiskal ko'prikka ulanadi).
  final Future<void> Function(Map<String, dynamic>? epos)? onEposRelay;

  static Shift? _parse(Map<String, dynamic>? j) {
    if (j == null) return null;
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return Shift(
      id: (j['id'] ?? '').toString(),
      status: (j['status'] ?? 'open').toString(),
      openedAt: dt(j['opened_at']),
      closedAt: dt(j['closed_at']),
      openingCash: Money.parse(j['opening_cash']),
      totalCash: Money.parse(j['total_cash']),
      totalCard: Money.parse(j['total_card']),
      totalSales: Money.parse(j['total_sales']),
      ordersCount: (j['orders_count'] is num)
          ? (j['orders_count'] as num).toInt()
          : int.tryParse('${j['orders_count']}') ?? 0,
      errorChecksCount: (j['error_checks_count'] is num)
          ? (j['error_checks_count'] as num).toInt()
          : int.tryParse('${j['error_checks_count']}') ?? 0,
    );
  }

  Future<Shift?> current() async {
    final res =
        await _client.get<Map<String, dynamic>>('/api/v2/pos-terminal/shifts/current');
    final shift = (res.data?['shift'] as Map?)?.cast<String, dynamic>();
    return _parse(shift);
  }

  Future<Shift> open(num openingCash) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/v2/pos-terminal/shifts/open',
      data: {'opening_cash': openingCash},
    );
    final shift = (res.data?['shift'] as Map?)?.cast<String, dynamic>();
    // ignore: unawaited_futures
    onEposRelay?.call((res.data?['epos'] as Map?)?.cast<String, dynamic>());
    final parsed = _parse(shift);
    if (parsed == null) throw StateError('Smena ochilmadi');
    return parsed;
  }

  Future<Shift> close({String? shiftId}) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/v2/pos-terminal/shifts/close',
      data: <String, dynamic>{'shift_id': ?shiftId},
    );
    final z = (res.data?['z_report'] as Map?)?.cast<String, dynamic>() ??
        (res.data?['shift'] as Map?)?.cast<String, dynamic>();
    // ignore: unawaited_futures
    onEposRelay?.call((res.data?['epos'] as Map?)?.cast<String, dynamic>());
    final parsed = _parse(z);
    if (parsed == null) throw StateError('Smena yopilmadi');
    return parsed;
  }
}
