import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';

/// F12 — bugungi FISKAL QILINMAGAN naqd cheklar ro'yxati.
/// Kassir strelka bilan tanlab Enter bosadi (yoki sichqoncha) —
/// [onFiscalize] chaqiriladi (server fiscalize + QR bilan chop etish).
/// Muvaffaqiyatli bo'lsa qator ro'yxatdan O'CHADI. Esc — yopish.
class UnfiscalizedDialog extends StatefulWidget {
  const UnfiscalizedDialog({
    super.key,
    required this.orders,
    required this.onFiscalize,
  });

  /// Serverdan kelgan ro'yxat: {id, number, total, created_at}.
  final List<Map<String, dynamic>> orders;

  /// true qaytarsa — fiskal + chop muvaffaqiyatli, qator olib tashlanadi.
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
      if (ok) {
        _rows.removeAt(i);
        if (_selected >= _rows.length) _selected = _rows.length - 1;
        if (_selected < 0) _selected = 0;
      }
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Fiskal chek (F12)',
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
                  'Bugungi fiskal qilinmagan naqd cheklar. Tanlang — soliqqa '
                  'yuborilib QR bilan chiqadi.',
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
                    child: const Text('Fiskal kutayotgan naqd chek yo\'q',
                        style: TextStyle(color: PosColors.muted)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _rows.length,
                      separatorBuilder: (a, b) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = _rows[i];
                        final sel = i == _selected;
                        final busy = _busyId == o['id'];
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
                                const SizedBox(width: 12),
                                Text(_time(o['created_at'] as String?),
                                    style: const TextStyle(
                                        color: PosColors.muted, fontSize: 13)),
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
                const Text('↑↓ tanlash · Enter — fiskal + chek · Esc — yopish',
                    style: TextStyle(color: PosColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
