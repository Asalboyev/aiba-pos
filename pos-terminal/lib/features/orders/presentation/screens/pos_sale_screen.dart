import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../menu/domain/entities/product.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../../../printing/domain/receipt_data.dart';
import '../../../printing/presentation/printing_providers.dart';
import '../../domain/entities/order_draft.dart';
import '../../domain/entities/payment_method.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_providers.dart';
import '../providers/sync_service.dart';
import '../widgets/cart_panel.dart';
import '../widgets/error_check_dialog.dart';
import '../widgets/fiscal_result_dialog.dart';
import '../widgets/keldi_ketdi_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_grid.dart';
import '../widgets/qr_pay_dialog.dart';

class PosSaleScreen extends ConsumerStatefulWidget {
  const PosSaleScreen({super.key});

  @override
  ConsumerState<PosSaleScreen> createState() => _PosSaleScreenState();
}

/// Oxirgi "xato" deb belgilangan chek raqami — keyingi (to'g'ri) chekда
/// "XATO CHEK №13 o'rniga" satri chiqadi, keyin tozalanadi.
String? _lastErrorCheckNumber;

class _PosSaleScreenState extends ConsumerState<PosSaleScreen> {
  @override
  void initState() {
    super.initState();
    // GLOBAL klaviatura: fokus qayerda bo'lishidan qat'i nazar F-klavishlar
    // HAR DOIM ishlaydi (dialogdan keyin fokus yo'qolsa ham).
    HardwareKeyboard.instance.addHandler(_onKey);
    // Ekran ochilishi bilan qidiruv tayyor.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => posSearchFocusNode.requestFocus());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Ustida dialog ochiq bo'lsa — klavishlarni dialogga qoldiramiz.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.f1) {
      posSearchFocusNode.requestFocus();
      return true;
    }
    if (k == LogicalKeyboardKey.f2) {
      _scanAdd(context, ref);
      return true;
    }
    if (k == LogicalKeyboardKey.f3) {
      _checkout(context, ref, PaymentMethod.qr);
      return true;
    }
    if (k == LogicalKeyboardKey.f4) {
      _checkout(context, ref, PaymentMethod.card);
      return true;
    }
    if (k == LogicalKeyboardKey.f5) {
      _checkout(context, ref, PaymentMethod.cash);
      return true;
    }
    if (k == LogicalKeyboardKey.f6) {
      _checkout(context, ref, PaymentMethod.keldiKetdi);
      return true;
    }
    // ── Bir nechta buyurtma (mijoz kutib qolsa) — faqat klaviatura ──
    final notifier = ref.read(cartProvider.notifier);
    if (k == LogicalKeyboardKey.f7) {
      // Yangi zakaz ochib, unga o'tamiz; qidiruv darhol tayyor.
      notifier.newOrder();
      posSearchFocusNode.requestFocus();
      _toast(context, 'Yangi zakaz — ${notifier.orderCount}');
      return true;
    }
    if (k == LogicalKeyboardKey.f8) {
      // F8 — keyingi zakaz, Shift+F8 — oldingi (ikkisi ham aylanadi).
      if (notifier.orderCount > 1) {
        final n = notifier.orderCount;
        final step = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
        final next = (notifier.activeOrder + step + n) % n;
        notifier.switchOrder(next);
        posSearchFocusNode.requestFocus();
        _toast(context, 'Zakaz - ${next + 1}');
      } else {
        _toast(context, 'Boshqa zakaz yo\'q — F7 yangi zakaz');
      }
      return true;
    }
    if (k == LogicalKeyboardKey.f9) {
      _closeOrder(context, ref);
      return true;
    }
    // Savatdagi oxirgi qatorni o'chirish — Delete/Backspace (qidiruv bo'sh
    // bo'lsagina, aks holda matn tahriri buzilmasin).
    if ((k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) &&
        !posSearchFocusNode.hasFocus) {
      final cart = ref.read(cartProvider);
      if (cart.items.isNotEmpty) {
        notifier.removeAt(cart.items.length - 1);
        _toast(context, 'Oxirgi qator o\'chirildi');
      }
      return true;
    }
    return false;
  }

  void _toast(BuildContext context, String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PosColors.card,
      ));
  }

  /// F9 — joriy zakazni bekor qilish. Savatда mahsulot bo'lsa: SABAB so'raladi
  /// va XATO URILGAN CHEK chop etiladi (to'lov qilinmagan bo'lsa ham —
  /// mahsulot xato urilgan bo'lsa hisobga olinishi shart), keyin savat
  /// tozalanadi / zakaz yopiladi. Bo'sh bo'lsa — jimgina yopiladi.
  Future<void> _closeOrder(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cartProvider.notifier);
    final cart = ref.read(cartProvider);

    if (cart.items.isNotEmpty) {
      // Sabab tanlanmasa (Esc) — hech narsa qilmaymiz.
      final r = await ErrorCheckDialog.show(context);
      if (r == null) {
        posSearchFocusNode.requestFocus();
        return;
      }
      // 1) Bazaga XATO CHEK sifatida yozamiz — chek RAQAMI beriladi va
      // adminka "Xato cheklar" ro'yxatida ko'rinadi. To'lov yo'q, shuning
      // uchun fiskalga ketmaydi (soliqqa yuborilmaydi).
      String? errNumber;
      try {
        final dio = ref.read(dioClientProvider);
        // Chek raqami oddiy savdo bilan bir xil ketma-ketlikda beriladi —
        // xato chek ham navbatdagi raqamni oladi (masalan GDT1-15).
        final errNo = await ref.read(appConfigProvider).nextOrderNumber();
        final res = await dio.post(
          '/api/v2/pos-terminal/orders',
          data: {
            'client_uuid': const Uuid().v4(),
            'number': errNo,
            'items': [
              for (final it in cart.items)
                {
                  if (it.productId != null) 'product_id': it.productId,
                  'name': it.name,
                  'qty': it.qty,
                  'price': it.price,
                  if (it.labels.isNotEmpty) 'labels': it.labels,
                }
            ],
            'payments': const [],
            'note': 'Xato urilgan chek: ${r.reason}',
          },
        );
        final data = (res.data is Map) ? res.data as Map : const {};
        final order = (data['order'] is Map) ? data['order'] as Map : const {};
        final oid = (order['id'] ?? '').toString();
        errNumber = (order['number'] ?? '').toString();
        if (oid.isNotEmpty) {
          await dio.post('/api/v2/pos-terminal/orders/$oid/mark-error',
              data: {'reason': r.reason, 'note': r.note});
          // Ochiq qolmasin — bekor qilingan holatga o'tkazamiz.
          await dio.post('/api/v2/pos-terminal/orders/$oid/cancel');
        }
      } catch (_) {
        // Oflayn/xato — chek baribir chop etiladi (raqamsiz).
      }
      if (errNumber != null && errNumber.isEmpty) errNumber = null;
      // Keyingi (to'g'irlangan) chekда shu raqamga havola qoldiramiz.
      _lastErrorCheckNumber = errNumber;

      // 2) XATO CHEK nusxasini chop etamiz (chek raqami bilan).
      final ses = ref.read(sessionProvider);
      final rr = ses?.restaurant;
      final errSlip = ReceiptData(
        restaurantName: rr?.name ?? 'AIBA',
        terminalName: ses?.terminal.name,
        orderNumber: errNumber,
        items: cart.items,
        subtotal: cart.subtotal,
        discount: cart.discount,
        total: cart.total,
        payments: const [],
        fiscal: null,
        createdAt: DateTime.now(),
        legalName: rr?.legalName,
        inn: rr?.inn,
        address: rr?.address,
        phone: rr?.receiptPhone,
        header: rr?.receiptHeader,
        footer: rr?.receiptFooter,
        showQr: false,
        showMxik: rr?.receiptShowMxik ?? true,
        paperWidth: rr?.receiptPaperWidth ?? 80,
        isErrorCheck: true,
        errorReason: r.reason,
      );
      final rep =
          await ref.read(printerServiceProvider).printReceipt(errSlip);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text('Xato chek: ${r.reason} · ${rep.message}')));
      }
    }

    if (notifier.orderCount <= 1) {
      notifier.clear();
    } else {
      notifier.closeOrder(notifier.activeOrder);
      if (context.mounted) _toast(context, 'Zakaz yopildi');
    }
    posSearchFocusNode.requestFocus();
  }

  Future<void> _checkout(
      BuildContext context, WidgetRef ref, PaymentMethod method) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Keldi-ketdi (VIP mehmon) — manager Telegram kodi bilan tasdiqlanadi,
    // pul olinmaydi, chek "keldi-ketdi" to'lovi bilan yopiladi.
    // QR bosilса — Payme/Click/QR skaner oynasi; aks holda oddiy to'lov oynasi.
    final List<Payment>? payments;
    if (method == PaymentMethod.keldiKetdi) {
      final ok = await KeldiKetdiDialog.show(context, amount: cart.total);
      if (ok != true || !context.mounted) return;
      payments = [
        Payment(PaymentMethod.keldiKetdi, cart.total, label: 'Keldi-ketdi'),
      ];
    } else if (method == PaymentMethod.qr) {
      // QR to'lovда 2 chek: 1) "To'lash" bosilganda mahsulotlar + TO'LOV KODI
      // QR (fiskal emas) — mijoz skanerlab to'laydi; 2) to'lov o'tgach fiskal
      // chek avtomatik chiqadi. Boshqa to'lov turlarida — bitta chek.
      payments = await QrPayDialog.show(
        context,
        cart.total,
        onPrintPaymentSlip: (checkoutUrl) async {
          final ses = ref.read(sessionProvider);
          final rr = ses?.restaurant;
          final slip = ReceiptData(
            restaurantName: rr?.name ?? 'AIBA',
            terminalName: ses?.terminal.name,
            orderNumber: null, // chek raqami hali yo'q (to'lovdan oldin)
            items: cart.items,
            subtotal: cart.subtotal,
            discount: cart.discount,
            total: cart.total,
            payments: const [],
            fiscal: null,
            createdAt: DateTime.now(),
            legalName: rr?.legalName,
            inn: rr?.inn,
            address: rr?.address,
            phone: rr?.receiptPhone,
            header: rr?.receiptHeader,
            footer: rr?.receiptFooter,
            showQr: false,
            showMxik: rr?.receiptShowMxik ?? true,
            paperWidth: rr?.receiptPaperWidth ?? 80,
            paymentQrUrl: checkoutUrl,
          );
          final rep = await ref.read(printerServiceProvider).printReceipt(slip);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(rep.message)));
          }
        },
      );
    } else {
      payments =
          await PaymentDialog.show(context, cart.total, initialMethod: method);
    }
    if (payments == null || payments.isEmpty || !context.mounted) return;

    // Daily order number is generated locally so the printed receipt always
    // carries one — even when the sale is queued offline.
    // Oldingi chek XATO deb belgilangan bo'lsa — to'g'irlangan chek AYNAN
    // O'SHA raqamni oladi (masalan 15). Bazada ikkita 15 bo'ladi, lekin
    // xatosi "is_error_check" bilan belgilangan va hisobotlarga
    // KIRMAYDI — faqat to'g'risi sanaladi.
    final orderNumber = _lastErrorCheckNumber ??
        await ref.read(appConfigProvider).nextOrderNumber();

    final draft = OrderDraft(
      clientUuid: const Uuid().v4(),
      number: orderNumber,
      items: cart.items,
      discount: cart.discount,
      payments: payments,
      // Joriy ochiq smena — serverdagi eskirgan JWT shift_id'ga ishonmasdan,
      // sotuvni aynan shu smenaga bog'laymiz (smena yopib-ochilgan bo'lsa ham).
      shiftId: ref.read(sessionProvider)?.shiftId,
    );

    // 1) Save locally + attempt immediate sync.
    final result = await ref.read(ordersRepositoryProvider).checkout(draft);
    ref.invalidate(recentOrdersProvider);
    ref.invalidate(unsyncedCountProvider);

    // Kassa-relay fiskal: navbatga tushgan chekni darhol lokal Communicator
    // orqali yuborishga urinamiz (fire-and-forget — dialog holatni o'zi
    // qayta so'rab turadi va "sent" bo'lganda QR bilan yangilanadi).
    if (result.synced) {
      // ignore: unawaited_futures
      ref.read(fiscalBridgeProvider).run();
    }

    // 2) Build receipt data and (optionally) print.
    final session = ref.read(sessionProvider);
    final r = session?.restaurant;
    final receipt = ReceiptData(
      restaurantName: r?.name ?? 'AIBA',
      terminalName: session?.terminal.name,
      orderNumber: result.orderNumber ?? draft.number,
      items: cart.items,
      subtotal: cart.subtotal,
      discount: cart.discount,
      total: cart.total,
      payments: draft.payments,
      fiscal: result.fiscal,
      createdAt: DateTime.now(),
      // Chek sozlamalari — adminkadan boshqariladi va login javobida keladi.
      legalName: r?.legalName,
      inn: r?.inn,
      address: r?.address,
      phone: r?.receiptPhone,
      header: r?.receiptHeader,
      footer: r?.receiptFooter,
      showQr: r?.receiptShowQr ?? true,
      showMxik: r?.receiptShowMxik ?? true,
      paperWidth: r?.receiptPaperWidth ?? 80,
      // Oldingi chek xato deb belgilangan bo'lsa — bu chek uning o'rniga.
      replacesErrorNumber: _lastErrorCheckNumber,
    );
    // Havola bir marta ishlatiladi.
    _lastErrorCheckNumber = null;

    if (!context.mounted) return;

    // 3) Show result + QR; clear the cart.
    final printerService = ref.read(printerServiceProvider);
    await FiscalResultDialog.show(
      context,
      result: result,
      // Dialog polls fiscal until "sent" and hands us the refreshed CheckoutResult,
      // so the printed receipt carries the final fiscal_sign + QR (not "pending").
      onPrint: (refreshed) async {
        // Adminka'da chek sozlamalari o'zgargan bo'lishi mumkin — chop etishdan
        // oldin serverdan yangi qiymatlarni olamiz. Server javob bergan bo'lsa,
        // barcha maydonlarni to'la almashtiramiz (jumladan null'lar — foydalanuvchi
        // maydonni bo'shatgan bo'lishi mumkin). Offline bo'lsa eskisi ishlaydi.
        await ref.read(sessionProvider.notifier).refreshRestaurant();
        final freshR = ref.read(sessionProvider)?.restaurant;
        final useFresh = freshR != null;
        // Logoni ham yuklab olamiz — chekda katta va aniq chiqishi uchun.
        List<int>? logoBytes;
        final logoUrl = useFresh ? freshR.receiptLogoUrl : null;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          logoBytes = await ref.read(dioClientProvider).fetchBytes(logoUrl);
        }
        final freshReceipt = ReceiptData(
          restaurantName: useFresh ? freshR.name : receipt.restaurantName,
          terminalName: receipt.terminalName,
          orderNumber: refreshed.orderNumber ?? receipt.orderNumber,
          items: receipt.items,
          subtotal: receipt.subtotal,
          discount: receipt.discount,
          total: receipt.total,
          payments: receipt.payments,
          fiscal: refreshed.fiscal ?? receipt.fiscal,
          createdAt: receipt.createdAt,
          legalName: useFresh ? freshR.legalName : receipt.legalName,
          inn: useFresh ? freshR.inn : receipt.inn,
          address: useFresh ? freshR.address : receipt.address,
          phone: useFresh ? freshR.receiptPhone : receipt.phone,
          header: useFresh ? freshR.receiptHeader : receipt.header,
          footer: useFresh ? freshR.receiptFooter : receipt.footer,
          showQr: useFresh ? freshR.receiptShowQr : receipt.showQr,
          showMxik: useFresh ? freshR.receiptShowMxik : receipt.showMxik,
          paperWidth: useFresh ? freshR.receiptPaperWidth : receipt.paperWidth,
          logoBytes: logoBytes,
        );
        final report = await printerService.printReceipt(freshReceipt);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(report.message)),
          );
        }
      },
      // Kassir "Xato urildi" deb belgilaganda: XATO CHEK bannerли nusxa
      // chop etiladi va raqam eslab qolinadi (keyingi to'g'ri chek uchun).
      onMarkedError: (reason, note) async {
        _lastErrorCheckNumber =
            (receipt.orderNumber ?? '').replaceAll('#', '');
        final errCopy = ReceiptData(
          restaurantName: receipt.restaurantName,
          terminalName: receipt.terminalName,
          orderNumber: receipt.orderNumber,
          items: receipt.items,
          subtotal: receipt.subtotal,
          discount: receipt.discount,
          total: receipt.total,
          payments: receipt.payments,
          fiscal: receipt.fiscal,
          createdAt: receipt.createdAt,
          legalName: receipt.legalName,
          inn: receipt.inn,
          address: receipt.address,
          phone: receipt.phone,
          header: receipt.header,
          footer: receipt.footer,
          // Xato chekда soliq QR kerak emas — u hisobga olinmaydi.
          showQr: false,
          showMxik: receipt.showMxik,
          paperWidth: receipt.paperWidth,
          isErrorCheck: true,
          errorReason: reason,
        );
        await printerService.printReceipt(errCopy);
      },
    );

    ref.read(cartProvider.notifier).clear();

    // 4) If we were offline, the order is queued; nudge a background push.
    if (!result.synced) {
      // ignore: unawaited_futures
      ref.read(syncServiceProvider.notifier).pushPending();
    }

    // Keyingi savdo uchun qidiruv darhol tayyor (klaviatura-first).
    posSearchFocusNode.requestFocus();
  }

  /// F2 — markirovka/shtrix skaner oynasi: skaner kodni yozadi + Enter →
  /// mahsulot topilib avtomatik savatga tushadi.
  Future<void> _scanAdd(BuildContext context, WidgetRef ref) async {
    final code = await _ScanDialog.show(context);
    if (code == null || code.isEmpty || !context.mounted) return;
    final all = ref.read(productsProvider).maybeWhen(
          data: (p) => p,
          orElse: () => const <Product>[],
        );
    final t = code.toLowerCase();
    Product? hit;
    for (final p in all) {
      final sku = (p.sku ?? '').toLowerCase();
      if (sku.isNotEmpty && (sku == t || t.contains(sku))) {
        hit = p;
        break;
      }
    }
    if (hit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mahsulot topilmadi — kod bazada yo\'q')));
      return;
    }
    // Markirovkali mahsulotga skanerlangan DataMatrix kod label sifatida
    // biriktiriladi (soliqqa shu kod ketadi) va mahsulot AVTOMATIK savatga
    // tushadi — bunday mahsulotlar menyuda ko'rinmaydi.
    ref.read(cartProvider.notifier).addProduct(hit,
        label: hit.markingRequired ? code : null);
    if (context.mounted) {
      _toast(context,
          '✓ ${hit.name} savatga qo\'shildi${hit.markingRequired ? ' (markirovka)' : ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    // Figma nisbatida savat kengligi: 301/1366 — katta ekranda kattalashadi.
    final cartW = (size.width * 301 / 1366).clamp(301.0, 480.0);

    if (isWide) {
      // F-klavishlar GLOBAL handler orqali (initState) — fokusga bog'liq emas.
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 3, child: ProductGrid()),
            const SizedBox(width: 16),
            SizedBox(
              // Figma: Basket 301px @1366 — ekranga proporsional.
              width: cartW,
              // Yuqoridagi avatar tagidan boshlanadi.
              child: Padding(
                padding: const EdgeInsets.only(top: 46),
                child: CartPanel(
                    onCheckout: (m) => _checkout(context, ref, m)),
              ),
            ),
          ],
        ),
      );
    }

    // Tor ekran (telefon): grid + pastda savat paneli tugmasi.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Stack(
        children: [
          const ProductGrid(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MiniCartBar(onOpen: () => _openCartSheet(context, ref)),
          ),
        ],
      ),
    );
  }

  void _openCartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CartPanel(onCheckout: (m) {
          Navigator.of(context).pop();
          _checkout(context, ref, m);
        }),
      ),
    );
  }
}

class _MiniCartBar extends ConsumerWidget {
  const _MiniCartBar({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.primary,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 8),
              Text('${cart.itemCount} ta',
                  style: const TextStyle(color: Colors.white)),
              const Spacer(),
              Text('Savatni ochish →',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// F2 — skaner/markirovka kiritish oynasi. Skaner kod yozib Enter yuboradi.
class _ScanDialog extends StatelessWidget {
  const _ScanDialog();

  static Future<String?> show(BuildContext context) => showDialog<String>(
        context: context,
        builder: (_) => const _ScanDialog(),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text('Skaner / markirovka (F2)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF232329),
                  hintText: 'Kodni skanerlang yoki tering, Enter…',
                  hintStyle: const TextStyle(color: Color(0xFF5C626A)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0x3DFFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF2277EA), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Esc — bekor qilish',
                  style: TextStyle(color: Color(0xFF8A9098), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
