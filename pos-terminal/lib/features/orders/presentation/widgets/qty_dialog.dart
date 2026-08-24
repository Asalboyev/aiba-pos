import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';

/// Miqdor kiritish oynasi (dark UI) — birlikka qarab ikki rejim:
///   * [weight] = true  (kg): gramm kiritiladi, narx 1 kg uchun. 400 → 0.4 kg.
///   * [weight] = false (dona): butun son.
class QtyDialog extends StatefulWidget {
  const QtyDialog({
    super.key,
    required this.name,
    required this.price,
    required this.weight,
    this.current,
  });

  final String name;
  final num price;
  final bool weight;
  final num? current;

  static Future<num?> show(
    BuildContext context, {
    required String name,
    required num price,
    required bool weight,
    num? current,
  }) =>
      showDialog<num>(
        context: context,
        builder: (context) => QtyDialog(
          name: name,
          price: price,
          weight: weight,
          current: current,
        ),
      );

  @override
  State<QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<QtyDialog> {
  // Fizik klaviatura: miqdor to'g'ridan-to'g'ri teriladi, Enter — tasdiqlash.
  late final TextEditingController _c = TextEditingController();
  String get _text => _c.text;

  @override
  void initState() {
    super.initState();
    final cur = widget.current;
    if (cur != null && cur > 0) {
      _c.text = widget.weight
          ? (cur * 1000).round().toString()
          : cur.round().toString();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? _raw() {
    final v = int.tryParse(_text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  void _submit() {
    final v = _raw();
    if (v == null) return;
    Navigator.of(context).pop(widget.weight ? v / 1000 : v);
  }

  void _setGrams(int grams) => setState(() => _c.text = grams.toString());

  @override
  Widget build(BuildContext context) {
    final v = _raw();
    final sum = v == null
        ? null
        : (widget.weight ? widget.price * v / 1000 : widget.price * v);

    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        onKeyEvent: (n, e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child:  ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
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
                  child: Icon(widget.weight ? Icons.scale : Icons.tag,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 18),
              Text(widget.weight ? 'Miqdorni kiriting' : 'Dona',
                  style: const TextStyle(color: PosColors.label, fontSize: 13)),
              const SizedBox(height: 8),
              // Fizik klaviatura: autofocus, Enter — tasdiqlash.
              TextField(
                controller: _c,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: PosColors.field,
                  suffixText: widget.weight ? 'g' : 'dona',
                  suffixStyle:
                      const TextStyle(color: PosColors.muted, fontSize: 15),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PosColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: PosColors.blue, width: 1.5),
                  ),
                ),
              ),
              if (widget.weight) ...[
                const SizedBox(height: 12),
                Row(children: [
                  for (final g in const [100, 500, 1000]) ...[
                    Expanded(
                      child: _QuickBtn(
                        label: g == 1000 ? '1 kg' : '$g gr',
                        onTap: () => _setGrams(g),
                      ),
                    ),
                    if (g != 1000) const SizedBox(width: 10),
                  ],
                ]),
                const SizedBox(height: 12),
                Center(
                  child: Text('1 kg = ${Money.formatSom(widget.price)}',
                      style: const TextStyle(color: PosColors.muted, fontSize: 14)),
                ),
              ],
              if (sum != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x1F2FBF71),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x332FBF71)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Summa :',
                          style: TextStyle(
                              color: PosColors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(Money.formatSom(sum),
                          style: const TextStyle(
                              color: PosColors.green,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _DialogBtn(
                    label: 'Bekor',
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _DialogBtn(
                    label: 'Tasdiqlash',
                    icon: Icons.check,
                    filled: true,
                    onTap: v == null ? null : _submit,
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

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn(
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
            border: Border.all(
                color: filled ? PosColors.blue : PosColors.cardBorder),
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
