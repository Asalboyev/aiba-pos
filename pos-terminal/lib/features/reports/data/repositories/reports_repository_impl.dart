import '../../domain/entities/sales_summary.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_datasource.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._remote);
  final ReportsRemoteDataSource _remote;

  @override
  Future<SalesSummary> salesSummary() => _remote.salesSummary();
}
