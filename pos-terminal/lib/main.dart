import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/core_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      await ref.read(sessionProvider.notifier).restore();
      if (mounted) setState(() => _restored = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // POS terminal har doim yorug' rejimda — kassir muhitida o'qilishi
      // oson va qurilma/tizim temasiga bog'liq bo'lmaydi.
      themeMode: ThemeMode.light,
      home: !_restored
          ? const _Splash()
          : (session == null ? const LoginScreen() : const HomeShell()),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
