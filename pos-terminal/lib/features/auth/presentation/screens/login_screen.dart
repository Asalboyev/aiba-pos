import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// Ekran klaviaturasi qaysi maydonga yozadi (sensorli kassada fizik
/// klaviatura yo'q — hamma raqamli maydon shu pad orqali to'ldiriladi).
enum _PadTarget { staff, pin, cash }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Terminal kodi endi Sozlamalarda (⚙️) turadi — kassir faqat o'z kodi va
  // PIN'ini kiritadi, chalg'imaydi.
  final _staffCode = TextEditingController();
  String _pin = '';
  bool _openShift = true;
  final _openingCash = TextEditingController(text: '0');

  /// Faol maydon — pad raqamlari shunga yoziladi. Maydonga bosilsa almashadi.
  _PadTarget _target = _PadTarget.staff;

  @override
  void dispose() {
    _staffCode.dispose();
    _openingCash.dispose();
    super.dispose();
  }

  void _padPress(String digit) {
    setState(() {
      switch (_target) {
        case _PadTarget.staff:
          if (_staffCode.text.length < 12) _staffCode.text += digit;
          // Xodim kodi to'lgach kassir odatda PIN'ga o'tadi — kod maydoniga
          // bosilganda yana qaytadi.
          break;
        case _PadTarget.pin:
          if (_pin.length < 8) _pin += digit;
          break;
        case _PadTarget.cash:
          final cur = _openingCash.text;
          if (cur.length >= 10) return;
          _openingCash.text = cur == '0' ? digit : cur + digit;
          break;
      }
    });
  }

  void _padBackspace() {
    setState(() {
      switch (_target) {
        case _PadTarget.staff:
          final t = _staffCode.text;
          if (t.isNotEmpty) _staffCode.text = t.substring(0, t.length - 1);
          break;
        case _PadTarget.pin:
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
          break;
        case _PadTarget.cash:
          final t = _openingCash.text;
          _openingCash.text = t.length <= 1 ? '0' : t.substring(0, t.length - 1);
          break;
      }
    });
  }

  void _setTarget(_PadTarget t) => setState(() => _target = t);

  Future<void> _submit() async {
    final terminalCode = ref.read(appConfigProvider).terminalCode.trim();
    final staffCode = _staffCode.text.trim();
    if (terminalCode.isEmpty) {
      // Bir martalik o'rnatish: administrator Sozlamalarda terminal kodini kiritadi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Terminal kodi kiritilmagan — Sozlamalar (⚙️) bo\'limida kiriting'),
          action: SnackBarAction(
            label: 'Sozlamalar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
      );
      return;
    }
    if (staffCode.isEmpty || _pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xodim kodi va PIN to\'ldiring')),
      );
      return;
    }

    final ok = await ref.read(loginControllerProvider.notifier).login(
          terminalCode: terminalCode,
          staffCode: staffCode,
          pin: _pin,
          openShift: _openShift,
          openingCash: num.tryParse(_openingCash.text.trim()) ?? 0,
        );
    if (!ok) setState(() => _pin = '');
    // On success, the root listens to sessionProvider and swaps the screen.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIBA POS — Kirish'),
        actions: [
          IconButton(
            tooltip: 'Sozlamalar',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Xodim kodi — bosilsa pad shu maydonga yozadi (faolligi
                // yashil qalin ramka bilan ko'rinadi).
                TextField(
                  controller: _staffCode,
                  autofocus: true,
                  onTap: () => _setTarget(_PadTarget.staff),
                  decoration: InputDecoration(
                    labelText: 'Xodim kodi',
                    hintText: '101',
                    border: const OutlineInputBorder(),
                    enabledBorder: _target == _PadTarget.staff
                        ? OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          )
                        : const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                // PIN qatori — bosilsa pad PIN'ga yozadi.
                _PinDisplay(
                  length: _pin.length,
                  active: _target == _PadTarget.pin,
                  onTap: () => _setTarget(_PadTarget.pin),
                ),
                const SizedBox(height: 12),
                _PinPad(onDigit: _padPress, onBackspace: _padBackspace),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kirishda smenani ochish'),
                  value: _openShift,
                  onChanged: (v) => setState(() {
                    _openShift = v;
                    if (!v && _target == _PadTarget.cash) {
                      _target = _PadTarget.staff;
                    }
                  }),
                ),
                if (_openShift)
                  TextField(
                    controller: _openingCash,
                    onTap: () => _setTarget(_PadTarget.cash),
                    decoration: InputDecoration(
                      labelText: 'Boshlang\'ich kassa (so\'m)',
                      border: const OutlineInputBorder(),
                      enabledBorder: _target == _PadTarget.cash
                          ? OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            )
                          : const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: state.loading ? null : _submit,
                    child: state.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirish', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDisplay extends StatelessWidget {
  const _PinDisplay({
    required this.length,
    required this.active,
    required this.onTap,
  });

  final int length;

  /// Pad hozir PIN'ga yozadimi — faol bo'lsa ramka bilan ajralib turadi.
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? scheme.primary : Theme.of(context).dividerColor,
            width: active ? 2 : 1,
          ),
          color: active ? scheme.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            length.clamp(0, 8).clamp(1, 8),
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < length
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
            ),
          )..insert(
              0,
              Text('PIN: ', style: Theme.of(context).textTheme.labelLarge),
            ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      for (var i = 1; i <= 9; i++) _key(context, '$i'),
      const SizedBox.shrink(),
      _key(context, '0'),
      IconButton(
        iconSize: 28,
        onPressed: onBackspace,
        icon: const Icon(Icons.backspace_outlined),
      ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: buttons,
    );
  }

  Widget _key(BuildContext context, String d) {
    return OutlinedButton(
      onPressed: () => onDigit(d),
      child: Text(d, style: const TextStyle(fontSize: 22)),
    );
  }
}
