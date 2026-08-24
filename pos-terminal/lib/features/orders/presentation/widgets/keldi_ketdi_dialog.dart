import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/pos_chrome.dart';

/// "Keldi - ketdi" tasdiq kodi (OTP) oynasi — Figma dark dizayn.
///
/// Oyna ochilishi bilan backend managerning Telegramiga bir martalik kod
/// yuboradi. Manager kodni kassirga aytadi — kassir shu kodni kiritadi.
/// Kod faqat managerda bo'lgani uchun soxta davomatning oldi olinadi.
class KeldiKetdiDialog extends ConsumerStatefulWidget {
  const KeldiKetdiDialog({super.key, this.amount});

  /// Comp qilinayotgan chek summasi — manager Telegramda ko'radi (nazorat).
  final num? amount;

  static Future<bool?> show(BuildContext context, {num? amount}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => KeldiKetdiDialog(amount: amount),
    );
  }

  @override
  ConsumerState<KeldiKetdiDialog> createState() => _KeldiKetdiDialogState();
}

class _KeldiKetdiDialogState extends ConsumerState<KeldiKetdiDialog> {
  static const _len = 4;
  String _code = '';
  bool _sending = false; // kod yuborilmoqda
  bool _verifying = false; // kod tekshirilmoqda
  String _status = ''; // 'sent' | 'not_configured' | 'error' | ''
  String _message = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _request());
  }

  Future<void> _request() async {
    setState(() {
      _sending = true;
      _code = '';
      _message = '';
    });
    try {
      final res = await ref.read(dioClientProvider).post(
        '/api/v2/pos-terminal/keldi-ketdi/request',
        data: {'direction': 'in', 'amount': widget.amount ?? 0},
      );
      final data = (res.data is Map) ? res.data as Map : const {};
      final status = (data['status'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = status == 'sent' ? 'sent' : status;
        _message = (data['message'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = 'error';
        _message = 'Serverga ulanib bo\'lmadi';
      });
    }
  }

  Future<void> _verify() async {
    if (_code.length < _len || _verifying) return;
    setState(() => _verifying = true);
    try {
      final res = await ref.read(dioClientProvider).post(
        '/api/v2/pos-terminal/keldi-ketdi/verify',
        data: {'code': _code, 'direction': 'in'},
      );
      final data = (res.data is Map) ? res.data as Map : const {};
      if (!mounted) return;
      if ((data['status'] ?? '').toString() == 'ok') {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verifying = false;
          _code = '';
          _message = (data['message'] ?? 'Kod noto\'g\'ri').toString();
          _status = 'invalid';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _message = 'Serverga ulanib bo\'lmadi';
        _status = 'error';
      });
    }
  }

  void _digit(String d) {
    if (_code.length >= _len) return;
    setState(() => _code += d);
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }


  @override
  Widget build(BuildContext context) {
    final complete = _code.length == _len;
    final configured = _status == 'sent' || _status == 'invalid';
    final subtitle = switch (_status) {
      'sent' => 'Managerning Telegramiga kod muvaffaqiyatli yuborildi, '
          'shu kodni kiriting!',
      'not_configured' => _message.isNotEmpty
          ? _message
          : 'Manager Telegrami sozlanmagan. Admin panel → POS → filial '
              'sozlamalarida sozlang.',
      'error' => _message.isNotEmpty ? _message : 'Kod yuborilmadi',
      'invalid' => _message.isNotEmpty ? _message : 'Kod noto\'g\'ri',
      _ => 'Kod yuborilmoqda…',
    };
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        // Fizik klaviatura: raqamlar teriladi, Backspace o'chiradi,
        // Enter — kod to'liq bo'lsa tasdiqlaydi.
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final ch = event.character;
            if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
              _digit(ch);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _backspace();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              if (complete && configured && !_verifying) _verify();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(children: [
                  SvgPicture.asset('assets/icons/pay_users.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn)),
                  const SizedBox(width: 12),
                  const Text('Keldi - ketdi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const Divider(height: 1, color: PosColors.cardBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  children: [
                    Text(
                      _status == 'sent'
                          ? 'Kod yuborildi!'
                          : (_sending ? 'Kod yuborilmoqda…' : 'Keldi - ketdi'),
                      style: TextStyle(
                          color: _status == 'not_configured' ||
                                  _status == 'error' ||
                                  _status == 'invalid'
                              ? PosColors.red
                              : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: PosColors.muted, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    const Text('Kodni kiriting',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_len, (i) {
                        final filled = i < _code.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: filled ? 14 : 22,
                          height: filled ? 14 : 3,
                          decoration: BoxDecoration(
                            color: filled
                                ? Colors.white
                                : const Color(0xFF3A3A40),
                            borderRadius:
                                BorderRadius.circular(filled ? 7 : 2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _sending ? null : _request,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: PosColors.muted))
                          : const Icon(Icons.refresh,
                              color: PosColors.muted, size: 18),
                      label: const Text('Qaytadan yuborish',
                          style: TextStyle(color: PosColors.muted)),
                    ),
                    const SizedBox(height: 8),
                    // Fizik klaviatura: raqam tering, Enter — tasdiqlash.
                    const Text(
                        'Kodni klaviaturada tering · Enter — tasdiqlash',
                        style:
                            TextStyle(color: Color(0xFF5C626A), fontSize: 12)),
                  ],
                ),
              ),
              const Divider(height: 1, color: PosColors.cardBorder),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: _Btn(
                      label: 'Bekor qilish',
                      icon: Icons.close,
                      filled: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Btn(
                      label: 'Tasdiqlash',
                      icon: Icons.check,
                      filled: true,
                      busy: _verifying,
                      onTap: (complete && configured && !_verifying)
                          ? _verify
                          : null,
                    ),
                  ),
                ]),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.label,
      required this.icon,
      required this.filled,
      required this.onTap,
      this.busy = false});
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  final bool busy;
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
            border:
                Border.all(color: filled ? PosColors.blue : PosColors.cardBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
            else
              Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
