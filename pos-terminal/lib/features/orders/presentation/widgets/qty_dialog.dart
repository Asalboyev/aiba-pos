import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/numeric_keypad.dart';

/// Miqdor kiritish oynasi — mahsulot birligiga qarab ikki rejim:
///   * [weight] = true  (birlik "kg"): gramm kiritiladi, narx 1 kg uchun.
///     400 → 0.4 kg qaytadi, summa oldindan ko'rinadi.
///   * [weight] = false (dona): faqat butun son kiritiladi.
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

  /// Joriy miqdor (savatdagi qatorni tahrirlashda oldindan to'ldiriladi).
  final num? current;

  /// Qaytadi: kg rejimda kg (0.4), dona rejimda butun son. Bekor — null.
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
  late final TextEditingController _controller;

  /// Ekran klaviaturasi — sensorli kassada input bosilganda ochiladi,
  /// tarozi oynasida esa darhol ochiq turadi (kassir tez ishlashi uchun).
  late bool _keypadVisible = widget.weight;

  @override
  void initState() {
    super.initState();
    var initial = '';
    final cur = widget.current;
    if (cur != null && cur > 0) {
      initial = widget.weight
          ? (cur * 1000).round().toString() // kg → gramm
          : cur.round().toString();
    }
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _raw() {
    final v = int.tryParse(_controller.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  void _submit() {
    final v = _raw();
    if (v == null) return;
    Navigator.of(context).pop(widget.weight ? v / 1000 : v);
  }

  void _setGrams(int grams) => setState(() {
        _controller.text = grams.toString();
      });

  void _pressDigit(String d) => setState(() {
        if (_controller.text.length >= 7) return;
        _controller.text += d;
      });

  void _pressBackspace() => setState(() {
        final t = _controller.text;
        _controller.text = t.isEmpty ? '' : t.substring(0, t.length - 1);
      });

  void _pressClear() => setState(() => _controller.text = '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _raw();
    final sum = v == null
        ? null
        : (widget.weight ? widget.price * v / 1000 : widget.price * v);
    return AlertDialog(
      title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: widget.weight ? 'Gramm' : 'Dona',
                  hintText: widget.weight ? 'masalan: 400' : 'masalan: 2',
                  suffixText: widget.weight ? 'gr' : 'dona',
                  border: const OutlineInputBorder(),
                ),
                onTap: () => setState(() => _keypadVisible = true),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              // Tez tanlash: eng ko'p so'raladigan vaznlar bir bosishda.
              if (widget.weight) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final g in const [100, 500, 1000]) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _setGrams(g),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            g == 1000 ? '1 kg' : '$g gr',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (g != 1000) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 10),
              if (widget.weight)
                Text(
                  '1 kg = ${Money.formatSom(widget.price)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              if (sum != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Summa: ${Money.formatSom(sum)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
              // Ekran klaviaturasi — sensorli kassa uchun.
              if (_keypadVisible) ...[
                const SizedBox(height: 8),
                NumericKeypad(
                  onDigit: _pressDigit,
                  onBackspace: _pressBackspace,
                  onClear: _pressClear,
                  onHide: () => setState(() => _keypadVisible = false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor'),
        ),
        FilledButton.icon(
          onPressed: v == null ? null : _submit,
          icon: Icon(widget.weight ? Icons.scale : Icons.check),
          label: const Text('OK'),
        ),
      ],
    );
  }
}
