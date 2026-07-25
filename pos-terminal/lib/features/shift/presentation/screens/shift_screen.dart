import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '0');
    final amount = await showDialog<num>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smena ochish'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Boshlang\'ich kassa',
            suffixText: "so'm",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, num.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Ochish'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    try {
      final shift = await ref.read(shiftRepositoryProvider).open(amount);
      ref.read(sessionProvider.notifier).setShiftId(shift.id);
      ref.invalidate(currentShiftProvider);
    } catch (e) {
      if (context.mounted) _snack(context, 'Xato: $e');
    }
  }

  Future<void> _close(
      BuildContext context, WidgetRef ref, String shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smenani yopish?'),
        content: const Text('Z-hisobot tuziladi va smena yopiladi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yopish')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(shiftRepositoryProvider).close(shiftId: shiftId);
      ref.read(sessionProvider.notifier).setShiftId(null);
      ref.invalidate(currentShiftProvider);
      if (context.mounted) _snack(context, 'Smena yopildi');
    } catch (e) {
      if (context.mounted) _snack(context, 'Xato: $e');
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(currentShiftProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(currentShiftProvider),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          shiftAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator())),
            error: (e, _) => _OfflineCard(
                message: 'Smena maʼlumoti olinmadi (oflayn?)\n$e',
                onOpen: () => _open(context, ref)),
            data: (shift) {
              if (shift == null || !shift.isOpen) {
                return _OfflineCard(
                  message: 'Hozir ochiq smena yo\'q.',
                  onOpen: () => _open(context, ref),
                );
              }
              return _OpenShiftCard(
                shift: shift,
                onClose: () => _close(context, ref, shift.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.message, required this.onOpen});
  final String message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.point_of_sale, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Smena ochish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenShiftCard extends StatelessWidget {
  const _OpenShiftCard({required this.shift, required this.onClose});
  final Shift shift;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open, color: Colors.green),
                const SizedBox(width: 8),
                Text('Smena ochiq', style: theme.textTheme.titleLarge),
              ],
            ),
            if (shift.openedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Ochilgan: ${shift.openedAt}',
                    style: theme.textTheme.bodySmall),
              ),
            const Divider(height: 32),
            Text('Z-hisobot', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('Boshlang\'ich kassa', shift.openingCash),
            _row('Naqd savdo', shift.totalCash),
            _row('Karta/QR savdo', shift.totalCard),
            _row('Jami savdo', shift.totalSales, bold: true),
            _row('Buyurtmalar', shift.ordersCount, isMoney: false),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              onPressed: onClose,
              icon: const Icon(Icons.stop),
              label: const Text('Smenani yopish (Z)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, num value, {bool bold = false, bool isMoney = true}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 18 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(isMoney ? Money.formatSom(value) : value.toString(),
              style: style),
        ],
      ),
    );
  }
}
