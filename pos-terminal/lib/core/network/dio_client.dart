import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config/app_config.dart';
import '../errors/failure.dart';

/// ISRG (Let's Encrypt) ildiz sertifikatlari — ilova O'ZI bilan olib yuradi.
/// Yangilanmagan/aktivlashtirilmagan Windows kassalarда tizim ishonch
/// do'konida bu ildizlar yo'q va HTTPS «tarmoq xatosi» bilan yiqilardi.
/// main() da bir marta yuklanadi.
SecurityContext? _posSecurityContext;

Future<void> loadBundledRoots() async {
  try {
    final pem = await rootBundle.load('assets/certs/roots.pem');
    final ctx = SecurityContext(withTrustedRoots: true);
    ctx.setTrustedCertificatesBytes(pem.buffer.asUint8List());
    _posSecurityContext = ctx;
  } catch (_) {
    // Ildizlar yuklanmasa ham ilova ishlayveradi — tizim do'koniga tayanadi.
  }
}

/// Thin wrapper around [Dio]. The base URL is read fresh from [AppConfig] on
/// every request so a settings change takes effect without restart. A bearer
/// token is injected (unless the request opts out via `extra['noAuth']`).
class DioClient {
  DioClient(this._config, {this.onUnauthorized}) : _dio = Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Content-Type'] = 'application/json';

    // Har HttpClient bizning SecurityContext bilan yaratiladi — Let's Encrypt
    // ildizlari ilova ichida, eski Windows'ning do'koniga bog'liq emas.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(context: _posSecurityContext),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = _config.baseUrl;
          final noAuth = options.extra['noAuth'] == true;
          if (!noAuth) {
            final token = await _config.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final AppConfig _config;

  /// Fired when an *authenticated* request comes back 401 — i.e. the stored
  /// token is expired/invalid and the user must log in again.
  final void Function()? onUnauthorized;

  Dio get raw => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool noAuth = false,
    bool noLogout = false,
  }) =>
      _wrap(() => _dio.get<T>(
            path,
            queryParameters: query,
            options: Options(extra: {'noAuth': noAuth, 'noLogout': noLogout}),
          ));

  /// Fetch raw bytes (used for chek logosini yuklab, ESC/POS raster'ga o'girish).
  Future<List<int>?> fetchBytes(String url) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          extra: const {'noAuth': true},
          // /static uploads jamoat rasm; base URL orqali suriladi.
        ),
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool noAuth = false,
    bool noLogout = false,
  }) =>
      _wrap(() => _dio.post<T>(
            path,
            data: data,
            options: Options(extra: {'noAuth': noAuth, 'noLogout': noLogout}),
          ));

  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Failure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final detail = _extractDetail(e.response?.data) ?? 'Server xatosi ($code)';
        if (code == 401 || code == 403) {
          // 401 on a token-bearing request = session expired (login itself is
          // noAuth, so a wrong PIN never triggers this).
          // noLogout: ixtiyoriy so'rovlar (masalan F12 ro'yxati) 401 qaytarsa
          // ham sessiya TUGATILMAYDI — eski serverda endpoint bo'lmasligi
          // kassirni logout qilib yubormasin.
          if (code == 401 &&
              e.requestOptions.extra['noAuth'] != true &&
              e.requestOptions.extra['noLogout'] != true) {
            onUnauthorized?.call();
          }
          return AuthFailure(detail);
        }
        return ServerFailure(detail, statusCode: code);
      default:
        return NetworkFailure(e.message ?? 'Tarmoq xatosi.');
    }
  }

  String? _extractDetail(dynamic data) {
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return null;
  }
}
