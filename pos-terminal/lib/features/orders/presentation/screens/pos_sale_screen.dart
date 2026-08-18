import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../printing/domain/receipt_data.dart';
import '../../../printing/presentation/printing_providers.dart';
import '../../domain/entities/order_draft.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_providers.dart';
import '../providers/sync_service.dart';
import '../widgets/cart_panel.dart';
import '../widgets/fiscal_result_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_grid.dart';

class PosSaleScreen extends ConsumerWidget {
  const PosSaleScreen({super.key});

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final payments = await PaymentDialog.show(context, cart.total);
    if (payments == null || payments.isEmpty || !context.mounted) return;

    // Daily order number is generated locally so the printed receipt always
    // carries one — even when the sale is queued offline.
    final orderNumber =
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
    );

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
    );

    ref.read(cartProvider.notifier).clear();

    // 4) If we were offline, the order is queued; nudge a background push.
    if (!result.synced) {
      // ignore: unawaited_futures
      ref.read(syncServiceProvider.notifier).pushPending();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Row(
        children: [
          const Expanded(flex: 3, child: ProductGrid()),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: CartPanel(onCheckout: () => _checkout(context, ref)),
          ),
        ],
      );
    }

    // Narrow layout (phone): grid on top, cart in a bottom sheet trigger.
    return Stack(
      children: [
        const ProductGrid(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MiniCartBar(
            onOpen: () => _openCartSheet(context, ref),
          ),
        ),
      ],
    );
  }

  void _openCartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CartPanel(onCheckout: () {
          Navigator.of(context).pop();
          _checkout(context, ref);
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
