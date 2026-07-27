import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

/// Fiskal ko'prik — "E-POS (kassa orqali)" rejimi.
///
/// Prod'da E-POS Communicator kassa kompyuterining `localhost:8347` portida
/// ishlaydi va bulutdagi Nex serveri unga yeta olmaydi. Shuning uchun server
/// chekni navbatga qo'yadi, bu servis esa:
///   1. serverdan tayyor payload'larni oladi (GET fiscal/jobs);
///   2. ularni shu kompyuterdagi Communicator'ga POST qiladi;
///   3. javobni serverga qaytaradi (POST fiscal/jobs/:id/result) — server
///      talqin qilib, kerak bo'lsa keyingi qadamni beradi (Z-ochish,
///      duplicate tekshiruvi) va biz shu zanjirni davom ettiramiz.
class FiscalBridgeService {
  FiscalBridgeService(this._client, this._config);

  final DioClient _client;
  final AppConfig _config;

  /// Communicator lokal va tez — qisqa timeout kifoya (fiskal modul o'zi
  /// sekin javob berishi mumkin, shuning uchun receive 30s).
  final Dio _local = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  bool _running = false;

  /// Bitta zanjirda serverdan keladigan eng ko'p qadam (sale → zopen → sale
  /// → check) — himoya chegarasi.
  static const _maxHops = 4;

  /// Navbatdagi barcha cheklarni yuborishga urinadi; yakunlanganlar sonini
  /// qaytaradi. Parallel chaqiruvlarga qarshi himoyalangan (no-op).
  Future<int> run() async {
    if (_running) return 0;
    _running = true;
    try {
      final res = await _client
          .get<Map<String, dynamic>>('/api/v2/pos-terminal/fiscal/jobs');
      final jobs = (res.data?['jobs'] as List?) ?? const [];
      var done = 0;
      for (final j in jobs) {
        if (j is! Map) continue;
        if (await _runJob(j.cast<String, dynamic>())) done++;
      }
      if (jobs.isNotEmpty) {
        debugPrint('[FiscalBridge] ${jobs.length} ta chek, $done ta yuborildi');
      }
      return done;
    } catch (e) {
      debugPrint('[FiscalBridge] run failed: $e');
      return 0;
    } finally {
      _running = false;
    }
  }

  /// Smena ochish/yopishda backend qaytargan relay payload'ini Communicator'ga
  /// yuboradi (best-effort — natija serverga qaytarilmaydi, sotuv oqimi
  /// baribir Z-report xatosini o'zi tuzatadi).
  Future<void> fireRelay(Map<String, dynamic>? epos) async {
    final relay = epos?['relay'];
    if (relay is! Map) return;
    final payload = relay['payload'];
    if (payload == null) return;
    try {
      await _local.post<dynamic>(_config.communicatorUrl, data: payload);
      debugPrint('[FiscalBridge] relay ${relay['kind']} yuborildi');
    } catch (e) {
      debugPrint('[FiscalBridge] relay ${relay['kind']} failed: $e');
    }
  }

  Future<bool> _runJob(Map<String, dynamic> job) async {
    final id = job['receipt_id']?.toString();
    if (id == null || id.isEmpty) return false;
    var kind = job['kind']?.toString() ?? 'sale';
    Object? payload = job['payload'];

    for (var hop = 0; hop < _maxHops; hop++) {
      // 1) Communicator'ga yuborish.
      Map<String, dynamic> resultBody;
      try {
        final r =
            await _local.post<dynamic>(_config.communicatorUrl, data: payload);
        final data = r.data;
        resultBody = {
          'kind': kind,
          'response': data is Map ? data : {'error': true, 'message': '$data'},
        };
      } on DioException catch (e) {
        final body = e.response?.data;
        if (body is Map) {
          // Communicator xatoni JSON qilib qaytardi — server talqin qiladi.
          resultBody = {'kind': kind, 'response': body};
        } else {
          resultBody = {
            'kind': kind,
            'transport_error':
                'E-POS Communicator bilan aloqa yo\'q (${_config.communicatorUrl}): ${e.message}',
          };
        }
      }

      // 2) Natijani serverga qaytarish; server keyingi qadamni beradi.
      final res = await _client.post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/fiscal/jobs/$id/result',
        data: resultBody,
      );
      final data = res.data ?? const {};
      if (data['done'] == true) return true;
      final next = data['next'];
      if (next is! Map) return false;
      kind = next['kind']?.toString() ?? 'sale';
      payload = next['payload'];
    }
    return false;
  }
}
