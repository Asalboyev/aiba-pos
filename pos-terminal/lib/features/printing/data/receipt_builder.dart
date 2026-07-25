import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/money.dart';
import '../domain/receipt_data.dart';

/// Builds the ESC/POS byte stream for a [ReceiptData], including the fiscal QR.
class ReceiptBuilder {
  /// Build the raw command bytes. Paper width comes from adminka sozlamalari
  /// (58 yoki 80 mm). Boshqa sozlamalar ham data.header/footer/showQr/showMxik
  /// orqali kelib qatlanadi.
  static Future<List<int>> build(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final paperSize = data.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());

    // Logo — adminkada yuklangan bo'lsa, chek boshida markazda chop etamiz.
    // Baytlarni printer-service yuklab beradi (Dio orqali /static'dan).
    if (data.logoBytes != null && data.logoBytes!.isNotEmpty) {
      try {
        final decoded = img.decodeImage(data.logoBytes!);
        if (decoded != null) {
          // Qog'oz kengligi bo'yicha piksel maksimumi: 58mm≈384, 80mm≈576.
          final maxW = data.paperWidth == 58 ? 300 : 480;
          final resized = decoded.width > maxW
              ? img.copyResize(decoded, width: maxW)
              : decoded;
          bytes.addAll(g.image(resized, align: PosAlign.center));
        }
      } catch (_) {
        // Rasm buzuq bo'lsa jimgina o'tkazamiz — matn hech qursa chiqsin.
      }
    }

    // Restoran nomi — katta va qalin (adminkadagi "Chekdagi nomi")
    bytes.addAll(g.text(
      data.restaurantName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    // Yuridik nomi (agar boshqa bo'lsa)
    if ((data.legalName ?? '').isNotEmpty && data.legalName != data.restaurantName) {
      bytes.addAll(g.text(data.legalName!,
          styles: const PosStyles(align: PosAlign.center)));
    }
    // INN
    if ((data.inn ?? '').isNotEmpty) {
      bytes.addAll(g.text('INN: ${data.inn}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    // Manzil
    if ((data.address ?? '').isNotEmpty) {
      bytes.addAll(g.text(data.address!,
          styles: const PosStyles(align: PosAlign.center)));
    }
    // Telefon
    if ((data.phone ?? '').isNotEmpty) {
      bytes.addAll(g.text('Tel: ${data.phone}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    // Menejer belgilagan "Yuqori matn" (masalan "Xush kelibsiz!")
    if ((data.header ?? '').isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text(data.header!,
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    if (data.terminalName != null) {
      bytes.addAll(g.text(data.terminalName!,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (data.orderNumber != null) {
      // Buyurtma raqami — mijoz navbatini shu raqam bilan kutadi, shuning
      // uchun katta va qalin bosiladi.
      bytes.addAll(g.text('Buyurtma #${data.orderNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )));
    }
    bytes.addAll(g.text(_formatDate(data.createdAt),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.hr());

    // Items
    for (final item in data.items) {
      bytes.addAll(g.text(item.name, styles: const PosStyles(bold: true)));
      bytes.addAll(g.row([
        PosColumn(
          text: '${item.qty} x ${Money.format(item.price)}',
          width: 7,
        ),
        PosColumn(
          text: Money.format(item.lineTotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      if (data.showMxik && (item.mxikCode ?? '').isNotEmpty) {
        bytes.addAll(g.text('  MXIK: ${item.mxikCode}',
            styles: const PosStyles(fontType: PosFontType.fontB)));
      }
    }

    bytes.addAll(g.hr());

    // Totals
    bytes.addAll(_amountRow(g, 'Oraliq', data.subtotal));
    if (data.discount > 0) {
      bytes.addAll(_amountRow(g, 'Chegirma', -data.discount));
    }
    bytes.addAll(g.row([
      PosColumn(
        text: 'JAMI',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: Money.formatSom(data.total),
        width: 6,
        styles: const PosStyles(
            bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));

    bytes.addAll(g.hr());

    // Payments
    for (final p in data.payments) {
      bytes.addAll(_amountRow(g, p.method.label, p.amount));
    }

    // MXIK note
    if (data.hasMxik) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text("Tovarlar MXIK kodlari bilan fiskalizatsiya qilindi",
          styles: const PosStyles(
              align: PosAlign.center, fontType: PosFontType.fontB)));
    }

    // Soliq QR — faqat sozlamada yoqilgan bo'lsa chop etadi.
    final qr = data.fiscal?.qrUrl;
    if (data.showQr && qr != null && qr.isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text('Soliq QR',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(g.qrcode(qr, size: QRSize.Size6));
      if ((data.fiscal?.fiscalSign ?? '').isNotEmpty) {
        // QR bilan FP ustma-ust tushmasin uchun bir qator bo'shliq.
        bytes.addAll(g.feed(1));
        bytes.addAll(g.text('FP: ${data.fiscal!.fiscalSign}',
            styles: const PosStyles(
                align: PosAlign.center, fontType: PosFontType.fontB)));
      }
    } else if (data.fiscal != null && !data.fiscal!.isSuccess) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text('Fiskalizatsiya: ${data.fiscal!.status}',
          styles: const PosStyles(align: PosAlign.center)));
    }

    // Pastki matn (adminkada belgilanadi). Adminka bo'sh qoldirilsa,
    // chekda ham hech narsa chiqmaydi — default matn qo'shmaymiz.
    if ((data.footer ?? '').isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text(
        data.footer!,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    }
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());

    return bytes;
  }

  /// Short hardware test ticket (used by the Settings "Test chek" button).
  static Future<List<int>> buildTest() async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(g.text('AIBA POS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        )));
    bytes.addAll(g.text('Printer test',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text(_formatDate(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.hr());
    bytes.addAll(g.text('Agar bu chek chiqqan bo\'lsa,',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text('printer to\'g\'ri sozlangan.',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static List<int> _amountRow(Generator g, String label, num amount) {
    return g.row([
      PosColumn(text: label, width: 7),
      PosColumn(
        text: Money.format(amount),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
