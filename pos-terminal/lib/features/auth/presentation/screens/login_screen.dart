import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../providers/auth_providers.dart';

/// Kirish ekrani — Figma "LOGIN" dizayni:
/// chapда aurora fon + shisha logo, o'ngда qora panel (AIBA + PIN + klaviatura).
/// PIN-only: kassir 4 xonali PIN teradi → to'liq bo'lganда AVTOMATIK kiradi.
/// To'g'ri → ilovaga o'tadi; xato → qizil toast + qizil nuqtalar.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

const int _pinLength = 4;

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _pin = '';
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    // Fizik klaviatura: PIN raqamlarini to'g'ridan-to'g'ri terish mumkin
    // (ekran tugmalarini bosish shart emas). Backspace — o'chirish.
    HardwareKeyboard.instance.addHandler(_onHwKey);
  }

  bool _onHwKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _digit(ch);
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHwKey);
    _errorTimer?.cancel();
    super.dispose();
  }

  void _digit(String d) {
    if (ref.read(loginControllerProvider).loading) return;
    if (_pin.length >= _pinLength) return;
    // Yangi raqam terila boshlaganда eski xato yo'qoladi.
    if (ref.read(loginControllerProvider).error != null) {
      ref.read(loginControllerProvider.notifier).clearError();
    }
    setState(() => _pin += d);
    // Yashirin avariya kodi "000" — Sozlamalarni ochadi (login sahifasида
    // ko'rinadigan tugma yo'q). Odatда sozlash birinchi o'rnatishда bir marta
    // qilinadi; bu kod noto'g'ri sozlashдан keyin ham qayta kirish uchun.
    if (_pin == '000') {
      setState(() => _pin = '');
      // FAQAT BIR MARTA: terminal bir marta muvaffaqiyatli kirgandan keyin
      // (`setupDone`) bu kod umuman ishlamaydi — kassir sozlamani buzmaydi.
      if (ref.read(appConfigProvider).setupDone) return;
      _openSettings();
      return;
    }
    if (_pin.length == _pinLength) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final terminalCode = ref.read(appConfigProvider).terminalCode.trim();
    if (terminalCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Terminal kodi kiritilmagan — Sozlamalar (⚙️) bo\'limида kiriting'),
        action: SnackBarAction(
          label: 'Sozlamalar',
          onPressed: _openSettings,
        ),
      ));
      setState(() => _pin = '');
      return;
    }
    // PIN-only: staffCode bo'sh — backend PIN orqali xodimni topadi.
    // Smena AVTO-OCHILMAYDI: smenani faqat menejer «Ish vaqti» bo'limida
    // boshlang'ich kassani kiritib ochadi. Ochiq smena bo'lsa, server uni
    // baribir sessiyaga bog'lab beradi.
    final ok = await ref.read(loginControllerProvider.notifier).login(
          terminalCode: terminalCode,
          staffCode: '',
          pin: _pin,
          openShift: false,
          openingCash: 0,
        );
    if (ok) {
      // Sozlash tugadi — endi "000" kodi ishlamaydi.
      await ref.read(appConfigProvider).markSetupDone();
      // KASSIR smena yopiq bo'lsa kira olmaydi — smenani menejer ochadi.
      // (Menejer smenasiz ham kiradi: aynan u smenani ochishi kerak.)
      final s = ref.read(sessionProvider);
      if (s != null && s.staff.role == 'cashier' && s.shiftId == null) {
        await ref.read(sessionProvider.notifier).logout();
        if (mounted) {
          setState(() => _pin = '');
          // ALERT — kassir aniq ko'rsin (snackbar sezilmay qolardi).
          await showDialog<void>(
            context: context,
            builder: (dctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C1D22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.lock_clock, color: Color(0xFFF5A623), size: 26),
                SizedBox(width: 10),
                Text('Smena ochilmagan',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ]),
              content: const Text(
                  'Kassir smena ochilmaguncha kira olmaydi.\n'
                  'Avval menejer kirib, «Ish vaqti» bo\'limida smenani ochsin.',
                  style: TextStyle(color: Color(0xFF9AA0A6), height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('Tushunarli'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    if (!ok && mounted) setState(() => _pin = '');
  }

  void _openSettings() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    // Xato paydo bo'lсa — 20 soniyadan so'ng o'zi yo'qoladi (raqam terilса ham
    // darhol ketadi). Har yangi xatoда taymer qayta boshlanadi.
    ref.listen<String?>(loginControllerProvider.select((s) => s.error),
        (prev, next) {
      _errorTimer?.cancel();
      if (next != null) {
        _errorTimer = Timer(const Duration(seconds: 20), () {
          if (mounted) ref.read(loginControllerProvider.notifier).clearError();
        });
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final panel = _RightPanel(
            pin: _pin,
            error: state.error,
            loading: state.loading,
            onDigit: _digit,
            onBackspace: _backspace,
            onClearError: () => ref.read(loginControllerProvider.notifier).clearError(),
          );
          if (!wide) return SafeArea(child: panel);
          return Row(
            children: [
              const Expanded(flex: 3, child: _BrandSide()),
              SizedBox(width: 520, child: SafeArea(child: panel)),
            ],
          );
        },
      ),
    );
  }
}

/// Chap tomon — aurora fon + shisha logo (Figma'dан kesilgan bitta rasm).
class _BrandSide extends StatelessWidget {
  const _BrandSide();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF060606),
      child: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/login_bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

/// O'ng paneldagi kichik app-icon — flat AIBA belgisi (SVG), yumaloq kvadratда.
class _AppIcon extends StatelessWidget {
  const _AppIcon({this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C20),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset('assets/logo_glass.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.pin,
    required this.error,
    required this.loading,
    required this.onDigit,
    required this.onBackspace,
    required this.onClearError,
  });

  final String pin;
  final String? error;
  final bool loading;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C0C0E),
      child: Stack(
        children: [
          // 1) Kontent — eng ostida (toast/gear ustдан bosilsин deб).
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 96, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AppIcon(size: 64),
                const SizedBox(height: 16),
                const Text('AIBA',
                    style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('POS system', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 16)),
                const SizedBox(height: 40),
                _PinDots(length: pin.length, error: error != null),
                const SizedBox(height: 40),
                _Keypad(onDigit: onDigit, onBackspace: onBackspace),
                const SizedBox(height: 8),
                // Yuklanish holati — PIN to'lgach avto-kirishda ko'rinadi.
                SizedBox(
                  height: 24,
                  child: loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2AA9E0)),
                        )
                      : null,
                ),
              ],
            ),
          ),
          // Xato toasti — eng ustда (X bosilsin).
          if (error != null)
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              child: _ErrorToast(text: error!, onClose: onClearError),
            ),
        ],
      ),
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE5484D);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chap qizil aksent chiziq.
            Container(width: 5, color: red),
            Expanded(
              child: Container(
                color: const Color(0xF22B2B31),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    // Qizil doira ichida ogohlantirish belgisi.
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                          color: red, shape: BoxShape.circle),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PIN indikatori — bo'sh = chiziqcha, to'la = nuqta, xato = qizil.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.error});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE5484D);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        // Xato holatida (Figma): barcha 4 nuqta qizil to'la ko'rinadi.
        final filled = error || i < length;
        final color = error
            ? red
            : (i < length ? Colors.white : const Color(0xFF3A3A40));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 11),
          width: filled ? 13 : 20,
          height: filled ? 13 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(filled ? 7 : 2),
          ),
        );
      }),
    );
  }
}

/// Raqamli klaviatura — 1..9, [bo'sh] 0 backspace. Dizayndagi qora yumaloq keys.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _KeyButton(label: d, onTap: () => onDigit(d));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          for (var i = 1; i <= 9; i++) key('$i'),
          const SizedBox.shrink(),
          key('0'),
          _KeyButton(icon: Icons.backspace_outlined, onTap: onBackspace),
        ],
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          color: _down ? const Color(0xFF3A3A40) : const Color(0xFF2A2A2E),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(widget.icon, color: Colors.white, size: 28)
              : Text(widget.label!,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
