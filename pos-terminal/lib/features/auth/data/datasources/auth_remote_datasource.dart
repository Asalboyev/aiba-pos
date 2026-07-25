import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_session.dart';
import '../models/auth_session_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);
  final DioClient _client;

  Future<AuthSession> login({
    required String terminalCode,
    required String staffCode,
    required String pin,
    required bool openShift,
    required num openingCash,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/v2/pos-terminal/auth/login',
      noAuth: true,
      data: {
        'terminal_code': terminalCode,
        'staff_code': staffCode,
        'pin': pin,
        'open_shift': openShift,
        'opening_cash': openingCash,
      },
    );
    return AuthSessionModel.fromLoginJson(res.data ?? const {});
  }

  /// Adminka chek sozlamalarini o'zgartirgan bo'lishi mumkin — chek chop
  /// etishdan oldin fresh restoran ma'lumotini olamiz.
  Future<Map<String, dynamic>> fetchRestaurant() async {
    final res = await _client.get<Map<String, dynamic>>('/api/v2/pos-terminal/restaurant/me');
    return res.data ?? const {};
  }
}
