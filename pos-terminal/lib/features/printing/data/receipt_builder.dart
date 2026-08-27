import 'dart:typed_data';

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

  // ── Matn kodlash ───────────────────────────────────────────────────────────
  // Generator.text() Latin-1 ga kodlaydi va KIRILL harflar yoki tipografik
  // belgilar («—», «’») uchrasa EXCEPTION otadi — chek umuman chiqmasdi.
  // Yechim: belgilarni tozalab, CP866 (kirill kodlash, ESC t 17) bilan
  // baytlarga o'girib textEncoded orqali yuboramiz. Har belgi = 1 bayt,
  // shuning uchun ustun tekislash (padding) matematikasi buzilmaydi.

  /// ESC t 17 — CP866 kod jadvalini tanlash (Xprinter/ESC-POS standarti).
  static const cp866Select = [0x1B, 0x74, 0x11];

  static const Map<String, String> _replace = {
    '—': '-', '–': '-', '―': '-',
    '‘': "'", '’': "'", '‚': "'", 'ʻ': "'", 'ʼ': "'",
    '“': '"', '”': '"', '„': '"', '«': '"', '»': '"',
    '…': '...', '·': '*', '•': '*', '№': 'No', '×': 'x',
    '✓': '+', '⟳': '@', ' ': ' ',
    'қ': 'k', 'Қ': 'K', 'ғ': 'g', 'Ғ': 'G', 'ҳ': 'h', 'Ҳ': 'H',
  };

  static String _sanitize(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_replace[ch] ?? ch);
    }
    return b.toString();
  }

  /// CP866 kodlash: ASCII o'z holicha, kirill — jadval bo'yicha, qolgan
  /// nstandart belgi '?' bo'ladi (exception YO'Q — chek doim chiqadi).
  static Uint8List _enc(String s) {
    final out = <int>[];
    for (final r in _sanitize(s).runes) {
      if (r < 0x80) {
        out.add(r);
      } else if (r >= 0x410 && r <= 0x42F) {
        out.add(0x80 + (r - 0x410)); // А-Я
      } else if (r >= 0x430 && r <= 0x43F) {
        out.add(0xA0 + (r - 0x430)); // а-п
      } else if (r >= 0x440 && r <= 0x44F) {
        out.add(0xE0 + (r - 0x440)); // р-я
      } else if (r == 0x401) {
        out.add(0xF0); // Ё
      } else if (r == 0x451) {
        out.add(0xF1); // ё
      } else if (r == 0x40E) {
        out.add(0xF6); // Ў
      } else if (r == 0x45E) {
        out.add(0xF7); // ў
      } else {
        out.add(0x3F); // ?
      }
    }
    return Uint8List.fromList(out);
  }

  /// _tx(g, ) o'rnini bosuvchi XAVFSIZ chiqarish (CP866, exception'siz).
  static List<int> _tx(Generator g, String text,
      {PosStyles styles = const PosStyles()}) {
    return g.textEncoded(_enc(text), styles: styles);
  }

  // ── to'liq stillar (har chaqiriqda hammasi aniq ko'rsatiladi) ──────────────
  static const _normal = PosStyles(
    align: PosAlign.left,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    fontType: PosFontType.fontA,
  );
  static const _bold = PosStyles(
    align: PosAlign.left,
    bold: true,
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
    bytes.addAll(cp866Select);

    // ── TO'LOV KODI cheki (1-chek) ────────────────────────────────────────────
    // Mijoz skanerlab to'laydigan chek. Fiskal EMAS — to'lov o'tgach ikkinchi,
    // fiskal chek chiqadi.
    final payQr = data.paymentQrUrl;
    final isPaySlip = payQr != null && payQr.isNotEmpty;
    if (isPaySlip) {
      bytes.addAll(_tx(g, '=' * cols, styles: _normal));
      bytes.addAll(_tx(g, 'TO\'LOV UCHUN', styles: _title));
      bytes.addAll(_tx(g, 'FISKAL CHEK EMAS', styles: _centerBold));
      bytes.addAll(_tx(g, '=' * cols, styles: _normal));
      bytes.addAll(g.feed(1));
    }

    // ── XATO CHEK banneri ─────────────────────────────────────────────────────
    // Chek xato deb belgilangan bo'lsa — eng boshida katta yozuv: chekni
    // ko'rgan odam (tekshiruvchi/buxgalter) darhol farqlaydi.
    if (data.isErrorCheck) {
      final no = (data.orderNumber ?? '').replaceAll('#', '');
      bytes.addAll(_tx(g, '*' * cols, styles: _normal));
      bytes.addAll(_tx(g, 'XATO CHEK', styles: _title));
      if (no.isNotEmpty) {
        bytes.addAll(_tx(g, 'CHEK RAQAMI: $no', styles: _centerBold));
      }
      if ((data.errorReason ?? '').isNotEmpty) {
        bytes.addAll(_tx(g, 'Sabab: ${data.errorReason}', styles: _center));
      }
      bytes.addAll(_tx(g, 'BU CHEK HISOBGA OLINMAYDI', styles: _centerBold));
      bytes.addAll(_tx(g, '*' * cols, styles: _normal));
      bytes.addAll(g.feed(1));
    } else if ((data.replacesErrorNumber ?? '').isNotEmpty) {
      // To'g'irlangan chek. Raqam xato chek bilan BIR XIL bo'lsa (odatiy
      // holat) — shunchaki "TO'G'IRLANGAN CHEK"; boshqa raqam bo'lsa
      // qaysi chek o'rniga ekani ham yoziladi.
      final same = (data.replacesErrorNumber ?? '') ==
          (data.orderNumber ?? '').replaceAll('#', '');
      bytes.addAll(_tx(g, '=' * cols, styles: _normal));
      bytes.addAll(_tx(g, 'TO\'G\'IRLANGAN CHEK', styles: _title));
      bytes.addAll(_tx(g, 
          same
              ? 'Oldingi urinish XATO — shu chek to\'g\'ri'
              : 'XATO CHEK № ${data.replacesErrorNumber} o\'rniga',
          styles: _centerBold));
      bytes.addAll(_tx(g, '=' * cols, styles: _normal));
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

    bytes.addAll(_tx(g, data.restaurantName, styles: _title));
    if ((data.legalName ?? '').isNotEmpty && data.legalName != data.restaurantName) {
      bytes.addAll(_tx(g, data.legalName!, styles: _center));
    }
    if ((data.inn ?? '').isNotEmpty) {
      bytes.addAll(_tx(g, 'INN: ${data.inn}', styles: _center));
    }
    if ((data.address ?? '').isNotEmpty) {
      for (final l in _wrap(data.address!, cols)) {
        bytes.addAll(_tx(g, l, styles: _center));
      }
    }
    if ((data.phone ?? '').isNotEmpty) {
      bytes.addAll(_tx(g, 'Tel: ${data.phone}', styles: _center));
    }
    if ((data.header ?? '').isNotEmpty) {
      bytes.addAll(_tx(g, data.header!, styles: _centerBold));
    }

    bytes.addAll(_tx(g, thin, styles: _normal));

    // Chek raqami katta — mijoz navbatini shu raqam bilan kutadi.
    if (data.orderNumber != null) {
      bytes.addAll(_tx(g, 'Chek #${data.orderNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
            fontType: PosFontType.fontA,
          )));
    }
    bytes.addAll(_tx(g, 
      _pair(data.terminalName ?? '', _formatDate(data.createdAt), cols),
      styles: _normal,
    ));

    bytes.addAll(_tx(g, thick, styles: _normal));

    // ── Mahsulotlar ───────────────────────────────────────────────────────────
    for (final item in data.items) {
      for (final l in _wrap(item.name, cols)) {
        bytes.addAll(_tx(g, l,
            styles: const PosStyles(
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              fontType: PosFontType.fontA,
            )));
      }
      bytes.addAll(_tx(g, 
        _pair('  ${_qty(item.qty)} x ${Money.format(item.price)}',
            Money.format(item.lineTotal), cols),
        styles: _normal,
      ));
      if (data.showMxik && (item.mxikCode ?? '').isNotEmpty) {
        bytes.addAll(_tx(g, '  MXIK: ${item.mxikCode}', styles: _smallLeft));
      }
    }

    bytes.addAll(_tx(g, thin, styles: _normal));

    // ── Jami ──────────────────────────────────────────────────────────────────
    bytes.addAll(_tx(g, _pair('Oraliq', Money.format(data.subtotal), cols),
        styles: _normal));
    if (data.discount > 0) {
      bytes.addAll(_tx(g, _pair('Chegirma', '-${Money.format(data.discount)}', cols),
          styles: _normal));
    }
    bytes.addAll(_tx(g, _pair('JAMI', Money.formatSom(data.total), cols),
        styles: _big));

    bytes.addAll(_tx(g, thin, styles: _normal));

    // ── To'lovlar ─────────────────────────────────────────────────────────────
    for (final p in data.payments) {
      bytes.addAll(_tx(g, _pair(p.label, Money.format(p.amount), cols),
          styles: _normal));
    }

    if (data.hasMxik) {
      bytes.addAll(_tx(g, 'Tovarlar MXIK kodlari bilan fiskalizatsiya qilindi',
          styles: _small));
    }

    // ── TO'LOV KODI QR (1-chek) — mijoz shu QR'ni skanerlab to'laydi ─────────
    if (isPaySlip) {
      bytes.addAll(g.feed(1));
      bytes.addAll(_tx(g, 'TO\'LOV KODI', styles: _title));
      bytes.addAll(g.qrcode(payQr,
          size: data.paperWidth == 58 ? QRSize.Size6 : QRSize.Size7));
      bytes.addAll(g.feed(1));
      bytes.addAll(_tx(g, 'Payme / Click / Uzum bilan skanerlab to\'lang',
          styles: _center));
      bytes.addAll(_tx(g, 'To\'lovdan so\'ng fiskal chek avtomatik chiqadi',
          styles: _small));
      if ((data.footer ?? '').isNotEmpty) {
        bytes.addAll(g.feed(1));
        bytes.addAll(_tx(g, data.footer!, styles: _center));
      }
      bytes.addAll(g.feed(2));
      bytes.addAll(g.cut());
      return bytes;
    }

    // ── Soliq QR ──────────────────────────────────────────────────────────────
    final qr = data.fiscal?.qrUrl;
    if (data.showQr && qr != null && qr.isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(_tx(g, 'Soliq cheki (QR)', styles: _centerBold));
      bytes.addAll(g.qrcode(qr,
          size: data.paperWidth == 58 ? QRSize.Size5 : QRSize.Size6));
      if ((data.fiscal?.fiscalSign ?? '').isNotEmpty) {
        bytes.addAll(g.feed(1));
        bytes.addAll(_tx(g, 'FP: ${data.fiscal!.fiscalSign}', styles: _small));
      }
    } else if (data.fiscal != null && !data.fiscal!.isSuccess) {
      bytes.addAll(g.feed(1));
      bytes.addAll(
          _tx(g, 'Fiskalizatsiya: ${data.fiscal!.status}', styles: _center));
    }

    if ((data.footer ?? '').isNotEmpty) {
      bytes.addAll(g.feed(1));
      bytes.addAll(_tx(g, data.footer!, styles: _centerBold));
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
    bytes.addAll(cp866Select);
    bytes.addAll(_tx(g, 'QR ORQALI TO\'LOV', styles: _title));
    bytes.addAll(_tx(g, _formatDate(DateTime.now()), styles: _center));
    bytes.addAll(_tx(g, '-' * _cols(paperWidth), styles: _normal));
    bytes.addAll(_tx(g, 'Summa: ${Money.formatSom(amount)}', styles: _big));
    bytes.addAll(g.feed(1));
    bytes.addAll(g.qrcode(url,
        size: paperWidth == 58 ? QRSize.Size6 : QRSize.Size7));
    bytes.addAll(g.feed(1));
    bytes.addAll(_tx(g, 'Payme / Click / Uzum bilan skanerlab to\'lang',
        styles: _center));
    bytes.addAll(_tx(g, 'To\'lovdan so\'ng chek avtomatik chiqadi',
        styles: _small));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  /// Z-HISOBOT cheki — smena yopilganda chiqadi: to'lov turlari kesimi,
  /// keldi-ketdi, rasxodlar, xato cheklar, kassa qoldig'i.
  static Future<List<int>> buildZReport({
    required String restaurantName,
    required String shiftName,
    required String? staffName,
    required DateTime? openedAt,
    required DateTime? closedAt,
    required int ordersCount,
    required num totalSales,
    required num cash,
    required num card,
    required num click,
    required num uzum,
    required num keldi,
    required num openingCash,
    required num expenses,
    required int errorChecks,
    num errorTotal = 0,
    num cashQrTotal = 0,
    int cashQrCount = 0,
    num cashNoQrTotal = 0,
    int cashNoQrCount = 0,
    List<ZItem> items = const [],
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paperSize, profile);
    final cols = _cols(paperWidth);
    final bytes = <int>[];
    // Ikki ustunli qator: chapda nom, o'ngda qiymat (probel bilan tekislangan).
    String row(String l, String r) {
      final pad = cols - l.length - r.length;
      return pad > 0 ? l + ' ' * pad + r : '$l $r';
    }

    // Markazlashgan bo'lim sarlavhasi: --- NOM ---
    String section(String t) {
      final side = (cols - t.length - 2) ~/ 2;
      final l = '-' * (side > 0 ? side : 0);
      final r = '-' * (cols - t.length - 2 - (side > 0 ? side : 0));
      return '$l $t $r';
    }

    bytes.addAll(g.reset());
    bytes.addAll(cp866Select);
    bytes.addAll(_tx(g, 'Z-HISOBOT', styles: _title));
    bytes.addAll(_tx(g, restaurantName, styles: _centerBold));
    if (shiftName.isNotEmpty) bytes.addAll(_tx(g, shiftName, styles: _center));
    bytes.addAll(_tx(g, '=' * cols, styles: _normal));
    if (openedAt != null) {
      bytes.addAll(
          _tx(g, row('Ochilgan:', _formatDate(openedAt.toLocal())), styles: _normal));
    }
    bytes.addAll(_tx(g, 
        row('Yopilgan:', _formatDate((closedAt ?? DateTime.now()).toLocal())),
        styles: _normal));
    if (staffName != null && staffName.isNotEmpty) {
      bytes.addAll(_tx(g, row('Yopdi:', staffName), styles: _normal));
    }
    bytes.addAll(_tx(g, section('SAVDO'), styles: _normal));
    bytes.addAll(_tx(g, row('Buyurtmalar', '$ordersCount ta'), styles: _normal));
    if (ordersCount > 0) {
      bytes.addAll(_tx(g,
          row('O\'rtacha chek', Money.formatSom(totalSales / ordersCount)),
          styles: _normal));
    }
    if (errorChecks > 0) {
      // Soni + summasi: rahbar «qancha pul xatoga urilgan»ni chekда ko'radi.
      bytes.addAll(_tx(g,
          row('Xato cheklar ($errorChecks ta)',
              '-${Money.formatSom(errorTotal)}'),
          styles: _normal));
    }
    bytes.addAll(
        _tx(g, row('JAMI SAVDO', Money.formatSom(totalSales)), styles: _bold));
    bytes.addAll(_tx(g, section('TO\'LOVLAR'), styles: _normal));
    // Nol qatorlar chekni cho'zmaydi — faqat bo'lgan to'lov turlari.
    if (cash != 0) {
      bytes.addAll(_tx(g, row('Naqd', Money.formatSom(cash)), styles: _normal));
    }
    if (card != 0) {
      bytes.addAll(_tx(g, row('Karta', Money.formatSom(card)), styles: _normal));
    }
    if (click != 0) {
      bytes.addAll(_tx(g, row('Click', Money.formatSom(click)), styles: _normal));
    }
    if (uzum != 0) {
      bytes.addAll(_tx(g, row('Uzum', Money.formatSom(uzum)), styles: _normal));
    }
    if (keldi != 0) {
      bytes.addAll(
          _tx(g, row('Keldi-ketdi', Money.formatSom(keldi)), styles: _normal));
    }
    if (cash == 0 && card == 0 && click == 0 && uzum == 0 && keldi == 0) {
      bytes.addAll(_tx(g, 'To\'lovlar bo\'lmagan', styles: _center));
    }
    // Naqd savdoning fiskal kesimi: menejer «naqdning qanchasi soliqda QR
    // olgan» summasini Z-chekда ham ko'radi (masalan 5 ta x 100 000 = 500 000).
    if (cashQrCount + cashNoQrCount > 0) {
      bytes.addAll(_tx(g,
          row('  Naqd QR bilan ($cashQrCount ta)', Money.formatSom(cashQrTotal)),
          styles: _normal));
      if (cashNoQrCount > 0) {
        bytes.addAll(_tx(g,
            row('  Naqd QRsiz ($cashNoQrCount ta)',
                Money.formatSom(cashNoQrTotal)),
            styles: _normal));
      }
    }
    bytes.addAll(_tx(g, section('KASSA'), styles: _normal));
    bytes.addAll(_tx(g, row('Boshlang\'ich kassa', Money.formatSom(openingCash)),
        styles: _normal));
    bytes.addAll(_tx(g, row('+ Naqd savdo', Money.formatSom(cash)), styles: _normal));
    if (expenses != 0) {
      bytes.addAll(
          _tx(g, row('- Rasxodlar', Money.formatSom(expenses)), styles: _normal));
    }
    bytes.addAll(_tx(g, 
        row('KASSADA NAQD', Money.formatSom(openingCash + cash - expenses)),
        styles: _bold));
    if (items.isNotEmpty) {
      bytes.addAll(_tx(g, section('SOTILGANLAR'), styles: _normal));
      for (final it in items) {
        // "3 x Osh" chapda, summasi o'ngda; uzun nom qisqartiriladi.
        final qty = _qty(it.qty);
        final amount = Money.formatSom(it.amount);
        var left = '$qty x ${it.name}';
        final maxLeft = cols - amount.length - 1;
        if (left.length > maxLeft && maxLeft > 3) {
          left = '${left.substring(0, maxLeft - 1)}.';
        }
        bytes.addAll(_tx(g, row(left, amount), styles: _normal));
      }
    }
    bytes.addAll(_tx(g, '=' * cols, styles: _normal));
    bytes.addAll(_tx(g, 'Smena yopildi', styles: _centerBold));
    bytes.addAll(_tx(g, _formatDate(DateTime.now()), styles: _center));
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
    bytes.addAll(cp866Select);
    bytes.addAll(_tx(g, 'AIBA POS', styles: _title));
    bytes.addAll(_tx(g, 'Printer test — ${paperWidth}mm rejim', styles: _center));
    bytes.addAll(_tx(g, _formatDate(DateTime.now()), styles: _center));
    bytes.addAll(_tx(g, '-' * _cols(paperWidth), styles: _normal));
    // O'lchagichlar: to'g'ri kenglikda oxirgi belgi o'ng chetga tegib turadi.
    bytes.addAll(_tx(g, '80mm o\'lchagich (48):', styles: _normal));
    bytes.addAll(_tx(g, '123456789012345678901234567890123456789012345678',
        styles: _normal));
    bytes.addAll(_tx(g, '58mm o\'lchagich (32):', styles: _normal));
    bytes.addAll(_tx(g, '12345678901234567890123456789012', styles: _normal));
    bytes.addAll(_tx(g, '-' * _cols(paperWidth), styles: _normal));
    bytes.addAll(_tx(g, 'Qaysi chiziq chetga tegsa —', styles: _center));
    bytes.addAll(_tx(g, 'adminkada o\'sha kenglikni tanlang.', styles: _center));
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

/// Z-hisobotdagi "Sotilganlar" qatori — smenada sotilgan mahsulot.
class ZItem {
  const ZItem({required this.name, required this.qty, required this.amount});
  final String name;
  final num qty;
  final num amount;
}
