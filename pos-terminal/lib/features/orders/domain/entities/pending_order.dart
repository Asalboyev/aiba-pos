import 'package:equatable/equatable.dart';

/// An order as it lives in the local offline queue.
class PendingOrder extends Equatable {
  final String clientUuid;
  final num total;
  final bool synced;
  final String? serverOrderId;
  final String? orderNumber;
  final String? fiscalStatus;
  final String? fiscalQrUrl;
  final DateTime createdAt;

  const PendingOrder({
    required this.clientUuid,
    required this.total,
    required this.synced,
    this.serverOrderId,
    this.orderNumber,
    this.fiscalStatus,
    this.fiscalQrUrl,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        clientUuid,
        total,
        synced,
        serverOrderId,
        orderNumber,
        fiscalStatus,
        fiscalQrUrl,
        createdAt,
      ];
}
