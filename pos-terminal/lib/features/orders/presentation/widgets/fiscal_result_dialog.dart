import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/checkout_result.dart';
import '../providers/orders_providers.dart';

/// Shows the outcome of a checkout: synced/offline status, fiscal status, the
/// fiscal QR (if available), plus a Print button.
///
/// The fiscal cheque is registered asynchronously in the backend (celery →
/// E-POS Communicator), so at checkout time [CheckoutResult.fiscal] is usually
/// `pending`. This dialog polls `GET /api/v2/orders/{id}` every second until
/// it transitions to `sent` (or `failed`), then shows the QR and only then
/// enables the "Print" button — so the printed receipt always carries the
/// fiscal sign + QR, never a bare pending stub.
class FiscalResultDialog extends ConsumerStatefulWidget {
  const FiscalResultDialog({
    super.key,
    required this.result,
    required this.onPrint,
    this.printMessage,
  });

  final CheckoutResult result;

  /// Called with the (possibly refreshed) result — dialog passes the latest
  /// fiscal state so the print job carries the correct sign + QR.
  final void Function(CheckoutResult refreshed) onPrint;
  final String? printMessage;

  static Future<void> show(
    BuildContext context, {
    required CheckoutResult result,
    required void Function(CheckoutResult refreshed) onPrint,
    String? printMessage,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FiscalResultDialog(
        result: result,
        onPrint: onPrint,
        printMessage: printMessage,
      ),
    );
  }

  @override
  ConsumerState<FiscalResultDialog> createState() => _FiscalResultDialogState();
}

class _FiscalResultDialogState extends ConsumerState<FiscalResultDialog> {
  static const _pollInterval = Duration(seconds: 1);
  static const _maxAttempts = 15; // ≈15s — celery + E-POS odatda 2-3s da qaytaradi

  late CheckoutResult _result;
  Timer? _timer;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _maybeStartPolling();
  }

  void _maybeStartPolling() {
    // Faqat online sinxronlangan buyurtmalar uchun (orderId server tomondan keladi)
    // va fiscal hali "pending" bo'lsa polling boshlanadi.
    if (!_result.synced || _result.orderId == null) return;
    final s = _result.fiscal?.status.toLowerCase();
    if (s == 'sent' || s == 'success' || s == 'failed') return;
    _timer = Timer.periodic(_pollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    _attempts++;
    if (!mounted) {
      _timer?.cancel();
      return;
    }
    final repo = ref.read(ordersRepositoryProvider);
    final fiscal = await repo.fetchFiscal(_result.orderId!);
    if (!mounted) return;
    if (fiscal != null) {
      setState(() => _result = _result.copyWith(fiscal: fiscal));
      final s = fiscal.status.toLowerCase();
      if (s == 'sent' || s == 'success' || s == 'failed') {
        _timer?.cancel();
        return;
      }
    }
    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _printEnabled {
    if (!_result.synced) return true; // offline chek — QR'siz chop etsa ham bo'ladi
    final s = _result.fiscal?.status.toLowerCase();
    // Fiscal chek final holatga o'tguncha chop etishni bloklaymiz.
    return s == 'sent' || s == 'success' || s == 'failed';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fiscal = _result.fiscal;
    final qr = fiscal?.qrUrl;
    final status = fiscal?.status.toLowerCase();
    final waiting = _result.synced && (status == 'pending' || status == null);

    final hasClientError = _result.clientError != null;
    final IconData icon;
    final Color iconColor;
    final String title;
    if (_result.synced) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
      title = 'Buyurtma qabul qilindi';
    } else if (hasClientError) {
      icon = Icons.error;
      iconColor = Colors.red;
      title = 'Buyurtma yaratib bo\'lmadi';
    } else {
      icon = Icons.cloud_off;
      iconColor = Colors.orange;
      title = 'Oflayn saqlandi';
    }
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenH - 60,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sarlavha — katta ikona + matn
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // O'rtadagi content — QR juda katta bo'lsa scrollable bo'ladi.
              // Sarlavha va tugmalar esa doim ko'rinishida.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              // Chek raqami + summa — katta highlighted karta
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (_result.orderNumber != null)
                      Text(
                        'Chek #${_result.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      Money.formatSom(_result.total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (hasClientError)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _result.clientError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                )
              else if (!_result.synced)
                const Text(
                  'Internet yo\'q — buyurtma navbatga qo\'shildi va keyin avtomatik yuboriladi.',
                  textAlign: TextAlign.center,
                ),
              if (fiscal != null) ...[
                Center(child: _FiscalStatusChip(status: fiscal.status)),
              ],
              if (waiting) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'E-POS chek yaratayapti…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (qr != null && qr.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Center(child: QrImageView(data: qr, size: 200)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Soliq QR — mijoz telefonda skanerlab chekni tekshirishi mumkin',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
              if (widget.printMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.printMessage!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (!hasClientError)
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _printEnabled ? () => widget.onPrint(_result) : null,
                          icon: const Icon(Icons.print),
                          label: Text(
                            _printEnabled ? 'Chop etish' : 'Kutilmoqda…',
                            style: const TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!hasClientError) const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Yopish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiscalStatusChip extends StatelessWidget {
  const _FiscalStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (color, label) = switch (s) {
      'sent' || 'success' => (Colors.green, 'Fiskal: yuborildi'),
      'pending' => (Colors.orange, 'Fiskal: kutilmoqda'),
      'failed' => (Colors.red, 'Fiskal: xato'),
      _ => (Colors.grey, 'Fiskal: $status'),
    };
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
    );
  }
}
