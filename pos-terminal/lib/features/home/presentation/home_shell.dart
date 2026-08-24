import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/onscreen_keyboard.dart';
import '../../../core/widgets/pos_chrome.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../delivery/presentation/screens/delivery_screen.dart';
import '../../orders/domain/entities/payment_method.dart';
import '../../orders/presentation/providers/sync_service.dart';
import '../../orders/presentation/screens/pos_sale_screen.dart';
import '../../orders/presentation/widgets/error_check_dialog.dart';
import '../../orders/presentation/widgets/keldi_ketdi_dialog.dart';
import '../../orders/presentation/widgets/payment_dialog.dart';
import '../../orders/presentation/widgets/qr_pay_dialog.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shift/presentation/providers/shift_providers.dart';
import '../../shift/presentation/screens/shift_screen.dart';

/// Login'dan keyingi asosiy qobiq — Figma "Pos Design": suv foni, chap
/// navigatsiya paneli (Mahsulotlar / Ish vaqti / Yetkazib berish, pastda
/// Sozlamalar), o'ng yuqorida profil avatari. Kontent — tanlangan ekran.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialIndex;

  /// F10 — bo'limlar orasida aylanish: Mahsulotlar → Ish vaqti →
  /// Yetkazib berish → Sozlamalar → Mahsulotlar. Kassir mishka ishlatmaydi,
  /// shuning uchun navigatsiya ham klaviaturada bo'lishi shart.
  bool _onNavKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (event.logicalKey != LogicalKeyboardKey.f10) return false;
    const order = [0, 1, 2, 3];
    final next = order[(order.indexOf(_index) + 1) % order.length];
    setState(() => _index = next);
    const names = ['Mahsulotlar', 'Ish vaqti', 'Yetkazib berish', 'Sozlamalar'];
    final m = ScaffoldMessenger.maybeOf(context);
    m
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(names[next],
            style: const TextStyle(fontWeight: FontWeight.w600)),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PosColors.card,
      ));
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onNavKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider) != null) {
        ref.read(syncServiceProvider.notifier).syncAll();
      }
      // Vizual tekshiruv: --dart-define=DEBUG_DIALOG=payment.
      const dbg = String.fromEnvironment('DEBUG_DIALOG');
      if (!mounted) return;
      switch (dbg) {
        case 'payment':
          PaymentDialog.show(context, 384000, initialMethod: PaymentMethod.card);
        case 'keldi':
          KeldiKetdiDialog.show(context);
        case 'error':
          ErrorCheckDialog.show(context);
        case 'qr':
          QrPayDialog.show(context, 15000);
        case 'keyboard':
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.transparent,
            isScrollControlled: true,
            constraints: const BoxConstraints(maxWidth: double.infinity),
            builder: (_) => OnScreenKeyboard(
              onChar: (_) {},
              onBackspace: () {},
              onClear: () {},
              onEnter: () => Navigator.of(context).pop(),
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onNavKey);
    super.dispose();
  }

  Future<void> _logout() async {
    final session = ref.read(sessionProvider);
    final hasOpenShift = session?.shiftId != null ||
        ref.read(currentShiftProvider).valueOrNull != null;

    if (hasOpenShift) {
      final action = await showDialog<String>(
        context: context,
        builder: (dctx) => Dialog(
          backgroundColor: const Color(0xFF1C1D22),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          // Mishkasiz: 1 — Bekor (Esc), 2 — Smenani yopish (Enter), 3 — chiqish.
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, e) {
              if (e is! KeyDownEvent) return KeyEventResult.ignored;
              final k = e.logicalKey;
              if (k == LogicalKeyboardKey.escape ||
                  k == LogicalKeyboardKey.digit1) {
                Navigator.of(dctx).pop('cancel');
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.enter ||
                  k == LogicalKeyboardKey.numpadEnter ||
                  k == LogicalKeyboardKey.digit2) {
                Navigator.of(dctx).pop('shift');
                return KeyEventResult.handled;
              }
              if (k == LogicalKeyboardKey.digit3) {
                Navigator.of(dctx).pop('logout');
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: const Color(0x1FF5A623),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF5A623), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Smena hali ochiq',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Text(
                    'Smena yopilmagan (Z-hisobot chiqmagan). Baribir chiqasizmi?\n\n'
                    'Ma\'lumot yo\'qolmaydi — qayta kirsangiz smena davom etadi.',
                    style: TextStyle(
                        color: PosColors.muted, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: _DlgBtn(
                        label: '1 · Bekor',
                        onTap: () => Navigator.of(dctx).pop('cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DlgBtn(
                        label: '2 · Smenani yopish',
                        onTap: () => Navigator.of(dctx).pop('shift'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DlgBtn(
                        label: '3 · Baribir chiqish',
                        color: PosColors.red,
                        onTap: () => Navigator.of(dctx).pop('logout'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Esc/1 — Bekor · Enter/2 — Smenani yopish · '
                        '3 — Baribir chiqish',
                        style: TextStyle(color: PosColors.muted, fontSize: 11)),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      );
      if (!mounted || action == null || action == 'cancel') return;
      if (action == 'shift') {
        setState(() => _index = 1);
        return;
      }
    }
    await ref.read(sessionProvider.notifier).logout();
  }

  Widget _content() {
    switch (_index) {
      case 1:
        return const ShiftScreen();
      case 3:
        return const SettingsScreen(embedded: true);
      case 2:
      default:
        // Smena ochilmagan bo'lsa savdo ham, dostavka ham bloklanadi —
        // aks holda sotuv smenasiz yaratilib Z-hisobotdan tashqarida qoladi.
        final shiftAsync = ref.watch(currentShiftProvider);
        return shiftAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ShiftGuard(
            onStart: () => setState(() => _index = 1),
            message: 'Smena holatini olib bo\'lmadi. Ish vaqti bo\'limidan tekshiring.',
          ),
          data: (shift) {
            if (shift == null || !shift.isOpen) {
              return _ShiftGuard(onStart: () => setState(() => _index = 1));
            }
            return _index == 2 ? const DeliveryScreen() : const PosSaleScreen();
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: PosColors.bg,
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            // Yangilash + akkaunt: KATTA ekranда Figma bo'yicha o'ng yuqorida
            // suzib turadi; ekran KICHIK bo'lsa (qidiruv ustiga chiqib
            // ketmasligi uchun) chap menyuning pastiga ko'chadi va strelkasiz
            // bo'ladi — avatarning o'zi bosiladi.
            final compact = c.maxWidth < 1200;
            final refresh = _RefreshButton(onTap: () {
              ref.read(syncServiceProvider.notifier).syncAll();
            });
            final avatar = PosAvatar(
              name: session?.staff.name ?? '',
              onLogout: _logout,
              compact: compact,
            );
            final rail = PosNavRail(
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              onSettings: () => setState(() => _index = 3),
              settingsSelected: _index == 3,
              footer: compact
                  ? Column(children: [
                      refresh,
                      const SizedBox(height: 10),
                      avatar,
                    ])
                  : null,
            );
            final body = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail,
                Expanded(
                  // Katta ekranда tugmalar o'ng yuqorida suzadi — kontent
                  // ular bilan to'qnashmasligi uchun tepadan joy qoldiramiz.
                  child: compact
                      ? _content()
                      : Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: _content(),
                        ),
                ),
              ],
            );
            if (compact) return body;
            return Stack(children: [
              body,
              Positioned(
                top: 10,
                right: 22,
                child: Row(children: [refresh, const SizedBox(width: 10), avatar]),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Avatar yonidagi "Yangilash" tugmasi — menyu/hisobotlarni qo'lda sinxronlaydi.
class _RefreshButton extends ConsumerWidget {
  const _RefreshButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing =
        ref.watch(syncServiceProvider.select((s) => s.syncing));
    return Tooltip(
      message: 'Yangilash',
      child: InkWell(
        onTap: syncing ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x3DFFFFFF)),
          ),
          child: syncing
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : const Icon(Icons.refresh, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _DlgBtn extends StatelessWidget {
  const _DlgBtn({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final filled = color != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? color! : PosColors.cardBorder),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Smena ochilmagan holatdagi to'siq — savdo ekrani o'rnida chiqadi.
/// Enter yoki tugma — "Ish vaqti" bo'limiga o'tkazadi.
class _ShiftGuard extends StatelessWidget {
  const _ShiftGuard({required this.onStart, this.message});
  final VoidCallback onStart;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onStart();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: PosColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: PosColors.iconChip,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock,
                    color: PosColors.blue, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Smena ochilmagan',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                message ??
                    'Savdo qilish uchun avval smenani boshlang. Smenasiz chek urish mumkin emas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: PosColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PosColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onStart,
                  child: const Text('→  Smenani boshlash',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Enter — Ish vaqti bo\'limiga o\'tish',
                  style: TextStyle(color: PosColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
