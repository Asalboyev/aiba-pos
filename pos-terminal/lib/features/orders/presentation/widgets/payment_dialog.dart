import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/numeric_keypad.dart';
import '../../domain/entities/payment_method.dart';

class PaymentChoice {
  final PaymentMethod method;
  final num amount;
  const PaymentChoice(this.method, this.amount);
}

/// Collects a single payment for the cart total. Cash/Card/QR buttons preset
/// the amount to the total; the amount field is editable.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.total});
  final num total;

  static Future<PaymentChoice?> show(BuildContext context, num total) {
    return showDialog<PaymentChoice>(
      context: context,
      builder: (_) => PaymentDialog(total: total),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  late final TextEditingController _amount =
      TextEditingController(text: widget.total.round().toString());
  final FocusNode _amountFocus = FocusNode();

  /// Ekran klaviaturasi ko'rinadimi. Input bosilsa ochiladi (sensorli
  /// Windows kassada fizik klaviatura yo'q), yashirish tugmasi yopadi.
  bool _keypadVisible = false;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  num get _amountValue => num.tryParse(_amount.text.trim()) ?? 0;
  num get _change => _amountValue - widget.total;

  // --- Keypad handlers ---
  void _pressDigit(String d) {
    setState(() {
      final cur = _amount.text;
      if (cur == '0') {
        _amount.text = d;
      } else {
        // Juda katta summani cheklaymiz (10 raqam yetadi)
        if (cur.length >= 10) return;
        _amount.text = cur + d;
      }
    });
  }

  void _pressBackspace() {
    setState(() {
      final cur = _amount.text;
      _amount.text = cur.length <= 1 ? '0' : cur.substring(0, cur.length - 1);
    });
  }

  void _pressClear() => setState(() => _amount.text = '0');


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: screenH - 60),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'To\'lov',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              // Jami summani ta'kidlab ko'rsatamiz — bu tablet uchun katta, aniq.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jami:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      Money.formatSom(widget.total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // 3 ta payment tugmasi qatorda — SegmentedButton o'rniga o'zimizni
              // Card + InkWell bilan qilamiz, chunki SegmentedButton hover paytida
              // qora fon berib qo'yayapti (macOS'da). Bu esa selected/unselected
              // holatlarni aniq va chiroyli qiladi.
              Row(
                children: [
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.payments,
                    label: 'Naqd',
                    selected: _method == PaymentMethod.cash,
                    onTap: () => setState(() => _method = PaymentMethod.cash),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.credit_card,
                    label: 'Karta',
                    selected: _method == PaymentMethod.card,
                    onTap: () => setState(() => _method = PaymentMethod.card),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.qr_code,
                    label: 'QR',
                    selected: _method == PaymentMethod.qr,
                    onTap: () => setState(() => _method = PaymentMethod.qr),
                  )),
                ],
              ),
              const SizedBox(height: 20),
              // "Olingan summa" ko'rsatgichi.
              // Desktop'da: oddiy TextField — fizik klaviatura ishlaydi.
              // Tablet'da: readOnly, bosilganda ostida keypad ochiladi.
              TextField(
                controller: _amount,
                focusNode: _amountFocus,
                showCursor: true,
                onTap: () => setState(() => _keypadVisible = true),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.end,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Olingan summa',
                  labelStyle: const TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixText: "so'm",
                  suffixStyle: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              // Input bosilsa ekran klaviaturasi ochiladi (sensorli kassa);
              // yashirish tugmasi bilan yopiladi. Fizik klaviatura ham ishlaydi.
              if (_keypadVisible) ...[
                const SizedBox(height: 6),
                NumericKeypad(
                  onDigit: _pressDigit,
                  onBackspace: _pressBackspace,
                  onClear: _pressClear,
                  onHide: () => setState(() => _keypadVisible = false),
                ),
              ],
              if (_method == PaymentMethod.cash && _change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Qaytim:',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          Money.formatSom(_change),
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Bekor',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _amountValue < widget.total
                            ? null
                            : () => Navigator.of(context).pop(
                                  PaymentChoice(_method, widget.total),
                                ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          "To'lash",
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

/// Payment method tanlash kartochkasi — Naqd/Karta/QR uchun mos.
/// selected=true bo'lganda yashil to'ldirilgan, aks holda och kulrang ramka.
/// Bosilganda scale + splash animatsiya bilan zamonaviy hislar.
class _PaymentMethodTile extends StatefulWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PaymentMethodTile> createState() => _PaymentMethodTileState();
}

class _PaymentMethodTileState extends State<_PaymentMethodTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = widget.selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final fg = widget.selected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final borderColor = widget.selected
        ? theme.colorScheme.primary
        : theme.dividerColor;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.96 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          elevation: widget.selected ? 2 : 0,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(12),
            hoverColor: widget.selected
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.06),
            splashColor: widget.selected
                ? Colors.white.withValues(alpha: 0.2)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
            highlightColor: widget.selected
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get icon => widget.icon;
}
