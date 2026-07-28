import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_provider.dart';
import 'qty_dialog.dart';

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
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      // Kg mahsulotda +/- 100 grammlik qadam bilan yuradi,
                      // dona mahsulotda odatdagidek 1 dona.
                      num step(num q, int dir) => item.soldByWeight
                          ? ((q * 1000).round() + dir * 100) / 1000
                          : q + dir;
                      return _CartLine(
                        item: item,
                        onInc: () =>
                            notifier.setQty(i, step(item.qty, 1)),
                        onDec: () =>
                            notifier.setQty(i, step(item.qty, -1)),
                        onRemove: () => notifier.removeAt(i),
                        onQtyTap: () async {
                          final qty = await QtyDialog.show(
                            context,
                            name: item.name,
                            price: item.price,
                            weight: item.soldByWeight,
                            current: item.qty,
                          );
                          if (qty != null) notifier.setQty(i, qty);
                        },
                      );
                    },
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
          // Miqdor ustiga bosilsa kiritish oynasi: kg mahsulotda gramm,
          // dona mahsulotda butun son.
          InkWell(
            onTap: onQtyTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: item.soldByWeight ? 72 : 52,
              height: 44,
              child: Center(
                child: Text(
                  item.soldByWeight
                      ? '${_fmtQty(item.qty)} kg'
                      : _fmtQty(item.qty),
                  textAlign: TextAlign.center,
                  style: (item.soldByWeight
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
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
