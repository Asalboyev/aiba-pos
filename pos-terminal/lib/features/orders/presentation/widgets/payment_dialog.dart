import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/numeric_keypad.dart';
import '../../domain/entities/payment_method.dart';

/// Bitta chekni bir yoki bir nechta to'lov usuli bilan yopish oynasi.
///
/// Oddiy holat: usul tanlab darrov «To'lash» — bitta to'lov qaytadi.
/// Bo'lib to'lash: kiritilgan summa qolgan summadan kam bo'lsa «Bo'lib to'lash»
/// tugmasi orqali qism ro'yxatga tushadi, usul avtomatik keyingi bo'sh usulga
/// o'tadi. Har usul bir chekda faqat bir marta. Yakuniy tugma qolgan summani
/// tanlangan usul bilan yopadi. Natija — [Payment] ro'yxati.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.total});
  final num total;

  static Future<List<Payment>?> show(BuildContext context, num total) {
    return showDialog<List<Payment>>(
      context: context,
      builder: (_) => PaymentDialog(total: total),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  /// Qo'shilgan qismlar (bo'lib to'lashda).
  final List<Payment> _parts = [];

  PaymentMethod _method = PaymentMethod.cash;
  late final TextEditingController _amount =
      TextEditingController(text: widget.total.round().toString());
  final FocusNode _amountFocus = FocusNode();

  bool _keypadVisible = false;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  // --- Hisob-kitob ---
  num get _paid => _parts.fold<num>(0, (s, p) => s + p.amount);
  num get _remaining => widget.total - _paid;
  num get _amountValue => num.tryParse(_amount.text.trim()) ?? 0;

  /// Qaytim faqat naqdda va faqat qolgan summaga nisbatan.
  num get _change =>
      _method == PaymentMethod.cash ? _amountValue - _remaining : 0;

  bool _used(PaymentMethod m) => _parts.any((p) => p.method == m);

  /// Yana bo'lib bo'ladimi — oxirgi bo'sh usul to'liq qolganini yopishi kerak,
  /// shuning uchun qismlar soni (usullar − 1) dan kam bo'lsagina.
  bool get _canSplitMore => _parts.length < PaymentMethod.values.length - 1;

  PaymentMethod? get _nextFree {
    for (final m in PaymentMethod.values) {
      if (!_used(m)) return m;
    }
    return null;
  }

  void _setAmountToRemaining() =>
      _amount.text = _remaining.round().toString();

  void _selectMethod(PaymentMethod m) {
    if (_used(m)) return; // ishlatilgan usul bosilmaydi
    setState(() {
      _method = m;
      _setAmountToRemaining();
    });
  }

  /// Kiritilgan summani qism sifatida ro'yxatga qo'shadi.
  void _addPart() {
    final amount = _amountValue;
    if (amount <= 0 || amount >= _remaining || !_canSplitMore || _used(_method)) {
      return;
    }
    setState(() {
      _parts.add(Payment(_method, amount, label: _method.label));
      // Usul avtomatik keyingi bo'sh usulga o'tadi, summa qolganiga to'ladi.
      _method = _nextFree ?? _method;
      _setAmountToRemaining();
    });
  }

  void _removePart(int index) {
    setState(() {
      final removed = _parts.removeAt(index);
      // O'chirilgan usul yana ochiladi — uni joriy usul qilib qo'yamiz.
      _method = removed.method;
      _setAmountToRemaining();
    });
  }

  /// Yakuniy: qolgan summani joriy usul bilan yopadi va ro'yxatni qaytaradi.
  void _finish() {
    final payments = [
      ..._parts,
      Payment(_method, _remaining, label: _method.label),
    ];
    Navigator.of(context).pop(payments);
  }

  // --- Keypad handlers ---
  void _pressDigit(String d) {
    setState(() {
      final cur = _amount.text;
      if (cur == '0') {
        _amount.text = d;
      } else {
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
    final hasParts = _parts.isNotEmpty;
    // Bo'lib to'lash tugmasi: summa qolganidan kam, musbat va yana bo'lish mumkin.
    final canAddPart = _amountValue > 0 && _amountValue < _remaining && _canSplitMore;
    // Yakuniy tugma: joriy usul bo'sh va summa qolganini qoplaydi.
    final canFinish = _remaining > 0 && !_used(_method) && _amountValue >= _remaining;

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
              // Jami summa.
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

              // Qo'shilgan qismlar + qolgan summa (bo'lib to'lash holati).
              if (hasParts) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _parts.length; i++)
                  _PartRow(
                    label: _parts[i].label,
                    amount: _parts[i].amount,
                    onRemove: () => _removePart(i),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Qoldi:',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        Money.formatSom(_remaining),
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              // Usul tugmalari — ishlatilgani xira/bosilmaydigan.
              Row(
                children: [
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.payments,
                    label: 'Naqd',
                    selected: _method == PaymentMethod.cash,
                    disabled: _used(PaymentMethod.cash),
                    onTap: () => _selectMethod(PaymentMethod.cash),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.credit_card,
                    label: 'Karta',
                    selected: _method == PaymentMethod.card,
                    disabled: _used(PaymentMethod.card),
                    onTap: () => _selectMethod(PaymentMethod.card),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PaymentMethodTile(
                    icon: Icons.qr_code,
                    label: 'QR',
                    selected: _method == PaymentMethod.qr,
                    disabled: _used(PaymentMethod.qr),
                    onTap: () => _selectMethod(PaymentMethod.qr),
                  )),
                ],
              ),
              const SizedBox(height: 20),
              // "Olingan summa".
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
              if (_keypadVisible) ...[
                const SizedBox(height: 6),
                NumericKeypad(
                  onDigit: _pressDigit,
                  onBackspace: _pressBackspace,
                  onClear: _pressClear,
                  onHide: () => setState(() => _keypadVisible = false),
                ),
              ],

              // Bo'lib to'lash tugmasi — summa qolganidan kam bo'lsa.
              if (canAddPart) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _addPart,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Bo\'lib to\'lash: ${Money.formatSom(_amountValue)} ${_method.label} qo\'shish',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              // Qaytim — faqat naqdda, qolgan summaga nisbatan.
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
                        onPressed: canFinish ? _finish : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          "To'lash (${Money.formatSom(_remaining)} ${_method.label})",
                          style: const TextStyle(
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

/// Qo'shilgan qism qatori — «Karta 10 000» + ✕ o'chirish.
class _PartRow extends StatelessWidget {
  const _PartRow({required this.label, required this.amount, required this.onRemove});
  final String label;
  final num amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text(
              Money.formatSom(amount),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              tooltip: 'O\'chirish',
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment method tanlash kartochkasi — Naqd/Karta/QR uchun mos.
/// selected=true bo'lganda yashil to'ldirilgan; disabled=true bo'lganda xira va
/// bosilmaydi (usul shu chekda ishlatilgan).
class _PaymentMethodTile extends StatefulWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
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

    final tile = AnimatedScale(
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
            onTap: widget.disabled ? null : widget.onTap,
            onTapDown: widget.disabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: widget.disabled ? null : (_) => setState(() => _pressed = false),
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
                  Icon(widget.icon, color: fg, size: 20),
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

    // Ishlatilgan usul — xira va bosilmaydi.
    return widget.disabled
        ? Opacity(opacity: 0.4, child: IgnorePointer(child: tile))
        : tile;
  }
}
