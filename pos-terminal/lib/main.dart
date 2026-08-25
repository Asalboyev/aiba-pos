import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/dio_client.dart' show loadBundledRoots;
import 'core/providers/core_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/settings/presentation/settings_screen.dart';

// Faqat ishlab chiqish/vizual tekshiruv uchun: login'ni chetlab o'tib to'g'ridan
// -to'g'ri qobiqni ko'rsatadi (--dart-define=DEBUG_HOME=true). Prod build'da
// o'chirilgan (default false).
const _kDebugHome = bool.fromEnvironment('DEBUG_HOME');
const _kDebugIndex = int.fromEnvironment('DEBUG_INDEX');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let's Encrypt ildizlari — eski Windows kassalarда HTTPS ishlashi uchun.
  await loadBundledRoots();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AibaPosApp(),
    ),
  );
}

class AibaPosApp extends ConsumerStatefulWidget {
  const AibaPosApp({super.key});

  @override
  ConsumerState<AibaPosApp> createState() => _AibaPosAppState();
}

class _AibaPosAppState extends ConsumerState<AibaPosApp> {
  bool _restored = false;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Restore a persisted session so the POS opens straight into the shell
    // (and works offline) after the first login.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Debug-home vizual tekshiruvda secure_storage (keychain) o'qishni
      // o'tkazib yuboramiz — aks holda macOS keychain oynasi appni to'sadi.
      if (!_kDebugHome) {
        await ref.read(sessionProvider.notifier).restore();
      }
      if (mounted) setState(() => _restored = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    // Sozlamalar saqlanganда qayta baholaymiz (setup → login).
    ref.watch(configVersionProvider);
    final configured =
        ref.read(appConfigProvider).terminalCode.trim().isNotEmpty;

    // Token expired on the server (401) — drop the cached session so the app
    // routes back to the login screen instead of queueing forever "offline".
    ref.listen<int>(sessionExpiredSignalProvider, (prev, next) {
      if (ref.read(sessionProvider) == null) return;
      ref.read(sessionProvider.notifier).logout();
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Sessiya muddati tugadi — qaytadan kiring. '
              'Saqlangan savdolar login\'dan keyin avtomatik yuboriladi.'),
          duration: Duration(seconds: 6),
        ),
      );
    });

    return MaterialApp(
      title: 'AIBA POS',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      // POS terminal har doim Figma qorong'i mavzusida (qurilma temasiga
      // bog'liq emas) — barcha ekranlar bir xil ko'rinadi.
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: _kDebugHome
          ? HomeShell(initialIndex: _kDebugIndex)
          : (!_restored
              ? const _Splash()
              : session != null
                  ? const HomeShell()
                  // Birinchi o'rnatiш: terminal sozlanmaган bo'lса — setup
                  // (Sozlamalar). Save'дан keyin login'ga o'tadi.
                  : (configured
                      ? const LoginScreen()
                      : const SettingsScreen())),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF06090B),
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
              strokeWidth: 3, color: Color(0xFF2277EA)),
        ),
      ),
    );
  }
}
