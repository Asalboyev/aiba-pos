import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';

/// F12 — BUGUNGI CHEKLAR TARIXI. Mijoz keyinroq "chek bering" deb kelsa
/// kassir shu ro'yxatdan topib qayta chop etadi:
///  - fiskal QILINMAGAN (naqd) chek → tanlansa soliqqa yuborilib QR bilan
///    chiqadi va belgisi ✓ ga o'zgaradi;
///  - fiskal BOR chek → shunchaki QR bilan QAYTA chop etiladi.
/// ↑↓ tanlash, Enter — chop etish, Esc — yopish.
class UnfiscalizedDialog extends StatefulWidget {
  const UnfiscalizedDialog({
    super.key,
    required this.orders,
    required this.onFiscalize,
  });

  /// Serverdan kelgan ro'yxat: {id, number, total, created_at, fiscal, methods}.
  final List<Map<String, dynamic>> orders;

  /// true qaytarsa — fiskal + chop muvaffaqiyatli.
  final Future<bool> Function(Map<String, dynamic> order) onFiscalize;

  @override
  State<UnfiscalizedDialog> createState() => _UnfiscalizedDialogState();
}

class _UnfiscalizedDialogState extends State<UnfiscalizedDialog> {
  late List<Map<String, dynamic>> _rows;
  int _selected = 0;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.orders);
  }

  Future<void> _pick(int i) async {
    if (_busyId != null || i < 0 || i >= _rows.length) return;
    final order = _rows[i];
    setState(() => _busyId = order['id'] as String?);
    final ok = await widget.onFiscalize(order);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      // Tarix saqlanadi — qator O'CHMAYDI, faqat fiskal belgisi yangilanadi
      // (yana kerak bo'lsa qayta chop etsa bo'ladi).
      if (ok) _rows[i] = {...order, 'fiscal': true};
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_rows.isEmpty) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1) % _rows.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1 + _rows.length) % _rows.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _pick(_selected);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _time(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  /// To'lov turi qisqa yorlig'i: cash → Naqd, card → Karta ...
  String _methods(Map<String, dynamic> o) {
    final m = (o['methods'] ?? '').toString();
    if (m.isEmpty) return '';
    const names = {
      'cash': 'Naqd',
      'card': 'Karta',
      'click': 'Click',
      'qr': 'Click',
      'uzum': 'Uzum',
      'keldi_ketdi': 'Keldi-ketdi',
    };
    return m.split(',').map((x) => names[x.trim()] ?? x).toSet().join('+');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Cheklar tarixi (F12)',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: PosColors.muted),
                    ),
                  ],
                ),
                const Text(
                  'Bugungi to\'langan cheklar. Tanlang — QR bilan chop etiladi '
                  '(fiskal bo\'lmagani avval soliqqa yuboriladi).',
                  style: TextStyle(color: PosColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (_rows.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PosColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Bugun chek urilmagan',
                        style: TextStyle(color: PosColors.muted)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _rows.length,
                      separatorBuilder: (a, b) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final o = _rows[i];
                        final sel = i == _selected;
                        final busy = _busyId == o['id'];
                        final fiscal = o['fiscal'] == true;
                        return InkWell(
                          onTap: () {
                            setState(() => _selected = i);
                            _pick(i);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? PosColors.blue.withValues(alpha: 0.18)
                                  : PosColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel
                                      ? PosColors.blue
                                      : PosColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Text('№${o['number'] ?? ''}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 10),
                                Text(
                                    '${_time(o['created_at'] as String?)} · ${_methods(o)}',
                                    style: const TextStyle(
                                        color: PosColors.muted, fontSize: 13)),
                                const SizedBox(width: 8),
                                // Fiskal holati: ✓ QR bor / QRsiz (naqd).
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: fiscal
                                        ? PosColors.green.withValues(alpha: 0.15)
                                        : const Color(0x33F5A623),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(fiscal ? 'QR ✓' : 'QRsiz',
                                      style: TextStyle(
                                          color: fiscal
                                              ? PosColors.green
                                              : const Color(0xFFF5A623),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const Spacer(),
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: PosColors.blue),
                                  )
                                else
                                  Text(
                                    Money.formatSom(
                                        num.tryParse('${o['total']}') ?? 0),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('↑↓ tanlash · Enter — chek chiqarish · Esc — yopish',
                    style: TextStyle(color: PosColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
