import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../domain/entities/payment_method.dart';

/// QR to'lov oynasi — Click / Uzum.
///
/// Asosiy (tez) yo'l: mijoz ilovasidagi QR kodni KO'RSATADI, kassir 2D skaner
/// bilan o'qiydi → backend Click Pass / merchant API orqali pulni yechadi →
/// order AVTOMATIK yopiladi va fiskal chek chiqadi. Kassir hech narsa bosmaydi.
///
/// Zaxira yo'l: mijoz kassadagi STATIK QRni o'z ilovasida skanerlab to'laydi —
/// kassir pul kelganini ko'rib Enter/«To'lash» bilan tasdiqlaydi va chek
/// chiqadi. Skaner maydoni bu rejimda yo'q, shu sabab tasodifiy Enter xavfsiz.
class QrPayDialog extends ConsumerStatefulWidget {
  const QrPayDialog({super.key, required this.total, this.scanMode = false});
  final num total;

  /// true — Click Pass rejimi (F10): skaner maydoni ochiq keladi, mijoz
  /// ko'rsatgan QR o'qiladi va pul avtomatik yechiladi.
  /// false — statik QR rejimi (F3): mijoz kassadagi QRni ilovasida to'laydi,
  /// kassir qo'lda tasdiqlaydi. Skaner maydoni ko'rsatilmaydi.
  final bool scanMode;

  static Future<List<Payment>?> show(BuildContext context, num total,
      {bool scanMode = false}) {
    return showDialog<List<Payment>>(
      context: context,
      builder: (_) => QrPayDialog(total: total, scanMode: scanMode),
    );
  }

  @override
  ConsumerState<QrPayDialog> createState() => _QrPayDialogState();
}

class _QrPayDialogState extends ConsumerState<QrPayDialog> {
  static const _providers = [
    ('Click', Icons.qr_code_scanner, Color(0xFF00A6FF)),
    ('Uzum', Icons.qr_code_scanner, Color(0xFF7F4DFF)),
  ];
  int _provider = 0;

  /// Backend'ga yuboriladigan provider kodi.
  String get _providerCode => _provider == 0 ? 'click' : 'uzum';
  String get _providerName => _providers[_provider].$1;

  /// To'lov usuli — Click va Uzum alohida hisoblanadi (hisobot kesimi).
  PaymentMethod get _method =>
      _provider == 0 ? PaymentMethod.click : PaymentMethod.uzum;

  final _scan = TextEditingController();
  final _scanFocus = FocusNode();
  bool _processing = false;
  String? _error;
  String? _info;

  /// Oxirgi skaner yuborilgan payt — skanerning ortiqcha (dum) Enter'i shu
  /// oynada kelib qolsa, uni qo'lda tasdiqlash deb qabul QILMAYMIZ.
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    if (widget.scanMode) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scanFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  /// Qo'lda tasdiqlash (klaviatura, statik QR rejimi): Enter — darhol
  /// tasdiqlanadi va chek chiqadi. Bu rejimda skaner maydoni yo'q, shuning
  /// uchun tasodifiy skaner-Enter xavfi ham yo'q.
  void _manualConfirmKeyboard() {
    final now = DateTime.now();
    if (_lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return; // skanerning ortiqcha Enter'i
    }
    _finishManual();
  }

  /// Tugma bosildi (mishka/barmoq) — ataylab qilingan harakat, darhol yopiladi.
  void _finishManual() {
    Navigator.of(context).pop([
      Payment(_method, widget.total, label: '$_providerName (qo\'lda)'),
    ]);
  }

  /// Skaner mijoz QR kodini o'qidi — avtomatik yechish (Click Pass / Uzum).
  /// `paid` kelsa order AVTOMATIK yopiladi, kassir hech narsa bosmaydi.
  Future<void> _onScan(String v) async {
    final token = v.trim();
    _scan.clear();
    _scanFocus.requestFocus();
    if (token.isEmpty) {
      _manualConfirmKeyboard();
      return;
    }
    if (token.length < 4) return;
    _lastScanAt = DateTime.now();
    setState(() {
      _processing = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await ref.read(dioClientProvider).post(
        '/api/v2/pos-terminal/pay/qr',
        data: {
          'provider': _providerCode,
          'token': token,
          'amount': widget.total,
        },
      );
      final data = (res.data is Map) ? res.data as Map : const {};
      final status = (data['status'] ?? '').toString();
      if (!mounted) return;
      if (status == 'paid') {
        // Pul yechildi — order avtomatik yopiladi, fiskal chek chiqadi.
        Navigator.of(context).pop([
          Payment(_method, widget.total, label: _providerName),
        ]);
        return;
      }
      setState(() {
        _processing = false;
        if (status == 'not_configured') {
          _info = (data['message'] ?? '').toString().isNotEmpty
              ? data['message'].toString()
              : '$_providerName avto-yechish sozlanmagan. Mijoz ilovada '
                  'to\'lagach «To\'lash»ni bosing.';
        } else {
          // Click/Uzum xatosi (masalan, balansda mablag' yetarli emas) —
          // sababi bilan ko'rsatiladi, order OCHIQ qoladi.
          final msg = (data['message'] ?? '').toString();
          _error = msg.isNotEmpty
              ? msg
              : 'To\'lov amalga oshmadi — mijoz balansida mablag\' '
                  'yetarli emasligini tekshiring';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _info =
            'Serverga ulanib bo\'lmadi. Mijoz to\'lagach «To\'lash»ni bosing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        // Klaviatura: F1 — Click, F2 — Uzum, Enter — qo'lda tasdiqlash
        // (statik rejim), Esc — bekor. autofocus SHART: statik rejimda hech
        // qaysi maydon fokus olmaydi, usiz Enter/Esc umuman ushlanmaydi.
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.f1) {
              if (!_processing) setState(() => _provider = 0);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f2) {
              if (!_processing) setState(() => _provider = 1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (!_processing) Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            // Qo'lda tasdiqlash (Enter×2) — faqat statik QR rejimida.
            // Skaner rejimida (F10) bo'sh Enter hech narsa qilmaydi: to'lov
            // faqat mijoz QRi skanerlanganda o'tadi.
            if ((event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                !widget.scanMode &&
                _scan.text.trim().isEmpty) {
              if (!_processing) _manualConfirmKeyboard();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: PosColors.iconChip,
                        borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.qr_code,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        widget.scanMode
                            ? '$_providerName Pass — mijoz QRini skanerlang'
                            : '$_providerName orqali to\'lov',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0x1F2FBF71),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x332FBF71)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jami:',
                          style: TextStyle(
                              color: PosColors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(Money.formatSom(widget.total),
                          style: const TextStyle(
                              color: PosColors.green,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('To\'lov turi',
                    style: TextStyle(color: PosColors.label, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _providers.length; i++) ...[
                      Expanded(
                        child: _ProviderTile(
                          label: _providers[i].$1,
                          icon: _providers[i].$2,
                          brand: _providers[i].$3,
                          selected: _provider == i,
                          onTap: _processing
                              ? null
                              : () => setState(() => _provider = i),
                        ),
                      ),
                      if (i < _providers.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
                // Skaner maydoni — FAQAT Click Pass rejimida (F10): mijoz
                // KO'RSATGAN QR shu yerga o'qiladi va pul avtomatik yechiladi.
                if (widget.scanMode) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PosColors.field,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.blue),
                    ),
                    child: Row(children: [
                      const Icon(Icons.qr_code_scanner,
                          color: PosColors.blue, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _scan,
                          focusNode: _scanFocus,
                          enabled: !_processing,
                          onSubmitted: _onScan,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText:
                                'Mijoz $_providerName QR kodini skanerlang…',
                            hintStyle:
                                const TextStyle(color: Color(0xFF5C626A)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (_processing) ...[
                  const SizedBox(height: 14),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: PosColors.blue)),
                        SizedBox(width: 10),
                        Text('To\'lov amalga oshirilmoqda…',
                            style: TextStyle(color: Colors.white)),
                      ]),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Banner(text: _error!, color: PosColors.red),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  _Banner(text: _info!, color: const Color(0xFFF5A623)),
                ],
                if (_error == null && _info == null && !_processing) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.scanMode
                        ? 'Mijoz ilovasidagi QRni 2D skaner bilan o\'qing — '
                            'pul yechilishi bilan order O\'ZI yopiladi va '
                            'fiskal chek chiqadi · F1 Click · F2 Uzum · '
                            'Esc — bekor'
                        : 'Mijoz kassadagi $_providerName QRni ilovasida '
                            'skanerlab to\'laydi. Pul kelganini ko\'rgach — '
                            'Enter (tasdiqlash, chek chiqadi) · F1 Click · '
                            'F2 Uzum · Esc — bekor',
                    style:
                        const TextStyle(color: PosColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: _Btn(
                      label: 'Bekor',
                      filled: false,
                      onTap: _processing
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  // Qo'lda "To'lash" — faqat statik QR rejimida. Skaner
                  // rejimida to'lov faqat QR o'qilganda o'tadi.
                  if (!widget.scanMode) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _Btn(
                        label:
                            "To'lash (${Money.formatSom(widget.total)} $_providerName)",
                        icon: Icons.check_circle_outline,
                        filled: true,
                        onTap: _processing ? null : _finishManual,
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.label,
    required this.icon,
    required this.brand,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color brand;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: selected ? PosColors.blue : PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : brand, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.label,
      required this.filled,
      required this.onTap,
      this.icon});
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
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? PosColors.blue : PosColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: filled ? PosColors.blue : PosColors.cardBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
