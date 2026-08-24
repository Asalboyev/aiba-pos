import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(dioClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    config: ref.watch(appConfigProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// The current auth session (null = logged out). The whole app routes off this.
class SessionNotifier extends StateNotifier<AuthSession?> {
  SessionNotifier(this._repo) : super(null);
  final AuthRepository _repo;

  Future<void> restore() async {
    state = await _repo.currentSession();
  }

  Future<void> setSession(AuthSession session) async => state = session;

  /// Adminka'da chek sozlamalari o'zgargan bo'lishi mumkin — chek chop
  /// etishdan oldin yangilaymiz.
  Future<void> refreshRestaurant() async {
    final fresh = await _repo.refreshRestaurant();
    if (fresh != null) state = fresh;
  }

  void setShiftId(String? shiftId) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(shiftId: shiftId);
    _repo.updateShiftId(shiftId);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = null;
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, AuthSession?>((ref) {
  return SessionNotifier(ref.watch(authRepositoryProvider));
});

/// Login form submission state.
class LoginState {
  final bool loading;
  final String? error;
  const LoginState({this.loading = false, this.error});
}

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._ref) : super(const LoginState());
  final Ref _ref;

  Future<bool> login({
    required String terminalCode,
    required String staffCode,
    required String pin,
    required bool openShift,
    required num openingCash,
  }) async {
    state = const LoginState(loading: true);
    try {
      final session = await _ref.read(authRepositoryProvider).login(
            terminalCode: terminalCode,
            staffCode: staffCode,
            pin: pin,
            openShift: openShift,
            openingCash: openingCash,
          );
      await _ref.read(sessionProvider.notifier).setSession(session);
      state = const LoginState(loading: false);
      return true;
    } on Failure catch (f) {
      state = LoginState(loading: false, error: f.message);
      return false;
    } catch (e) {
      state = LoginState(loading: false, error: e.toString());
      return false;
    }
  }

  /// Xato toast'ini yopish (foydalanuvchi ✕ bosсa).
  void clearError() {
    if (state.error != null) state = const LoginState();
  }
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
  return LoginController(ref);
});

/// Convenience: the persisted base URL/terminal code for prefilling the form.
final appConfigInstanceProvider = Provider<AppConfig>(
  (ref) => ref.watch(appConfigProvider),
);
