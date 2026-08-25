import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../../menu/domain/entities/category.dart';
import '../../../menu/domain/entities/product.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../providers/cart_provider.dart';
import 'qty_dialog.dart';
import 'scan_label_dialog.dart';

/// Qidiruv + kategoriya chiplari + mahsulotlar grid'i (Figma "Pos Design").
/// Suv fonining ustida: qidiruv va chiplar to'g'ridan-to'g'ri, grid — qorong'i
/// yumaloq panel ichida. Bosilса savatga qo'shiladi.
class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final products = ref.watch(filteredProductsProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final counts = ref.watch(categoryCountsProvider);
    final cart = ref.read(cartProvider.notifier);
    final baseUrl = ref.read(appConfigProvider).baseUrl;
    final searching = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchBar(onSubmit: (raw) => _submitSearch(context, ref, cart, raw)),
        const SizedBox(height: 14),
        SizedBox(
          height: 68,
          child: categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (categories) => _CategoryChips(
              categories: categories,
              selected: selected,
              counts: counts,
              baseUrl: baseUrl,
              onSelect: (id) =>
                  ref.read(selectedCategoryProvider.notifier).state = id,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: PosColors.panel,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: products.isEmpty
                ? (searching ? const _NoResults() : const _EmptyProducts())
                : LayoutBuilder(builder: (context, gc) {
                    // Kichik ekran (kassa monobloklari, ~1024px): 5 ta tor
                    // katak o'rniga 4 ta KENGROQ katak — nomlar o'qiladi.
                    // Har katak kamida ~150px bo'lsin.
                    final cols = (gc.maxWidth / 162).floor().clamp(3, 6);
                    final narrow = gc.maxWidth / cols < 165;
                    return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      // Tor katakda nom 2 qator bo'ladi — biroz balandroq.
                      childAspectRatio: narrow ? 0.88 : 170 / 165,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return _ProductCard(
                        name: p.name,
                        price: p.price,
                        code: (p.sku != null && p.sku!.trim().isNotEmpty)
                            ? p.sku!.trim()
                            : '',
                        imageUrl: _absoluteUrl(baseUrl, p.imageUrl),
                        markingRequired: p.markingRequired,
                        outOfStock: p.outOfStock,
                        onTap: p.outOfStock
                            ? null
                            : () => _addToCart(context, cart, p),
                      );
                    },
                  );
                  }),
          ),
        ),
      ],
    );
  }
}

final _trailingSlashes = RegExp(r'/+$');

String? _absoluteUrl(String base, String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return base.replaceAll(_trailingSlashes, '') +
      (url.startsWith('/') ? url : '/$url');
}

/// Enter bilan qo'shish: "kod", "nom", "3*kod" yoki "kod*3" (miqdor bilan).
/// Avval kod (sku) aniq mosligi, keyin nom/kod ichida qidiriladi.
Future<void> _submitSearch(BuildContext context, WidgetRef ref,
    CartNotifier cart, String raw) async {
  if (raw.isEmpty) return;

  // SOF RAQAM + Enter = oxirgi qo'shilgan mahsulot MIQDORI.
  // (Agar aynan shu raqamli kodli mahsulot bo'lsa — u ustun turadi.)
  final pureNum = RegExp(r'^\d+([.,]\d+)?$').hasMatch(raw);
  if (pureNum) {
    final all0 = ref.read(productsProvider).maybeWhen(
          data: (p) => p,
          orElse: () => const <Product>[],
        );
    final hasExactSku =
        all0.any((p) => (p.sku ?? '').toLowerCase() == raw.toLowerCase());
    final items = ref.read(cartProvider).items;
    if (!hasExactSku && items.isNotEmpty) {
      final n = num.tryParse(raw.replaceAll(',', '.')) ?? 0;
      if (n > 0) {
        final i = items.length - 1;
        final last = items[i];
        // Og'irlik mahsulotida raqam GRAMM deb qabul qilinadi (500 → 0.5 kg).
        final q = last.soldByWeight ? n / 1000 : n.round();
        cart.setQty(i, q);
        return;
      }
    }
  }

  num qty = 1;
  var term = raw;
  final m1 = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[*xх]\s*(.+)$').firstMatch(raw);
  final m2 = RegExp(r'^(.+?)\s*[*xх]\s*(\d+(?:[.,]\d+)?)$').firstMatch(raw);
  if (m1 != null) {
    qty = num.tryParse(m1.group(1)!.replaceAll(',', '.')) ?? 1;
    term = m1.group(2)!.trim();
  } else if (m2 != null) {
    qty = num.tryParse(m2.group(2)!.replaceAll(',', '.')) ?? 1;
    term = m2.group(1)!.trim();
  }
  final all = ref.read(productsProvider).maybeWhen(
        data: (p) => p,
        orElse: () => const <Product>[],
      );
  final t = term.toLowerCase();
  Product? hit;
  // 1) ANIQ KOD mosligi — kassir aynan kodni teradi (asosiy oqim).
  for (final p in all) {
    if ((p.sku ?? '').toLowerCase() == t) {
      hit = p;
      break;
    }
  }
  // 2) Kod shu bilan boshlanadi.
  if (hit == null) {
    for (final p in all) {
      if ((p.sku ?? '').toLowerCase().startsWith(t)) {
        hit = p;
        break;
      }
    }
  }
  // 3) Nom yoki kod ichida uchraydi.
  if (hit == null) {
    for (final p in all) {
      if (p.name.toLowerCase().contains(t) ||
          (p.sku ?? '').toLowerCase().contains(t)) {
        hit = p;
        break;
      }
    }
  }
  if (hit == null || hit.outOfStock) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topilmadi: $term'), duration: const Duration(seconds: 2)));
    return;
  }
  if (qty != 1) {
    // Miqdor terilgan — dialogsiz to'g'ridan-to'g'ri qo'shamiz.
    cart.addProduct(hit, qty: hit.soldByWeight ? qty : qty.round());
    _addedToast(context, hit.name, qty);
    return;
  }
  await _addToCart(context, cart, hit);
  if (context.mounted && !hit.markingRequired && !hit.soldByWeight) {
    _addedToast(context, hit.name, 1);
  }
}

/// Qo'shilgani haqida qisqa tasdiq — kassir ko'rib turadi.
void _addedToast(BuildContext context, String name, num qty) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text('✓ $name × ${Money.formatQty(qty)} savatga qo\'shildi'),
      duration: const Duration(milliseconds: 900),
    ));
}

Future<void> _addToCart(
    BuildContext context, CartNotifier cart, Product p) async {
  String? label;
  if (p.markingRequired) {
    label = await ScanLabelDialog.show(context, p.name);
    if (label == null) return;
  }
  num qty = 1;
  if (p.soldByWeight) {
    if (!context.mounted) return;
    final kg = await QtyDialog.show(context,
        name: p.name, price: p.price, weight: true);
    if (kg == null) return;
    qty = kg;
  }
  cart.addProduct(p, label: label, qty: qty);
}

/// Qidiruv maydonining global fokusi — F1 shu yerga fokus beradi.
final posSearchFocusNode = FocusNode(debugLabel: 'pos-search');

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.onSubmit});

  /// Enter bosilganda (kod terildi / skaner o'qidi) chaqiriladi.
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _c =
      TextEditingController(text: ref.read(searchQueryProvider));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _set(String v) {
    _c.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
    );
    ref.read(searchQueryProvider.notifier).state = v;
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(searchQueryProvider);
    // Figma 38px @768 — katta ekranda proporsional kattalashadi.
    final sc =
        (MediaQuery.of(context).size.height / 768).clamp(1.0, 1.6).toDouble();
    return Container(
      height: 38 * sc,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x3DFFFFFF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SvgPicture.asset('assets/icons/search.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                  Color(0x6BFFFFFF), BlendMode.srcIn)),
          const SizedBox(width: 10),
          Expanded(
            // Fizik klaviatura: F1 → fokus, kod/nom teriladi, Enter → savatga.
            child: TextField(
              controller: _c,
              focusNode: posSearchFocusNode,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              onSubmitted: (v) {
                widget.onSubmit(v.trim());
                _set('');
                // Keyingi kod uchun fokus qoladi.
                posSearchFocusNode.requestFocus();
              },
              style: TextStyle(color: Colors.white, fontSize: 13 * sc),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText:
                    'F1 kod/nom · kod*3 miqdor · Enter savatga · F2 skaner · '
                    'F3 QR · F4 karta · F5 naqd · F7 yangi zakaz · F8/⇧F8 zakaz almashtirish · F9 xato chek/bekor · Del oxirgi qator',
                hintStyle: TextStyle(color: Color(0xFF5C626A)),
              ),
            ),
          ),
          if (q.isNotEmpty)
            InkWell(
              onTap: () => _set(''),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Color(0x99FFFFFF), size: 18),
              ),
            ),
          const SizedBox(width: 8),
          // Klavish badge — F1 shu maydonni ochadi.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x3DFFFFFF)),
            ),
            child: const Text('F1',
                style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.baseUrl,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selected;
  final Map<String?, int> counts;
  final String baseUrl;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _Chip(
          icon: 'assets/icons/cat_all.svg',
          label: 'Hammasi',
          count: counts[null] ?? 0,
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final c in categories)
          _Chip(
            icon: 'assets/icons/cat_food.svg',
            // Kategoriya rasmi (admin panelda) — bo'lsa ikon o'rniga ko'rsatiladi.
            imageUrl: _absoluteUrl(baseUrl, c.imageUrl),
            label: c.name,
            count: counts[c.id] ?? 0,
            selected: selected == c.id,
            onTap: () => onSelect(c.id),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });
  final String icon;
  final String? imageUrl;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Figma "Card Category": oq 8% fon, rounded 6, px12 py8, icon(20) tepada +
    // pastda nom(16) + son(12) qatori. Balandligi ~63.
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? PosColors.blue : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: imageUrl != null
                    // Kategoriya rasmi (admin panelda o'rnatilgan).
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 80,
                            errorBuilder: (_, _, _) => SvgPicture.asset(icon,
                                fit: BoxFit.contain,
                                colorFilter: ColorFilter.mode(
                                    selected
                                        ? Colors.white
                                        : const Color(0xB3FFFFFF),
                                    BlendMode.srcIn))),
                      )
                    : SvgPicture.asset(
                        icon,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                            selected ? Colors.white : const Color(0xB3FFFFFF),
                            BlendMode.srcIn),
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.0)),
                  const SizedBox(width: 14),
                  Text('$count xil',
                      style: TextStyle(
                          color: selected
                              ? Colors.white70
                              : const Color(0x6BFFFFFF),
                          fontSize: 12,
                          height: 1.0)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 84, color: Color(0xFF3A3D42)),
          SizedBox(height: 18),
          Text('Hozircha mahsulotlar yo\'q',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Ishni boshlash uchun mahsulotlar va boshqa kerakli '
              'ma\'lumotlarni kiriting',
              style: TextStyle(color: PosColors.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Qidiruv bo'yicha natija topilmaganda (Figma "Ma'lumot topilmadi").
class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 84, color: Color(0xFF3A3D42)),
          SizedBox(height: 18),
          Text('Ma\'lumot topilmadi',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Qidiruvingiz bo\'yicha hech qanday ma\'lumot topilmadi',
              style: TextStyle(color: PosColors.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.code,
    required this.onTap,
    this.imageUrl,
    this.markingRequired = false,
    this.outOfStock = false,
  });

  final String name;
  final num price;
  final String code;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool markingRequired;
  final bool outOfStock;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Kod (SKU) — kassir tez topishi uchun to'liq ko'rsatamiz (qisqa bo'lsa).
    // Uzun bo'lsa oxirgi 6 belgi. Kod bo'sh bo'lsa umuman ko'rsatmaymiz.
    final shortCode = widget.code.length > 8
        ? widget.code.substring(widget.code.length - 6)
        : widget.code;
    return Opacity(
      opacity: widget.outOfStock ? 0.5 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: LayoutBuilder(builder: (context, cc) {
            // Tor katak (kichik kassa ekrani): nom 2 QATOR (o'qiladi!),
            // kod rasm ustida chip, narx har doim BITTA qator.
            final narrow = cc.maxWidth < 165;
            return Container(
            decoration: BoxDecoration(
              color: PosColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PosColors.cardBorder),
            ),
            padding: EdgeInsets.all(narrow ? 8 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _ProductImage(url: widget.imageUrl),
                        ),
                      ),
                      // Tor rejimда kod rasm ustida — nom qatoriga joy bo'shaydi.
                      if (narrow && widget.code.isNotEmpty)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('#$shortCode',
                                style: const TextStyle(
                                    color: Color(0xB3FFFFFF), fontSize: 10)),
                          ),
                        ),
                      if (widget.markingRequired)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_scanner,
                                size: 16, color: Colors.orangeAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: narrow ? 6 : 10),
                if (narrow)
                  Text(widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 12.5,
                          height: 1.15,
                          fontWeight: FontWeight.w500))
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFFAFAFA),
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      // Figma: "#124" — oq 42%. Kod bo'sh bo'lsa ko'rsatilmaydi.
                      if (widget.code.isNotEmpty)
                        Text('#$shortCode',
                            style: const TextStyle(
                                color: Color(0x6BFFFFFF), fontSize: 12)),
                    ],
                  ),
                const SizedBox(height: 4),
                // Narx BITTA qatorda — sig'masa avtomatik kichrayadi
                // (avval "8 000" / "so'm" ikki qatorga bo'linib ketardi).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Money.formatSom(widget.price),
                      maxLines: 1,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: narrow ? 14 : 15,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
          }),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _ImagePlaceholder();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: 400,
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
    // Rasm bo'lmaganда — neytral to'q plitka (Figmaда vilka/ikon yo'q).
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26282E), Color(0xFF1D1F24)],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: PosColors.muted))
            : const Icon(Icons.image_outlined,
                size: 30, color: Color(0xFF3A3D42)),
      ),
    );
  }
}
