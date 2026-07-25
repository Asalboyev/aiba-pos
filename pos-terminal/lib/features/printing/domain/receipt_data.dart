import '../../orders/domain/entities/cart.dart';
import '../../orders/domain/entities/fiscal_info.dart';
import '../../orders/domain/entities/payment_method.dart';

/// Everything needed to render a receipt (print or on-screen preview).
class ReceiptData {
  final String restaurantName;
  final String? terminalName;
  final String? orderNumber;
  final List<CartItem> items;
  final num subtotal;
  final num discount;
  final num total;
  final List<Payment> payments;
  final FiscalInfo? fiscal;
  final DateTime createdAt;
  // --- Chek sozlamalari (adminkadan boshqariladi) ---
  final String? legalName;
  final String? inn;
  final String? address;
  final String? phone;
  final String? header;
  final String? footer;
  final bool showQr;
  final bool showMxik;
  final int paperWidth; // 58 yoki 80
  /// Yuklab olingan logo faylining xom baytlari (PNG/JPG/WebP).
  /// Chek chop etishdan oldin printer-service uni yuklaydi.
  final List<int>? logoBytes;

  const ReceiptData({
    required this.restaurantName,
    this.terminalName,
    this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.payments,
    this.fiscal,
    required this.createdAt,
    this.legalName,
    this.inn,
    this.address,
    this.phone,
    this.header,
    this.footer,
    this.showQr = true,
    this.showMxik = true,
    this.paperWidth = 80,
    this.logoBytes,
  });

  ReceiptData copyWith({List<int>? logoBytes}) => ReceiptData(
        restaurantName: restaurantName,
        terminalName: terminalName,
        orderNumber: orderNumber,
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        payments: payments,
        fiscal: fiscal,
        createdAt: createdAt,
        legalName: legalName,
        inn: inn,
        address: address,
        phone: phone,
        header: header,
        footer: footer,
        showQr: showQr,
        showMxik: showMxik,
        paperWidth: paperWidth,
        logoBytes: logoBytes ?? this.logoBytes,
      );

  /// True if any line carries an MXIK code AND user wants MXIK shown.
  bool get hasMxik => showMxik && items.any((i) => (i.mxikCode ?? '').isNotEmpty);
}
