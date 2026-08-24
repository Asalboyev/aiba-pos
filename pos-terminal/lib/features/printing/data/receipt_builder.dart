import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/money.dart';
import '../domain/receipt_data.dart';

/// Builds the ESC/POS byte stream for a [ReceiptData], including the fiscal QR.
///
/// O'lcham nazorati qat'iy: HAR BIR qator to'liq (o'lcham + qalinlik + font +
/// hizalanish) stil bilan bosiladi — hech bir qator oldingi qatorning "katta"
/// stilini meros qilib olmaydi (arzon printerlarda style-bleed muammosi).
/// Ustunlar PosColumn'ga emas, qog'oz kengligidan hisoblangan aniq belgilar
/// soniga (58mm = 32, 80mm = 48) probel bilan tekislanadi — yaxlitlash
/// xatosiz, o'ng ustun har doim o'ng chetga tegib turadi.
class ReceiptBuilder {
  // Font A da bir qatorga sig'adigan belgilar: 58mm → 32, 80mm → 48.
  static int _cols(int paperWidth) => paperWidth == 58 ? 32 : 48;

  // ── to'liq stillar (har chaqiriqda hammasi aniq ko'rsatiladi) ──────────────
  static const _normal = PosStyles(
    align: PosAlign.left,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _center = PosStyles(
    align: PosAlign.center,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _centerBold = PosStyles(
    align: PosAlign.center,
    bold: true,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _title = PosStyles(
    align: PosAlign.center,
    bold: true,
    height: PosTextSize.size2, // balandligi 2x, ENI 1x — uzun nom ham sig'adi
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _big = PosStyles(
    align: PosAlign.left,
    bold: true,
    height: PosTextSize.size2,
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _small = PosStyles(
    align: PosAlign.center,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontB, // mayda texnik satrlar (FP, izohlar)
  );
  static const _smallLeft = PosStyles(
    align: PosAlign.left,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontB, // MXIK — mahsulot qatori tagida, chapda
  );

  /// Chap + o'ng juftlikni qog'oz kengligiga probel bilan tekislaydi.
  static String _pair(String left, String right, int cols) {
    var l = left;
    final space = cols - right.length;
    if (space < 1) return '$l $right'; // juda uzun — hech qursa ajratib beramiz
    if (l.length > space - 1) l = l.substring(0, space - 1);
    return l + ' ' * (space - l.length) + right;
  }

  /// Uzun nomni qog'oz kengligiga so'zma-so'z o'raydi.
  static List<String> _wrap(String text, int cols) {
    final words = text.split(' ');
    final lines = <String>[];
    var cur = StringBuffer();
    for (final w in words) {
      if (cur.isEmpty) {
        cur.write(w);
      } else if (cur.length + 1 + w.length <= cols) {
        cur.write(' $w');
      } else {
        lines.add(cur.toString());
        cur = StringBuffer(w);
      }
    }
    if (cur.isNotEmpty) lines.add(cur.toString());
    // Yakka so'z qatordan uzun bo'lsa — majburan kesamiz.
    return lines
        .expand((l) => l.length <= cols
            ? [l]
            : [for (var i = 0; i < l.length; i += cols) l.substring(i, (i + cols).clamp(0, l.length))])
        .toList();
  }

  /// Build the raw command bytes. Paper width comes from adminka sozlamalari
  /// (58 yoki 80 mm) — barcha ustun/chiziqlar shu kenglikdan hisoblanadi.
  static Future<List<int>> build(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final paperSize = data.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final cols = _cols(data.paperWidth);
    final g = Generator(paperSize, profile);
    final bytes = <int>[];

    final thin = '-' * cols;
    final thick = '=' * cols;

    bytes.addAll(g.reset());

    // ── TO'LOV KODI cheki (1-chek) ────────────────────────────────────────────
    // Mijoz skanerlab to'laydigan chek. Fiskal EMAS — to'lov o'tgach ikkinchi,
    // fiskal chek chiqadi.
    final payQr = data.paymentQrUrl;
    final isPaySlip = payQr != null && payQr.isNotEmpty;
    if (isPaySlip) {
      bytes.addAll(g.text('=' * cols, styles: _normal));
      bytes.addAll(g.text('TO\'LOV UCHUN', styles: _title));
      bytes.addAll(g.text('FISKAL CHEK EMAS', styles: _centerBold));
      bytes.addAll(g.text('=' * cols, styles: _normal));
      bytes.addAll(g.feed(1));
    }

    // ── XATO CHEK banneri ─────────────────────────────────────────────────────
    // Chek xato deb belgilangan bo'lsa — eng boshida katta yozuv: chekni
    // ko'rgan odam (tekshiruvchi/buxgalter) darhol farqlaydi.
    if (data.isErrorCheck) {
      final no = (data.orderNumber ?? '').replaceAll('#', '');
      bytes.addAll(g.text('*' * cols, styles: _normal));
      bytes.addAll(g.text('XATO CHEK', styles: _title));
      if (no.isNotEmpty) {
        bytes.addAll(g.text('CHEK RAQAMI: $no', styles: _centerBold));
      }
      if ((data.errorReason ?? '').isNotEmpty) {
        bytes.addAll(g.text('Sabab: ${data.errorReason}', styles: _center));
      }
      bytes.addAll(g.text('BU CHEK HISOBGA OLINMAYDI', styles: _centerBold));
      bytes.addAll(g.text('*' * cols, styles: _normal));
      bytes.addAll(g.feed(1));
    } else if ((data.replacesErrorNumber ?? '').isNotEmpty) {
      // To'g'irlangan chek. Raqam xato chek bilan BIR XIL bo'lsa (odatiy
      // holat) — shunchaki "TO'G'IRLANGAN CHEK"; boshqa raqam bo'lsa
      // qaysi chek o'rniga ekani ham yoziladi.
      final same = (data.replacesErrorNumber ?? '') ==
          (data.orderNumber ?? '').replaceAll('#', '');
      bytes.addAll(g.text('=' * cols, styles: _normal));
      bytes.addAll(g.text('TO\'G\'IRLANGAN CHEK', styles: _title));
      bytes.addAll(g.text(
          same
              ? 'Oldingi urinish XATO — shu chek to\'g\'ri'
              : 'XATO CHEK № ${data.replacesErrorNumber} o\'rniga',
          styles: _centerBold));
      bytes.addAll(g.text('=' * cols, styles: _normal));
      bytes.addAll(g.feed(1));
    }

    // ── Sarlavha ──────────────────────────────────────────────────────────────
    if (data.logoBytes != null && data.logoBytes!.isNotEmpty) {
      try {
        final decoded = img.decodeImage(data.logoBytes!);
        if (decoded != null) {
          final maxW = data.paperWidth == 58 ? 300 : 480;
          final resized =
              decoded.width > maxW ? img.copyResize(decoded, width: maxW) : decoded;
          bytes.addAll(g.image(resized, align: PosAlign.center));
        }
      } catch (_) {
        // Rasm buzuq bo'lsa jimgina o'tkazamiz — matn hech qursa chiqsin.
      }
    }

    bytes.addAll(g.text(data.restaurantName, styles: _title));
    if ((data.legalName ?? '').isNotEmpty && data.legalName != data.restaurantName) {
      bytes.addAll(g.text(data.legalName!, styles: _center));
    }
    if ((data.inn ?? '').isNotEmpty) {
      bytes.addAll(g.text('INN: ${data.inn}', styles: _center));
    }
    if ((data.address ?? '').isNotEmpty) {
      for (final l in _wrap(data.address!, cols)) {
        bytes.addAll(g.text(l, styles: _center));
      }
    }
    if ((data.phone ?? '').isNotEmpty) {
      bytes.addAll(g.text('Tel: ${data.phone}', styles: _center));
    }
    if ((data.header ?? '').isNotEmpty) {
      bytes.addAll(g.text(data.header!, styles: _centerBold));
    }

    bytes.addAll(g.text(thin, styles: _normal));

    // Chek raqami katta — mijoz navbatini shu raqam bilan kutadi.
    if (data.orderNumber != null) {
      bytes.addAll(g.text('Chek #${data.orderNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
            fontType: PosFontType.fontA,
          )));
    }
    bytes.addAll(g.text(
      _pair(data.terminalName ?? '', _formatDate(data.createdAt), cols),
      styles: _normal,
    ));

    bytes.addAll(g.text(thick, styles: _normal));

    // ── Mahsulotlar ───────────────────────────────────────────────────────────
    for (final item in data.items) {
      for (final l in _wrap(item.name, cols)) {
        bytes.addAll(g.text(l,
            styles: const PosStyles(
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              fontType: PosFontType.fontA,
            )));
      }
      bytes.addAll(g.text(
        _pair('  ${_qty(item.qty)} x ${Money.format(item.price)}',
            Money.format(item.lineTotal), cols),
        styles: _normal,
      ));
      if (data.showMxik && (item.mxikCode ?? '').isNotEmpty) {
        bytes.addAll(g.text('  MXIK: ${item.mxikCode}', styles: _smallLeft));
      }
    }

    bytes.addAll(g.text(thin, styles: _normal));

    // ── Jami ──────────────────────────────────────────────────────────────────
    bytes.addAll(g.text(_pair('Oraliq', Money.format(data.subtotal), cols),
        styles: _normal));
    if (data.discount > 0) {
      bytes.addAll(g.text(_pair('Chegirma', '-${Money.format(data.discount)}', cols),
          styles: _normal));
    }
    bytes.addAll(g.text(_pair('JAMI', Money.formatSom(data.total), cols),
        styles: _big));

    bytes.addAll(g.text(thin, styles: _normal));

    // ── To'lovlar ─────────────────────────────────────────────────────────────
    for (final p in data.payments) {
      bytes.addAll(g.text(_pair(p.label, Money.format(p.amount), cols),
          styles: _normal));
    }

    if (data.hasMxik) {
      bytes.addAll(g.text('Tovarlar MXIK kodlari bilan fiskalizatsiya qilindi',
          styles: _small));
    }

    // ── TO'LOV KODI QR (1-chek) — mijoz shu QR'ni skanerlab to'laydi ─────────
    if (isPaySlip) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text('TO\'LOV KODI', styles: _title));
      bytes.addAll(g.qrcode(payQr,
          size: data.paperWidth == 58 ? QRSize.Size6 : QRSize.Size7));
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text('Payme / Click / Uzum bilan skanerlab to\'lang',
          styles: _center));
      bytes.addAll(g.text('To\'lovdan so\'ng fiskal chek avtomatik chiqadi',
          styles: _small));
      if ((data.footer ?? '').isNotEmpty) {
        bytes.addAll(g.feed(1));
        bytes.addAll(g.text(data.footer!, styles: _center));
      }
      bytes.addAll(g.feed(2));
      bytes.addAll(g.cut());
      return bytes;
    }

    // ── Soliq QR ──────────────────────────────────────────────────────────────
    final qr = data.fiscal?.qrUrl;
    if (data.showQr && qr != null && qr.isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text('Soliq cheki (QR)', styles: _centerBold));
      bytes.addAll(g.qrcode(qr,
          size: data.paperWidth == 58 ? QRSize.Size5 : QRSize.Size6));
      if ((data.fiscal?.fiscalSign ?? '').isNotEmpty) {
        bytes.addAll(g.feed(1));
        bytes.addAll(g.text('FP: ${data.fiscal!.fiscalSign}', styles: _small));
      }
    } else if (data.fiscal != null && !data.fiscal!.isSuccess) {
      bytes.addAll(g.feed(1));
      bytes.addAll(
          g.text('Fiskalizatsiya: ${data.fiscal!.status}', styles: _center));
    }

    if ((data.footer ?? '').isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(g.text(data.footer!, styles: _centerBold));
    }
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());

    return bytes;
  }

  /// Short hardware test ticket (used by the Settings "Test chek" button).
  ///
  /// Ikkala kenglik uchun "o'lchagich" chiziq bosadi: qaysi chiziq qog'ozga
  /// aniq sig'sa — adminkada o'sha kenglikni tanlash kerak (58 yoki 80).
  /// QR to'lov taloni (fiskal EMAS): mijoz skanerlashi uchun WLCM checkout QR.
  static Future<List<int>> buildQrSlip({
    required String url,
    required num amount,
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paperSize, profile);
    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(g.text('QR ORQALI TO\'LOV', styles: _title));
    bytes.addAll(g.text(_formatDate(DateTime.now()), styles: _center));
    bytes.addAll(g.text('-' * _cols(paperWidth), styles: _normal));
    bytes.addAll(g.text('Summa: ${Money.formatSom(amount)}', styles: _big));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.qrcode(url,
        size: paperWidth == 58 ? QRSize.Size6 : QRSize.Size7));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.text('Payme / Click / Uzum bilan skanerlab to\'lang',
        styles: _center));
    bytes.addAll(g.text('To\'lovdan so\'ng chek avtomatik chiqadi',
        styles: _small));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static Future<List<int>> buildTest({int paperWidth = 80}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paperSize, profile);
    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(g.text('AIBA POS', styles: _title));
    bytes.addAll(g.text('Printer test — ${paperWidth}mm rejim', styles: _center));
    bytes.addAll(g.text(_formatDate(DateTime.now()), styles: _center));
    bytes.addAll(g.text('-' * _cols(paperWidth), styles: _normal));
    // O'lchagichlar: to'g'ri kenglikda oxirgi belgi o'ng chetga tegib turadi.
    bytes.addAll(g.text('80mm o\'lchagich (48):', styles: _normal));
    bytes.addAll(g.text('123456789012345678901234567890123456789012345678',
        styles: _normal));
    bytes.addAll(g.text('58mm o\'lchagich (32):', styles: _normal));
    bytes.addAll(g.text('12345678901234567890123456789012', styles: _normal));
    bytes.addAll(g.text('-' * _cols(paperWidth), styles: _normal));
    bytes.addAll(g.text('Qaysi chiziq chetga tegsa —', styles: _center));
    bytes.addAll(g.text('adminkada o\'sha kenglikni tanlang.', styles: _center));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static String _qty(num q) =>
      q == q.truncate() ? q.truncate().toString() : q.toString();

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
