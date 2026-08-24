import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/pos_chrome.dart';

/// "Xato urilgan chek" — chekni xato deb belgilash (o'chirilmaydi, oy oxirida
/// tekshiruvchi ko'rib to'g'irlaydi). Figma dark dizayn.
class ErrorCheckResult {
  const ErrorCheckResult(this.reason, this.note);
  final String reason;
  final String note;
}

class ErrorCheckDialog extends StatefulWidget {
  const ErrorCheckDialog({super.key});

  static Future<ErrorCheckResult?> show(BuildContext context) {
    return showDialog<ErrorCheckResult>(
      context: context,
      builder: (_) => const ErrorCheckDialog(),
    );
  }

  @override
  State<ErrorCheckDialog> createState() => _ErrorCheckDialogState();
}

class _ErrorCheckDialogState extends State<ErrorCheckDialog> {
  static const _reasons = [
    'Boshqa taom urildi',
    'Miqdori ko\'p urildi',
    'Miqdori kam urildi',
    'Narxi noto\'g\'ri',
    'Mijoz fikridan qaytdi',
    'Ikki marta urildi',
  ];
  int _selected = 0;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context)
      .pop(ErrorCheckResult(_reasons[_selected], _note.text.trim()));

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: screenH - 60),
        // To'liq klaviatura: 1–6 sabab · ↑↓ tanlash · Tab/I izoh · Enter
        // tasdiqlash · Esc bekor. Mishka umuman kerak emas.
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final k = event.logicalKey;
            // Esc — bekor qilish (har qanday holatda).
            if (k == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            // Enter — tasdiqlash (izoh maydonida ham ishlaydi).
            if (k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter) {
              _confirm();
              return KeyEventResult.handled;
            }
            // Izoh maydoni fokusда bo'lsa — matn terishga xalaqit bermaymiz.
            if (_noteFocus.hasFocus) return KeyEventResult.ignored;
            // Tab yoki I — izoh maydoniga o'tish.
            if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.keyI) {
              _noteFocus.requestFocus();
              return KeyEventResult.handled;
            }
            // ↑ / ↓ — sabablar bo'ylab yurish.
            if (k == LogicalKeyboardKey.arrowDown) {
              setState(() => _selected = (_selected + 1) % _reasons.length);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.arrowUp) {
              setState(() => _selected =
                  (_selected - 1 + _reasons.length) % _reasons.length);
              return KeyEventResult.handled;
            }
            final ch = event.character;
            if (ch != null && RegExp(r'^[1-6]$').hasMatch(ch)) {
              final i = int.parse(ch) - 1;
              if (i < _reasons.length) setState(() => _selected = i);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Xato urilgan chek',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const Divider(height: 1, color: PosColors.cardBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check o\'chirilmaydi - belgilanadi va oy oxirida '
                      'tekshiruvchi ko\'rib to\'g\'irlaydi.',
                      style: TextStyle(color: PosColors.muted, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: PosColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: PosColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _reasons.length; i++)
                            _ReasonRow(
                              label: '${i + 1}.  ${_reasons[i]}',
                              selected: _selected == i,
                              first: i == 0,
                              last: i == _reasons.length - 1,
                              onTap: () => setState(() => _selected = i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Sabab',
                        style: TextStyle(color: PosColors.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      focusNode: _noteFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _confirm(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: PosColors.field,
                        hintText: 'Izoh yozish',
                        hintStyle: const TextStyle(color: Color(0xFF5C626A)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PosColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PosColors.blue, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: PosColors.cardBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: _Btn(
                    label: 'Esc · Bekor',
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _Btn(
                    label: 'Enter · Tasdiqlash',
                    filled: true,
                    onTap: _confirm,
                  ),
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '1–6 yoki ↑↓ — sababni tanlash · Tab/I — izoh yozish · '
                'Enter — Tasdiqlash · Esc — bekor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5C626A), fontSize: 12),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(14) : Radius.zero,
        bottom: last ? const Radius.circular(14) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x22F5A623) : Colors.transparent,
          border: Border(
            bottom: last
                ? BorderSide.none
                : const BorderSide(color: PosColors.cardBorder),
          ),
        ),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF5A623) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: selected ? const Color(0xFFF5A623) : PosColors.muted,
                  width: 1.6),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
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
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
