import '../entities/auth_session.dart';

abstract class AuthRepository {
  /// Login with terminal + staff credentials. Optionally opens/attaches a
  /// shift on the backend. Persists the resulting session (token + metadata).
  Future<AuthSession> login({
    required String terminalCode,
    required String staffCode,
    required String pin,
    required bool openShift,
    required num openingCash,
  });

  /// The currently persisted session, if any (works offline).
  Future<AuthSession?> currentSession();

  /// Update the shift id on the persisted session (e.g. after opening a shift).
  Future<void> updateShiftId(String? shiftId);

  /// Fetch fresh restaurant/receipt settings from the server (adminka'da
  /// o'zgargan bo'lishi mumkin) va persistedSessiondagi restaurant blokini
  /// yangilash. Yangi sessiya obyektini qaytaradi. Null — offline yoki xato.
  Future<AuthSession?> refreshRestaurant();

  /// Clear token + persisted session.
  Future<void> logout();
}
