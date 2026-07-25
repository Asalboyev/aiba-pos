import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/shift_remote_datasource.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';

final shiftRemoteDataSourceProvider = Provider<ShiftRemoteDataSource>((ref) {
  return ShiftRemoteDataSource(ref.watch(dioClientProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepositoryImpl(ref.watch(shiftRemoteDataSourceProvider));
});

/// The current open shift (refreshes by invalidation).
final currentShiftProvider = FutureProvider<Shift?>((ref) {
  return ref.watch(shiftRepositoryProvider).current();
});
