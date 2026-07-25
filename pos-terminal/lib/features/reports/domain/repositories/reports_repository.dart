import '../entities/sales_summary.dart';

abstract class ReportsRepository {
  Future<SalesSummary> salesSummary();
}
