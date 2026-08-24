import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/payment_method.dart';
import '../providers/cart_provider.dart';

/// O'ng tomondagi buyurtma paneli — Figma "Pos Design":
/// Zakaz tab'lari, Mijoz, qatorlar (rasm + nom + narx + miqdor), jami va
/// to'lov tugmalari. Qatorga bosilганда hech narsa chiqmaydi.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, required this.onCheckout});

  /// Tanlangan to'lov usuli bilan chaqiriladi (Karta/Naqd/QR).
  final void Function(PaymentMethod method) onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    ref.watch(cartTabsVersionProvider); // tab'lar o'zgarsa qayta chiziladi
    final orderCount = notifier.orderCount;
    final activeOrder = notifier.activeOrder;
    final baseUrl = ref.watch(appConfigProvider).baseUrl;

    return Container(
      decoration: BoxDecoration(
        color: PosColors.panel,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zakaz tab'lari — oxirida yangi buyurtma qo'shish "+".
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < orderCount; i++) ...[
                  _OrderTab(
                    label: 'Zakaz - ${i + 1}',
                    // Klaviatura: F8 — keyingi, Shift+F8 — oldingi zakaz.
                    keyHint: i == activeOrder && orderCount > 1 ? 'F8' : null,
                    selected: i == activeOrder,
                    onTap: () => notifier.switchOrder(i),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: notifier.newOrder,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PosColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.cardBorder),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: PosColors.muted, size: 18),
                        Text('F7',
                            style: TextStyle(
                                color: PosColors.muted,
                                fontSize: 9,
                                height: 1,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Mijoz bloki hozircha yashirilgan (funksiya tayyor bo'lganda ochiladi).
          const Divider(height: 1, color: PosColors.cardBorder),
          const SizedBox(height: 8),
          // Qatorlar.
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: cart.items.length,
                    itemBuilder: (context, i) => _CartLine(
                      item: cart.items[i],
                      imageUrl: _absoluteUrl(baseUrl, cart.items[i].imageUrl),
                      onRemove: () => notifier.removeAt(i),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: PosColors.cardBorder),
          const SizedBox(height: 12),
          // Jami.
          Row(
            children: [
              Text('${cart.itemCount} ta mahsulot',
                  style: const TextStyle(color: PosColors.muted, fontSize: 14)),
              const Spacer(),
              Text(Money.formatSom(cart.total),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          _PayButton(
            label: 'Karta',
            iconAsset: 'assets/icons/pay_card.svg',
            filled: true,
            keyLabel: 'F4',
            onTap: cart.isEmpty ? null : () => onCheckout(PaymentMethod.card),
          ),
          const SizedBox(height: 10),
          _PayButton(
            label: 'Naqd',
            iconAsset: 'assets/icons/pay_cash.svg',
            keyLabel: 'F5',
            onTap: cart.isEmpty ? null : () => onCheckout(PaymentMethod.cash),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PayButton(
                  label: 'Keldi - ketdi',
                  iconAsset: 'assets/icons/pay_users.svg',
                  keyLabel: 'F6',
                  onTap: cart.isEmpty
                      ? null
                      : () => onCheckout(PaymentMethod.keldiKetdi),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PayButton(
                  label: 'QR',
                  iconAsset: 'assets/icons/pay_qr_fill.svg',
                  keyLabel: 'F3',
                  onTap: cart.isEmpty ? null : () => onCheckout(PaymentMethod.qr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _absoluteUrl(String baseUrl, String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return baseUrl.replaceAll(RegExp(r'/+$'), '') +
      (url.startsWith('/') ? url : '/$url');
}

String _fmtQty(num q) {
  if (q % 1 == 0) return q.toInt().toString();
  var s = q.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

class _OrderTab extends StatelessWidget {
  const _OrderTab(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.keyHint});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Klaviatura yorlig'i (masalan "⌃2") — kassir mishka ishlatmaydi.
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? PosColors.blue : PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : PosColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          if (keyHint != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : PosColors.iconChip,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(keyHint!,
                  style: TextStyle(
                      color: selected ? Colors.white : PosColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Savat qatori — bosilганда HECH NARSA chiqmaydi (dizayn talabi).
/// O'chirish uchun uzoq bosiladi (jimgina o'chadi, oyna chiqmaydi).
class _CartLine extends StatelessWidget {
  const _CartLine(
      {required this.item, required this.imageUrl, required this.onRemove});
  final CartItem item;
  final String? imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: onRemove,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PosColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.cardBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: _Thumb(url: imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(Money.formatSom(item.lineTotal),
                        style: const TextStyle(
                            color: PosColors.muted, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.soldByWeight
                    ? '${_fmtQty(item.qty)} kg'
                    : _fmtQty(item.qty),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _ThumbPlaceholder();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ThumbPlaceholder(),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFF232429)),
      child: Icon(Icons.image_outlined, size: 20, color: Color(0xFF4A4E55)),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 72, color: Color(0xFF3A3D42)),
          SizedBox(height: 16),
          Text('Savatcha hozircha bo\'sh',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('Mahsulotlarni tanlang va savatchaga qo\'shing',
                textAlign: TextAlign.center,
                style: TextStyle(color: PosColors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.filled = false,
    this.keyLabel,
  });
  final String label;
  final String iconAsset;
  final VoidCallback? onTap;
  final bool filled;

  /// Tugmani ochadigan klavish (F3/F4/F5/F6) — chiroyli badge sifatida.
  final String? keyLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // Figma: Karta — #2273e7; boshqalar — oq 12%.
    final bg = filled ? PosColors.blue : const Color(0x1FFFFFFF);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 54,
          // To'liq kenglik — tugma panel bo'ylab cho'ziladi (Figma).
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          // Kontent markazda; tor panelda sig'masa proporsional kichrayadi.
          child: Center(
            child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(iconAsset,
                    width: 22,
                    height: 22,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (keyLabel != null) ...[
                  const SizedBox(width: 10),
                  _KeyBadge(text: keyLabel!, onBlue: filled),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Klaviatura klavishi badge'i — "F4" kabi (klaviatura tugmasiga o'xshash).
class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.text, this.onBlue = false});
  final String text;
  final bool onBlue;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: onBlue ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: onBlue ? const Color(0x66FFFFFF) : const Color(0x3DFFFFFF)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}
