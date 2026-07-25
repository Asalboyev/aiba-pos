import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AppConfig config,
    required SharedPreferences prefs,
  })  : _remote = remote,
        _config = config,
        _prefs = prefs;

  final AuthRemoteDataSource _remote;
  final AppConfig _config;
  final SharedPreferences _prefs;

  static const _kSession = 'auth_session';

  @override
  Future<AuthSession> login({
    required String terminalCode,
    required String staffCode,
    required String pin,
    required bool openShift,
    required num openingCash,
  }) async {
    final session = await _remote.login(
      terminalCode: terminalCode,
      staffCode: staffCode,
      pin: pin,
      openShift: openShift,
      openingCash: openingCash,
    );
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession?> currentSession() async {
    final token = await _config.getToken();
    final raw = _prefs.getString(_kSession);
    if (token == null || token.isEmpty || raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return AuthSessionModel.fromPersistedJson(json, token);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateShiftId(String? shiftId) async {
    final raw = _prefs.getString(_kSession);
    if (raw == null) return;
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    json['shift_id'] = shiftId;
    await _prefs.setString(_kSession, jsonEncode(json));
  }

  @override
  Future<AuthSession?> refreshRestaurant() async {
    final token = await _config.getToken();
    final raw = _prefs.getString(_kSession);
    if (token == null || token.isEmpty || raw == null) return null;
    try {
      final fresh = await _remote.fetchRestaurant();
      if (fresh.isEmpty) return null;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      // Restaurant blokini butunlay almashtiramiz — adminka nima jo'natsa shu.
      json['restaurant'] = fresh;
      await _prefs.setString(_kSession, jsonEncode(json));
      return AuthSessionModel.fromPersistedJson(json, token);
    } catch (_) {
      // Offline yoki 4xx — jimgina o'tkazamiz, chek eski sozlama bilan chiqadi.
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _config.setToken(null);
    await _prefs.remove(_kSession);
  }

  Future<void> _persist(AuthSession session) async {
    await _config.setToken(session.accessToken);
    await _prefs.setString(
      _kSession,
      jsonEncode(AuthSessionModel.toPersistedJson(session)),
    );
  }
}
