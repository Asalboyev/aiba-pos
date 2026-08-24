import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../domain/entities/checkout_result.dart';
import '../providers/orders_providers.dart';
import 'error_check_dialog.dart';

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
    this.onMarkedError,
  });

  final CheckoutResult result;

  /// Called with the (possibly refreshed) result — dialog passes the latest
  /// fiscal state so the print job carries the correct sign + QR.
  final void Function(CheckoutResult refreshed) onPrint;
  final String? printMessage;

  /// Chek "xato" deb belgilanganda — XATO CHEK bannerли nusxani chop etish
  /// va keyingi (to'g'ri) chekда havola qoldirish uchun.
  final void Function(String reason, String? note)? onMarkedError;

  static Future<void> show(
    BuildContext context, {
    required CheckoutResult result,
    required void Function(CheckoutResult refreshed) onPrint,
    String? printMessage,
    void Function(String reason, String? note)? onMarkedError,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FiscalResultDialog(
        result: result,
        onPrint: onPrint,
        printMessage: printMessage,
        onMarkedError: onMarkedError,
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
    // Fiskal allaqachon final (yoki oflayn) — chekni darhol chiqaramiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _timer == null) _autoPrint();
    });
  }

  /// Chek AVTOMATIK chop etiladi (kassir P bosmasin) — fiskal holat final
  /// bo'lishi bilan bir marta. Printer yo'q bo'lsa jimgina o'tib ketadi.
  bool _autoPrinted = false;
  void _autoPrint() {
    if (_autoPrinted || !_printEnabled) return;
    _autoPrinted = true;
    widget.onPrint(_result);
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
        _autoPrint();
        return;
      }
    }
    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      // Fiskal javob bermadi — chekni baribir chiqaramiz (mijoz kutmasin).
      _autoPrint();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// X klavishi / "Xato urildimi?" tugmasi — chekni xato deb belgilash.
  Future<void> _markError() async {
    final r = await ErrorCheckDialog.show(context);
    if (r == null) return;
    final oid = _result.orderId;
    var ok = false;
    if (oid != null) {
      try {
        await ref.read(dioClientProvider).post(
          '/api/v2/pos-terminal/orders/$oid/mark-error',
          data: {'reason': r.reason, 'note': r.note},
        );
        ok = true;
      } catch (_) {}
    }
    // XATO CHEK nusxasini chop etamiz (chek raqami + sabab bilan) va
    // keyingi to'g'ri chekда shu raqamga havola qoldiramiz.
    widget.onMarkedError?.call(r.reason, r.note);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Xato chek deb belgilandi: ${r.reason}'
              : 'Belgilandi (oflayn): ${r.reason}'),
        ),
      );
    }
  }

  bool get _printEnabled {
    if (!_result.synced) return true; // offline chek — QR'siz chop etsa ham bo'ladi
    final s = _result.fiscal?.status.toLowerCase();
    // Fiscal chek final holatga o'tguncha chop etishni bloklaymiz.
    return s == 'sent' || s == 'success' || s == 'failed';
  }

  @override
  Widget build(BuildContext context) {
    final fiscal = _result.fiscal;
    final status = fiscal?.status.toLowerCase();
    final waiting = _result.synced && (status == 'pending' || status == null);

    final hasClientError = _result.clientError != null;
    final IconData icon;
    final Color iconColor;
    final String title;
    if (_result.synced) {
      icon = Icons.check_circle;
      iconColor = PosColors.green;
      title = 'Buyurtma qabul qilindi';
    } else if (hasClientError) {
      icon = Icons.error;
      iconColor = PosColors.red;
      title = 'Buyurtma yaratib bo\'lmadi';
    } else {
      icon = Icons.cloud_off;
      iconColor = const Color(0xFFF5A623);
      title = 'Oflayn saqlandi';
    }
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: screenH - 60),
        // Klaviatura: Enter — Yopish, P — Chop etish (tayyor bo'lsa).
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.keyP && _printEnabled) {
              widget.onPrint(_result);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.keyX &&
                _result.synced &&
                _result.clientError == null) {
              _markError();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Chek / Summa / Holati.
                      Container(
                        decoration: BoxDecoration(
                          color: PosColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PosColors.cardBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        child: Column(
                          children: [
                            if (_result.orderNumber != null)
                              _infoRow('Chek :', '#${_result.orderNumber}'),
                            _infoRow('Summa :', Money.formatSom(_result.total)),
                            if (fiscal != null)
                              _infoRowWidget('Holati :',
                                  _FiscalStatusChip(status: fiscal.status)),
                          ],
                        ),
                      ),
                      if (hasClientError) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x1FE5484D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x33E5484D)),
                          ),
                          child: Text(_result.clientError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFE5847D))),
                        ),
                      ] else if (!_result.synced) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Internet yo\'q — buyurtma navbatga qo\'shildi va keyin avtomatik yuboriladi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PosColors.muted),
                        ),
                      ],
                      if (waiting) ...[
                        const SizedBox(height: 14),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Color(0xFFF5A623))),
                          SizedBox(width: 10),
                          Text('E-POS chek yaratayapti…',
                              style: TextStyle(color: PosColors.muted)),
                        ]),
                      ],
                      // Figma: to'lov popupida QR ko'rsatilmaydi — QR faqat
                      // chop etilgan chekda chiqadi.
                      // Xato urildimi? — belgilash (fiskal xato).
                      if (_result.synced && !hasClientError) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _markError,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x1FF5A623),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x33F5A623)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flag_outlined,
                                    color: Color(0xFFF5A623), size: 18),
                                SizedBox(width: 8),
                                Text('Xato urildimi? Belgilash',
                                    style: TextStyle(
                                        color: Color(0xFFF5A623),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (widget.printMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(widget.printMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: PosColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                if (!hasClientError) ...[
                  Expanded(
                    child: _ResultBtn(
                      label: _printEnabled ? 'Chop etish' : 'Kutilmoqda…',
                      icon: Icons.print,
                      filled: false,
                      onTap: _printEnabled ? () => widget.onPrint(_result) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _ResultBtn(
                    label: 'Yopish',
                    filled: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // Klaviatura yo'riqnomasi — kassir sichqonchasiz ishlaydi.
              const Text(
                'Enter — Yopish · P — Chop etish · X — Xato belgilash',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5C626A), fontSize: 12),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: PosColors.muted, fontSize: 15)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _infoRowWidget(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: PosColors.muted, fontSize: 15)),
          value,
        ]),
      );
}

class _ResultBtn extends StatelessWidget {
  const _ResultBtn(
      {required this.label, required this.filled, required this.onTap, this.icon});
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? PosColors.blue : PosColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? PosColors.blue : PosColors.cardBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
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
      'sent' || 'success' => (PosColors.green, 'Yuborildi'),
      'pending' => (const Color(0xFFF5A623), 'Kutilmoqda'),
      'failed' => (PosColors.red, 'Xato'),
      _ => (PosColors.muted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
