import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_provider.dart';

/// The right-hand cart panel: line items with qty controls, discount, total.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, required this.onCheckout});

  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined),
                const SizedBox(width: 8),
                Text('Savat (${cart.itemCount})',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (!cart.isEmpty)
                  TextButton.icon(
                    onPressed: notifier.clear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Tozalash'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Savat bo\'sh'))
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) => _CartLine(
                      item: cart.items[i],
                      onInc: () => notifier.increment(i),
                      onDec: () => notifier.decrement(i),
                      onRemove: () => notifier.removeAt(i),
                      onQtyTap: () async {
                        final qty = await _QtyDialog.show(
                            context, cart.items[i]);
                        if (qty != null) notifier.setQty(i, qty);
                      },
                    ),
                  ),
          ),
          const Divider(height: 1),
          _DiscountRow(
            discount: cart.discount,
            onChanged: notifier.setDiscount,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _totalRow(theme, 'Oraliq', cart.subtotal),
                if (cart.discount > 0)
                  _totalRow(theme, 'Chegirma', -cart.discount),
                const SizedBox(height: 4),
                _totalRow(theme, 'JAMI', cart.total, big: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: cart.isEmpty ? null : onCheckout,
                    icon: const Icon(Icons.payment),
                    label: Text('To\'lov • ${Money.formatSom(cart.total)}',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(ThemeData theme, String label, num amount,
      {bool big = false}) {
    final style = big
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Money.formatSom(amount), style: style),
        ],
      ),
    );
  }
}

/// Miqdorni odam o'qiydigan ko'rinishda: 2 → "2", 0.4 → "0.4" (kg).
String _fmtQty(num q) {
  if (q % 1 == 0) return q.toInt().toString();
  var s = q.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
    required this.onQtyTap,
  });

  final CartItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;
  final VoidCallback onQtyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minVerticalPadding: 8,
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(Money.formatSom(item.lineTotal)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundAction(icon: Icons.remove, onTap: onDec),
          // Miqdor ustiga bosilsa gramm/dona kiritish oynasi ochiladi
          // (kilolab sotiladigan mahsulotlar uchun: 400 gr = 0.4).
          InkWell(
            onTap: onQtyTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 44,
              child: Center(
                child: Text(
                  _fmtQty(item.qty),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          _RoundAction(icon: Icons.add, onTap: onInc),
          const SizedBox(width: 14),
          _RoundAction(icon: Icons.close, onTap: onRemove, danger: true),
        ],
      ),
    );
  }
}

/// Miqdor kiritish oynasi: raqam yoziladi, keyin "Dona" yoki "Gramm"
/// bosiladi. Gramm rejimida narx 1 kg uchun deb hisoblanadi:
/// 400 [Gramm] → miqdor 0.4, summa = narx × 0.4.
class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.item});

  final CartItem item;

  static Future<num?> show(BuildContext context, CartItem item) =>
      showDialog<num>(
        context: context,
        builder: (context) => _QtyDialog(item: item),
      );

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num? _value() {
    final v = num.tryParse(_controller.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  void _submit({required bool grams}) {
    final v = _value();
    if (v == null) return;
    // Gramm → kg (narx 1 kg uchun kiritilgan bo'ladi).
    final qty = grams ? v / 1000 : v;
    Navigator.of(context).pop(qty);
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.item.price;
    final v = _value();
    return AlertDialog(
      title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              labelText: 'Miqdor',
              hintText: 'masalan: 400',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (v != null)
            Text(
              'Gramm bo\'lsa: ${Money.formatSom(price * v / 1000)}   •   '
              'Dona bo\'lsa: ${Money.formatSom(price * v)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          Text(
            'Kilolab sotiladigan mahsulotda narx 1 kg uchun kiritilgan '
            'bo\'lishi kerak (masalan 85 000 = 1 kg).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor'),
        ),
        OutlinedButton.icon(
          onPressed: v == null ? null : () => _submit(grams: false),
          icon: const Icon(Icons.tag),
          label: const Text('Dona'),
        ),
        FilledButton.icon(
          onPressed: v == null ? null : () => _submit(grams: true),
          icon: const Icon(Icons.scale),
          label: const Text('Gramm'),
        ),
      ],
    );
  }
}

/// Large round tap target for the cart's most-used controls. POS terminals
/// are operated quickly (often on touch screens), so these stay ≥48px.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: danger ? scheme.errorContainer : scheme.secondaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 26,
            color: danger ? scheme.onErrorContainer : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _DiscountRow extends StatefulWidget {
  const _DiscountRow({required this.discount, required this.onChanged});
  final num discount;
  final void Function(num) onChanged;

  @override
  State<_DiscountRow> createState() => _DiscountRowState();
}

class _DiscountRowState extends State<_DiscountRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.discount > 0 ? widget.discount.round().toString() : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.discount_outlined, size: 20),
          const SizedBox(width: 8),
          const Text('Chegirma:'),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                hintText: '0',
                border: OutlineInputBorder(),
                suffixText: "so'm",
              ),
              onChanged: (v) => widget.onChanged(num.tryParse(v.trim()) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}
