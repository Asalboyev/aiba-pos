import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../orders/presentation/providers/orders_providers.dart';
import '../../orders/presentation/providers/sync_service.dart';
import '../../orders/presentation/screens/pos_sale_screen.dart';
import '../../reports/presentation/screens/today_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shift/presentation/providers/shift_providers.dart';
import '../../shift/presentation/screens/shift_screen.dart';

/// Top-level navigation shell shown after login. A NavigationRail on wide
/// screens (Windows / tablet landscape), a NavigationBar on narrow.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Sotuv', 'Smena', 'Bugun'];

  @override
  void initState() {
    super.initState();
    // Refresh the menu cache on first launch after login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider.notifier).syncAll();
    });
  }

  /// Chiqishdan oldin smena ochiq bo'lsa ogohlantiramiz — kassir smenani
  /// yopishni (Z-hisobot) unutmasin. Ma'lumot yo'qolmaydi, lekin ochiq smena
  /// yopilmay qolishi mumkin.
  Future<void> _logout() async {
    final session = ref.read(sessionProvider);
    // Ochiq smena bormi: sessiyada shift_id yoki serverdagi joriy ochiq smena.
    final hasOpenShift = session?.shiftId != null ||
        ref.read(currentShiftProvider).valueOrNull != null;

    if (hasOpenShift) {
      final action = await showDialog<String>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Smena hali ochiq'),
          content: const Text(
            'Smena yopilmagan (Z-hisobot chiqmagan). Baribir chiqasizmi?\n\n'
            'Ma\'lumot yo\'qolmaydi — qayta kirsangiz smena davom etadi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop('cancel'),
              child: const Text('Bekor'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop('shift'),
              child: const Text('Smenani yopish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dctx).pop('logout'),
              child: const Text('Baribir chiqish'),
            ),
          ],
        ),
      );
      if (!mounted || action == null || action == 'cancel') return;
      if (action == 'shift') {
        // Smena tabiga o'tkazamiz — kassir Z-hisobotni yopsin.
        setState(() => _index = 1);
        return;
      }
    }
    await ref.read(sessionProvider.notifier).logout();
  }

  Widget _body() {
    switch (_index) {
      case 1:
        return const ShiftScreen();
      case 2:
        return const TodayScreen();
      default:
        return const PosSaleScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final sync = ref.watch(syncServiceProvider);
    final unsynced = ref.watch(unsyncedCountProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    final isWide = MediaQuery.of(context).size.width >= 720;

    final destinations = const [
      (Icons.point_of_sale, 'Sotuv'),
      (Icons.access_time, 'Smena'),
      (Icons.bar_chart, 'Bugun'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_titles[_index]} • ${session?.restaurant.name ?? ''}'),
        actions: [
          if (unsynced > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: const Icon(Icons.cloud_upload, size: 16),
                label: Text('$unsynced'),
                backgroundColor: Colors.orange.shade100,
              ),
            ),
          IconButton(
            tooltip: 'Sinxronlash',
            onPressed: sync.syncing
                ? null
                : () => ref.read(syncServiceProvider.notifier).syncAll(),
            icon: sync.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sozlamalar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(session?.staff.name ?? 'Xodim'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Chiqish')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    label: Text(d.$2),
                  ),
              ],
            ),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.$1), label: d.$2),
              ],
            ),
    );
  }
}
