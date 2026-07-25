import 'fiscal_info.dart';

/// Outcome of a checkout: always saved locally; [synced] indicates whether the
/// backend accepted it during the immediate sync attempt.
class CheckoutResult {
  final String clientUuid;
  final bool synced;
  final String? orderId;  // backend UUID — needed to poll for fiscal_sign
  final String? orderNumber;
  final num total;
  final FiscalInfo? fiscal;

  /// True when the order was saved locally but could not reach the backend
  /// due to network/server issues (recoverable — will retry later).
  final bool savedOffline;

  /// Client-side validation error from backend (400) — NOT recoverable by retry.
  /// Kassir choralar ko'rishi kerak (masalan markirovka skanerlash).
  final String? clientError;

  const CheckoutResult({
    required this.clientUuid,
    required this.synced,
    required this.total,
    this.orderId,
    this.orderNumber,
    this.fiscal,
    this.savedOffline = false,
    this.clientError,
  });

  CheckoutResult copyWith({FiscalInfo? fiscal}) => CheckoutResult(
        clientUuid: clientUuid,
        synced: synced,
        total: total,
        orderId: orderId,
        orderNumber: orderNumber,
        fiscal: fiscal ?? this.fiscal,
        savedOffline: savedOffline,
        clientError: clientError,
      );
}
