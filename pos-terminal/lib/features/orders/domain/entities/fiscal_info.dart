import 'package:equatable/equatable.dart';

/// Fiscal receipt info attached to an order by the backend OFD integration.
class FiscalInfo extends Equatable {
  final String status; // pending / success / failed / ...
  final String? provider;
  final String? fiscalSign;
  final String? fiscalId;
  final String? qrUrl;
  final int retries;

  const FiscalInfo({
    required this.status,
    this.provider,
    this.fiscalSign,
    this.fiscalId,
    this.qrUrl,
    this.retries = 0,
  });

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isFailed => status.toLowerCase() == 'failed';

  static FiscalInfo? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return FiscalInfo(
      status: (j['status'] ?? 'pending').toString(),
      provider: j['provider']?.toString(),
      fiscalSign: j['fiscal_sign']?.toString(),
      fiscalId: j['fiscal_id']?.toString(),
      qrUrl: j['qr_url']?.toString(),
      retries: (j['retries'] is num) ? (j['retries'] as num).toInt() : 0,
    );
  }

  @override
  List<Object?> get props =>
      [status, provider, fiscalSign, fiscalId, qrUrl, retries];
}
