import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../auth/domain/entities/auth_session.dart';

/// Oflayn fiskal — internet (Nex serveri) uzilganda chekni KASSADAGI E-POS
/// Communicator orqali to'g'ridan-to'g'ri fiskalizatsiya qiladi. Communicator
/// lokal (localhost:8347) bo'lgani uchun internetga bog'liq emas.
///
/// Payload servisdagi `pos_fiscal::epos_sale_payload` bilan AYNAN bir xil
/// quriladi (tiyin, har qator amount=1000 + price=qator jami, chegirma
/// taqsimoti, QQS). `externalID` sifatida buyurtmaning `client_uuid`i
/// ishlatiladi — takror urinishlar idempotent.
///
/// Natija (`offline_fiscal` xaritasi) pending buyurtma payload'iga yoziladi;
/// internet qaytib sync bo'lganda server uni qabul qilib chekni 'sent' deb
/// belgilaydi — IKKINCHI marta fiskalizatsiya bo'lmaydi.
class OfflineFiscalService {
  OfflineFiscalService(this._config);

  final AppConfig _config;

  /// E-POS protokolining qat'iy tokeni (hamma uchun bir xil, dok bo'yicha).
  static const fixedToken = 'DXJFX32CN1296678504F2';
  static const _port = '3448';

  final Dio _local = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Muvaffaqiyatda `offline_fiscal` xaritasini qaytaradi, aks holda null
  /// (chek fiskalsiz chiqadi, keyin server relay orqali yuboriladi).
  Future<Map<String, dynamic>?> fiscalize({
    required Map<String, dynamic> orderIn,
    required RestaurantInfo restaurant,
    String? staffName,
  }) async {
    try {
      final payload = _salePayload(orderIn, restaurant, staffName);
      final externalId = payload['externalID'] as String;

      var resp = await _post(payload);
      if (resp != null && _isError(resp)) {
        final msg = _errText(resp);
        if (msg.contains('ZReport')) {
          // Smena yopiq — avto-ochib qayta uramiz (server relay bilan bir xil).
          final z = await _post({
            'token': fixedToken,
            'method': 'openZreport',
            'port': _port,
          });
          if (z != null && !_isError(z)) resp = await _post(payload);
        } else if (msg.contains('DUPLICATE_EXTERNAL_ID')) {
          return _fromCheck(await _post({
            'token': fixedToken,
            'method': 'checkReceiptIfExists',
            'external_id': externalId,
          }), externalId);
        }
      }
      if (resp == null || _isError(resp)) {
        debugPrint('[OfflineFiscal] xato: ${resp == null ? 'aloqa yo\'q' : _errText(resp)}');
        return null;
      }
      // Server `interpret_epos` bilan bir xil: info/message obyekt bo'lsa o'sha.
      var m = resp;
      for (final k in const ['info', 'message']) {
        if (resp[k] is Map) {
          m = (resp[k] as Map).cast<String, dynamic>();
          break;
        }
      }
      final sign = _numStr(m['fiscalSign']);
      if (sign.isEmpty) return null;
      final terminal = _numStr(m['terminalId']);
      final seq = _numStr(m['receiptSeq']);
      return {
        'external_id': externalId,
        'fiscal_sign': sign,
        'fiscal_id': terminal.isNotEmpty && seq.isNotEmpty ? '$terminal:$seq' : seq,
        'qr_url': m['qrCodeURL']?.toString(),
        'raw_response': resp,
      };
    } catch (e) {
      debugPrint('[OfflineFiscal] fiscalize failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(Map<String, dynamic> payload) async {
    try {
      final r = await _local.post<dynamic>(_config.communicatorUrl, data: payload);
      return r.data is Map ? (r.data as Map).cast<String, dynamic>() : null;
    } on DioException catch (e) {
      final body = e.response?.data;
      return body is Map ? body.cast<String, dynamic>() : null;
    }
  }

  static bool _isError(Map<String, dynamic> d) =>
      d['error'] == true || d['error'] is String;

  static String _errText(Map<String, dynamic> d) =>
      (d['message'] ?? '').toString();

  static String _numStr(dynamic v) =>
      v == null ? '' : (v is num ? v.toString() : v.toString());

  Map<String, dynamic>? _fromCheck(Map<String, dynamic>? resp, String externalId) {
    final data = resp?['data'];
    if (data is! Map || data['exists'] != true) return null;
    final r = data['receipt'];
    if (r is! Map) return null;
    final terminal = _numStr(r['terminal_id']);
    final seq = _numStr(r['receipt_seq']);
    return {
      'external_id': externalId,
      'fiscal_sign': _numStr(r['fiscal_sign']),
      'fiscal_id': terminal.isNotEmpty && seq.isNotEmpty ? '$terminal:$seq' : seq,
      'qr_url': r['qr_code_url']?.toString(),
      'raw_response': resp,
    };
  }

  // ── payload qurish — pos_fiscal::epos_sale_payload'ning Dart nusxasi ──────

  static int _tiyin(num somValue) => (somValue * 100).round();

  Map<String, dynamic> _salePayload(
    Map<String, dynamic> orderIn,
    RestaurantInfo r,
    String? staffName,
  ) {
    final rawItems = (orderIn['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    // Qator jamlari (tiyin): server total = round2(price*qty) ni tiyinlaydi.
    final lineTotals = <int>[];
    for (final it in rawItems) {
      final price = (it['price'] as num?) ?? 0;
      final qty = (it['qty'] as num?) ?? 1;
      final total = (price * qty * 100).roundToDouble() / 100; // round2 (so'm)
      lineTotals.add(_tiyin(total));
    }

    // Chegirma proporsional taqsimoti, qoldiq oxirgi qatorga (server bilan bir xil).
    final discountTiyin = _tiyin((orderIn['discount'] as num?) ?? 0);
    final discounts = List<int>.filled(lineTotals.length, 0);
    final sum = lineTotals.fold<int>(0, (a, b) => a + b);
    if (discountTiyin > 0 && sum > 0) {
      var acc = 0;
      for (var i = 0; i < lineTotals.length; i++) {
        discounts[i] = (discountTiyin * lineTotals[i] / sum).round();
        acc += discounts[i];
      }
      discounts[discounts.length - 1] += discountTiyin - acc;
    }

    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < rawItems.length; i++) {
      final it = rawItems[i];
      final vatPercent = ((it['vat_percent'] as num?) ?? 12).toDouble();
      final totalTiyin = lineTotals[i];
      // QQS jami ichida: total × p / (100 + p). Server so'mda hisoblab
      // tiyinlagani uchun aynan shu tartibda hisoblaymiz.
      final totalSom = totalTiyin / 100;
      final vat = vatPercent == 0
          ? 0
          : (totalSom * vatPercent / (100 + vatPercent) * 100).round();
      items.add({
        'name': it['name'] ?? '',
        // Bir qator = 1 birlik: price = qator jami (tiyin), amount = 1000.
        'amount': 1000,
        'price': totalTiyin,
        'vatPercent': vatPercent,
        'vat': vat,
        'classCode': it['mxik_code'] ?? '',
        'packageCode': it['package_code'] ?? '',
        'barcode': it['barcode'] ?? '',
        'label': it['label'] ?? '',
        'discount': discounts[i],
        'other': 0,
        'ownerType': 0,
      });
    }

    num cash = 0, card = 0;
    for (final p in (orderIn['payments'] as List? ?? const [])) {
      if (p is! Map) continue;
      final amount = (p['amount'] as num?) ?? 0;
      final method = (p['method'] ?? '').toString();
      if (method == 'cash') {
        cash += amount;
      } else if (method == 'card' || method == 'qr') {
        card += amount;
      }
    }

    final clientUuid = (orderIn['client_uuid'] ?? '').toString();
    final number = (orderIn['number'] ?? '').toString().isNotEmpty
        ? orderIn['number'].toString()
        : clientUuid.replaceAll('-', '').substring(0, 8).toUpperCase();
    final companyName =
        (r.legalName != null && r.legalName!.trim().isNotEmpty) ? r.legalName! : r.name;

    return {
      'token': fixedToken,
      'method': 'sale',
      'externalID': clientUuid,
      'orderNumber': number,
      'companyName': companyName,
      'companyINN': r.inn ?? '',
      'companyAddress': r.address ?? '',
      'staffName': staffName ?? '',
      'params': {
        'items': items,
        'receivedCash': _tiyin(cash),
        'receivedCard': _tiyin(card),
        'paycheckNumber': number,
      },
    };
  }
}
