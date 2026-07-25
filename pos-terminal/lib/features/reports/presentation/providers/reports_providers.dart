import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/reports_remote_datasource.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/repositories/reports_repository.dart';

final reportsRemoteDataSourceProvider = Provider<ReportsRemoteDataSource>((ref) {
  return ReportsRemoteDataSource(ref.watch(dioClientProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(ref.watch(reportsRemoteDataSourceProvider));
});

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) {
  return ref.watch(reportsRepositoryProvider).salesSummary();
});
