import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';

/// Overridden in main() after async init so the rest of the tree can read it
/// synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  // macOS: use the legacy file-based keychain instead of the data-protection
  // keychain — the latter needs a keychain-access-group entitlement (and thus
  // a paid signing certificate), which dev/desktop builds don't have.
  // Avoids errSecMissingEntitlement (-34018).
  (ref) => const FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    iOptions: IOSOptions(),
  ),
);

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig(
    ref.watch(sharedPreferencesProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Sozlamalar saqlanganда oshiriladi. Ilova ildizi buni kuzatib, birinchi
/// o'rnatiш (setup) → login o'tishini qayta baholaydi.
final configVersionProvider = StateProvider<int>((ref) => 0);

/// Bumped by [DioClient] whenever an authenticated request returns 401.
/// The app root listens and forces a re-login ("session expired").
final sessionExpiredSignalProvider = StateProvider<int>((ref) => 0);

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.watch(appConfigProvider),
    onUnauthorized: () =>
        ref.read(sessionExpiredSignalProvider.notifier).state++,
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// Emits whenever connectivity changes. The sync service listens to this.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return ref.watch(connectivityProvider).onConnectivityChanged;
});

/// True when at least one non-`none` connection is available.
final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStreamProvider);
  return async.maybeWhen(
    data: (results) =>
        results.any((r) => r != ConnectivityResult.none),
    orElse: () => true, // assume online until proven otherwise
  );
});
