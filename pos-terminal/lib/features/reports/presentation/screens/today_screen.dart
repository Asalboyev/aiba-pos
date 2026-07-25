import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/sales_summary.dart';
import '../providers/reports_providers.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesSummaryProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(salesSummaryProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Center(
              child: Text('Hisobot olinmadi (oflayn?)\n$e',
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(salesSummaryProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish'),
              ),
            ),
          ],
        ),
        data: (summary) => _SummaryView(summary: summary),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});
  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Bugungi savdo', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
                title: 'Buyurtmalar',
                value: summary.ordersCount.toString(),
                icon: Icons.receipt_long),
            _StatCard(
                title: 'Jami savdo',
                value: Money.formatSom(summary.totalSales),
                icon: Icons.payments),
            _StatCard(
                title: 'Naqd',
                value: Money.formatSom(summary.totalCash),
                icon: Icons.money),
            _StatCard(
                title: 'Karta/QR',
                value: Money.formatSom(summary.totalCard),
                icon: Icons.credit_card),
          ],
        ),
        const SizedBox(height: 24),
        Text('Top mahsulotlar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (summary.topProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Maʼlumot yo\'q'),
          )
        else
          ...summary.topProducts.map(
            (p) => Card(
              child: ListTile(
                leading: const Icon(Icons.fastfood),
                title: Text(p.name),
                subtitle: Text('${p.qty} dona'),
                trailing: Text(Money.formatSom(p.total),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
