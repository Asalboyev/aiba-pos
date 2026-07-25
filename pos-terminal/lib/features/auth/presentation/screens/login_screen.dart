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

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Terminal kodi endi Sozlamalarda (⚙️) turadi — kassir faqat o'z kodi va
  // PIN'ini kiritadi, chalg'imaydi.
  final _staffCode = TextEditingController();
  String _pin = '';
  bool _openShift = true;
  final _openingCash = TextEditingController(text: '0');

  @override
  void dispose() {
    _staffCode.dispose();
    _openingCash.dispose();
    super.dispose();
  }

  void _pinPress(String digit) {
    if (_pin.length >= 8) return;
    setState(() => _pin += digit);
  }

  void _pinBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

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
                TextField(
                  controller: _staffCode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Xodim kodi',
                    hintText: '101',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _PinDisplay(length: _pin.length),
                const SizedBox(height: 12),
                _PinPad(onDigit: _pinPress, onBackspace: _pinBackspace),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kirishda smenani ochish'),
                  value: _openShift,
                  onChanged: (v) => setState(() => _openShift = v),
                ),
                if (_openShift)
                  TextField(
                    controller: _openingCash,
                    decoration: const InputDecoration(
                      labelText: 'Boshlang\'ich kassa (so\'m)',
                      border: OutlineInputBorder(),
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
  const _PinDisplay({required this.length});
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      )..insert(
          0,
          Text('PIN: ', style: Theme.of(context).textTheme.labelLarge),
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
