import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../menu/domain/entities/category.dart';
import '../../../menu/domain/entities/product.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../providers/cart_provider.dart';
import 'qty_dialog.dart';
import 'scan_label_dialog.dart';

/// Category tabs + product grid. Tapping a product adds it to the cart.
class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final products = ref.watch(filteredProductsProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final cart = ref.read(cartProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Menyu xatosi: $e')),
            data: (categories) => _CategoryTabs(
              categories: categories,
              selected: selected,
              onSelect: (id) =>
                  ref.read(selectedCategoryProvider.notifier).state = id,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: products.isEmpty
              ? const Center(
                  child: Text(
                    'Mahsulot yo\'q.\nSinxronlash uchun yangilang.',
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.82,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return _ProductCard(
                      name: p.name,
                      price: p.price,
                      imageUrl: _absoluteUrl(ref, p.imageUrl),
                      markingRequired: p.markingRequired,
                      trackStock: p.trackStock,
                      stockQty: p.stockQty,
                      outOfStock: p.outOfStock,
                      lowStock: p.lowStock,
                      onTap: p.outOfStock
                          ? null
                          : () => _addToCart(context, cart, p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Backend '/static/uploads/...' kabi nisbiy URL qaytaradi — Image.network
/// uchun to'liq URL kerak. AppConfig'dan baseUrl olib ulaymiz.
String? _absoluteUrl(WidgetRef ref, String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final base = ref.read(appConfigProvider).baseUrl;
  return base.replaceAll(RegExp(r'/+$'), '') + (url.startsWith('/') ? url : '/$url');
}

Future<void> _addToCart(BuildContext context, CartNotifier cart, Product p) async {
  String? label;
  if (p.markingRequired) {
    // Markirovka mahsulot uchun har dona alohida DataMatrix skanerlanadi.
    label = await ScanLabelDialog.show(context, p.name);
    if (label == null) return; // kassir bekor qildi
  }
  // Kilolab sotiladigan mahsulot (birligi "kg"): bosishi bilan tarozi
  // oynasi — gramm kiritiladi, savatga kg sifatida tushadi.
  num qty = 1;
  if (p.soldByWeight) {
    if (!context.mounted) return;
    final kg = await QtyDialog.show(context,
        name: p.name, price: p.price, weight: true);
    if (kg == null) return; // bekor qilindi
    qty = kg;
  }
  cart.addProduct(p, label: label, qty: qty);
  if (!context.mounted) return;
  final qtyText = p.soldByWeight ? ' (${(qty * 1000).round()} gr)' : '';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${p.name}$qtyText qo\'shildi'),
      duration: const Duration(milliseconds: 600),
    ));
}


class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: ChoiceChip(
            label: const Text('Hammasi'),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
        ),
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: Text(c.name),
              selected: selected == c.id,
              onSelected: (_) => onSelect(c.id),
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.onTap,
    this.imageUrl,
    this.markingRequired = false,
    this.trackStock = false,
    this.stockQty = 0,
    this.outOfStock = false,
    this.lowStock = false,
  });

  final String name;
  final num price;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool markingRequired;
  final bool trackStock;
  final num stockQty;
  final bool outOfStock;
  final bool lowStock;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: widget.outOfStock ? 0.5 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.96 : 1.0,
        child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.4),
              width: _pressed ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.02 : 0.04),
                blurRadius: _pressed ? 4 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Rasm / placeholder — kartochkaning yuqori qismi (flexible)
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _ProductImage(url: widget.imageUrl),
                          ),
                        ),
                        if (widget.markingRequired)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Tooltip(
                                message: 'Markirovka — DataMatrix skanerlash majburiy',
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),
                        if (widget.trackStock)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: _StockChip(
                              qty: widget.stockQty,
                              outOfStock: widget.outOfStock,
                              lowStock: widget.lowStock,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mahsulot nomi
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Narx
                  Text(
                    Money.formatSom(widget.price),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Kartochka rasmi — Image.network yoki xato/yo'q holatida chiroyli placeholder.
class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _ImagePlaceholder();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ImagePlaceholder(loading: true);
      },
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              )
            : Icon(
                Icons.restaurant_menu,
                size: 40,
                color: theme.colorScheme.primary.withValues(alpha: 0.55),
              ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.qty,
    required this.outOfStock,
    required this.lowStock,
  });
  final num qty;
  final bool outOfStock;
  final bool lowStock;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;
    if (outOfStock) {
      bg = Colors.red.shade600;
      fg = Colors.white;
      text = 'Yo\'q';
    } else if (lowStock) {
      bg = Colors.orange.shade600;
      fg = Colors.white;
      text = _fmt(qty);
    } else {
      bg = Colors.white.withValues(alpha: 0.95);
      fg = Colors.green.shade800;
      text = _fmt(qty);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static String _fmt(num n) {
    // 100.000 → 100; 12.500 → 12.5
    final s = n.toStringAsFixed(3);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }
}
