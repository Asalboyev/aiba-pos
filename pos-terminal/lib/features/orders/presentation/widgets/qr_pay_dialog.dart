import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../../printing/presentation/printing_providers.dart';
import '../../domain/entities/payment_method.dart';

/// QR to'lov oynasi — Payme / Click / QR.
///
/// 2-usul (avto-yechish): kassir mijoz kodini 2D skaner bilan o'qiydi →
/// backend `/pay/qr` merchant shlyuzi orqali pulni yechadi → muvaffaqiyatli
/// bo'lsa oyna avtomatik yopiladi va chek yopiladi.
/// Shlyuz sozlanmagan bo'lsa (kalitlar yo'q) — 1-usulga tushadi: kassir mijoz
/// ilovada to'lagach «To'lash»ni qo'lda bosadi.
class QrPayDialog extends ConsumerStatefulWidget {
  const QrPayDialog({super.key, required this.total, this.onPrintPaymentSlip});
  final num total;

  /// "To'lash" bosilganda 1-chekni (mahsulotlar + TO'LOV KODI QR) chop etish.
  /// Savat ma'lumoti savdo ekranida bo'lgani uchun chop etish shu yerga
  /// topshiriladi. null bo'lsa — chek chiqmaydi (WLCM sozlanmagan).
  final Future<void> Function(String checkoutUrl)? onPrintPaymentSlip;

  static Future<List<Payment>?> show(
    BuildContext context,
    num total, {
    Future<void> Function(String checkoutUrl)? onPrintPaymentSlip,
  }) {
    return showDialog<List<Payment>>(
      context: context,
      builder: (_) => QrPayDialog(
        total: total,
        onPrintPaymentSlip: onPrintPaymentSlip,
      ),
    );
  }

  @override
  ConsumerState<QrPayDialog> createState() => _QrPayDialogState();
}

class _QrPayDialogState extends ConsumerState<QrPayDialog> {
  // Payme va Click bitta bo'ldi — skaner kodni o'qiydi, shlyuz Payme/Click'ni
  // avtomatik aniqlab pulni yechadi va chekni yopadi.
  static const _providers = [
    ('Payme / Click', Icons.account_balance_wallet_outlined, Color(0xFF33CCCC)),
    ('QR', Icons.qr_code, PosColors.muted),
  ];
  int _provider = 0;

  /// Backend/shlyuzga yuboriladigan provider kodi.
  String get _providerCode => _provider == 0 ? 'payme_click' : 'qr';

  /// "QR" tabi tanlanganmi — QR kod va TO'LOV KODI cheki faqat shunda.
  bool get _isQrTab => _provider == 1;

  final _scan = TextEditingController();
  final _scanFocus = FocusNode();
  bool _processing = false;
  String? _error;
  String? _info;

  // WLCM shlyuzi: checkout QR + holat polling'i.
  String? _checkoutUrl;
  String? _externalId;
  Timer? _poll;
  bool _slipPrinted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scanFocus.requestFocus());
    _startWlcm();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scan.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  /// WLCM checkout yaratamiz: muvaffaqiyatli bo'lsa QR ekranda ko'rinadi,
  /// talon bosiladi va to'lov holati har 2 soniyada tekshiriladi.
  /// Sozlanmagan bo'lsa — eski (skaner/qo'lda) oqim o'zgarishsiz qoladi.
  Future<void> _startWlcm() async {
    final ext = const Uuid().v4();
    try {
      final res = await ref.read(dioClientProvider).post(
        '/api/v2/pos-terminal/wlcm/checkout',
        data: {'external_id': ext, 'amount': widget.total},
      );
      final data = (res.data is Map) ? res.data as Map : const {};
      if (!mounted) return;
      if ((data['status'] ?? '') == 'created' &&
          (data['checkout_url'] ?? '').toString().isNotEmpty) {
        setState(() {
          _checkoutUrl = data['checkout_url'].toString();
          _externalId = ext;
        });
        // Chek "To'lash" bosilganda chiqadi (avtomatik emas) — kassir
        // tayyor bo'lganda beradi.
        _poll = Timer.periodic(
            const Duration(seconds: 2), (_) => _checkWlcm());
      }
      // not_configured — jim: eski oqim ishlayveradi.
    } catch (_) {
      // Server/tarmoq xatosi — eski oqim qoladi.
    }
  }

  /// 1-chek: mahsulotlar + TO'LOV KODI QR (fiskal emas). "To'lash" bosilganда
  /// chiqadi; keyin dialog mijozning to'lovini kutadi.
  Future<void> _printSlip() async {
    final url = _checkoutUrl;
    if (_slipPrinted || url == null) return;
    setState(() => _slipPrinted = true);
    try {
      final cb = widget.onPrintPaymentSlip;
      if (cb != null) {
        await cb(url);
      } else {
        // Zaxira: savat ma'lumoti bo'lmasa — qisqa talon.
        await ref
            .read(printerServiceProvider)
            .printQrSlip(url: url, amount: widget.total);
      }
    } catch (_) {/* printersiz ham davom etamiz */}
  }

  Future<void> _checkWlcm() async {
    final ext = _externalId;
    if (ext == null || !mounted) return;
    try {
      final res = await ref.read(dioClientProvider).get(
        '/api/v2/pos-terminal/wlcm/status',
        query: {'external_id': ext},
      );
      final data = (res.data is Map) ? res.data as Map : const {};
      final st = (data['state'] as num?)?.toInt() ?? 1;
      if (!mounted) return;
      if (st == 2) {
        _poll?.cancel();
        // To'landi — chek avtomatik yopiladi, fiskal chek (2-chek) chiqadi.
        Navigator.of(context).pop(
            [Payment(PaymentMethod.qr, widget.total, label: 'QR (WLCM)')]);
      } else if (st == -2) {
        _poll?.cancel();
        setState(() => _error = 'To\'lov bekor qilindi');
      }
    } catch (_) {/* keyingi poll'da urinamiz */}
  }

  String get _providerName => _providers[_provider].$1;

  void _completeManual() {
    Navigator.of(context)
        .pop([Payment(PaymentMethod.qr, widget.total, label: _providerName)]);
  }

  /// "To'lash" bosilganда:
  ///  • WLCM QR tayyor va chek hali chiqmagan → 1-chekni chiqaradi va mijoz
  ///    to'lashini kutadi (dialog yopilmaydi, to'lov o'tishi bilan o'zi yopiladi);
  ///  • chek allaqachon chiqqan yoki WLCM yo'q → qo'lda tasdiqlaydi.
  Future<void> _onPayPressed() async {
    // QR tabida: 1-chek (TO'LOV KODI) chiqadi va mijozning to'lovi kutiladi.
    if (_isQrTab && _checkoutUrl != null && !_slipPrinted) {
      await _printSlip();
      return;
    }
    // Payme/Click tabi yoki chek allaqachon chiqqan — qo'lda tasdiqlash.
    _completeManual();
  }

  /// Skaner kodni o'qiganda — avtomatik yechishga urinamiz (2-usul).
  /// Bo'sh holatda Enter — qo'lda «To'lash» (mijoz ilovada to'lagan).
  Future<void> _onScan(String v) async {
    final token = v.trim();
    _scan.clear();
    if (token.isEmpty) {
      // Bo'sh Enter = "To'lash" tugmasi: 1-chek chiqadi, keyingi Enter —
      // qo'lda tasdiqlash (kassir mishka ishlatmaydi).
      await _onPayPressed();
      return;
    }
    if (token.length < 4) return;
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
        // Pul yechildi — chekni avtomatik yopamiz.
        Navigator.of(context).pop(
            [Payment(PaymentMethod.qr, widget.total, label: _providerName)]);
        return;
      }
      setState(() {
        _processing = false;
        if (status == 'not_configured') {
          _info = (data['message'] ?? '').toString().isNotEmpty
              ? data['message'].toString()
              : 'Avto-yechish sozlanmagan. Mijoz ilovada to\'lagach «To\'lash»ni bosing.';
        } else {
          _error = (data['message'] ?? 'To\'lov amalga oshmadi').toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _info = 'Serverga ulanib bo\'lmadi. Mijoz to\'lagach «To\'lash»ni bosing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _providerName;
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        // Klaviatura: F1 — Payme/Click, F2 — QR, Enter — To'lash, Esc — bekor.
        child: Focus(
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
            // Esc — bekor qilish (mishkasiz).
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (!_processing) Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            // Enter — "To'lash": skaner maydoni bo'sh bo'lsa chekni chiqaradi,
            // ikkinchi Enter qo'lda tasdiqlaydi. (Maydonда matn bo'lsa —
            // TextField o'zi onSubmitted bilan ishlaydi.)
            if ((event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                _scan.text.trim().isEmpty) {
              if (!_processing) _onPayPressed();
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
                  child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$name orqali to\'lov',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              // WLCM QR — FAQAT "QR" tabida (Payme/Click tabida mijoz kodini
              // skanerlaymiz, QR ko'rsatilmaydi).
              if (_isQrTab && _checkoutUrl != null) ...[
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _checkoutUrl!,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_slipPrinted)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: PosColors.green)),
                    SizedBox(width: 10),
                    Text('Chek chiqarildi — mijoz to\'lashi kutilmoqda',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ])
                else
                  const Center(
                    child: Text('«To\'lash» — TO\'LOV KODI cheki chiqadi',
                        style: TextStyle(color: PosColors.muted, fontSize: 12.5)),
                  ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                      'To\'lov o\'tishi bilan fiskal chek avtomatik chiqadi',
                      style: TextStyle(color: PosColors.muted, fontSize: 12)),
                ),
              ],
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
              const SizedBox(height: 18),
              // Skaner maydoni — 2D skaner kodni yozadi → avto-yechish.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PosColors.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PosColors.cardBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_scanner,
                      color: PosColors.muted, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _scan,
                      focusNode: _scanFocus,
                      enabled: !_processing,
                      onSubmitted: _onScan,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Mijoz Payme/Click kodini skanerlang…',
                        hintStyle: TextStyle(color: Color(0xFF5C626A)),
                      ),
                    ),
                  ),
                ]),
              ),
              if (_processing) ...[
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
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
                const Text(
                  'Enter — To\'lash (chek chiqadi) · yana Enter — qo\'lda '
                  'tasdiqlash · skanerlang — pul avtomatik yechiladi · '
                  'F1/F2 — to\'lov turi · Esc — bekor',
                  style: TextStyle(color: PosColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: _Btn(
                    label: 'Bekor',
                    filled: false,
                    onTap: _processing ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _Btn(
                    label: _isQrTab && _checkoutUrl != null && !_slipPrinted
                        ? "To'lash — TO'LOV KODI cheki chiqadi"
                        : _slipPrinted
                            ? "Qo'lda tasdiqlash"
                            : "To'lash (${Money.formatSom(widget.total)} $name)",
                    icon: Icons.check_circle_outline,
                    filled: true,
                    onTap: _processing ? null : _onPayPressed,
                  ),
                ),
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
          border:
              Border.all(color: selected ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : brand, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
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
          height: 54,
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
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
