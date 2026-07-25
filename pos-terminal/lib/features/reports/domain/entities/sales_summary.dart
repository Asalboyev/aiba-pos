import 'package:equatable/equatable.dart';

class TopProduct extends Equatable {
  final String name;
  final num qty;
  final num total;
  const TopProduct({required this.name, required this.qty, required this.total});

  @override
  List<Object?> get props => [name, qty, total];
}

class SalesSummary extends Equatable {
  final int ordersCount;
  final num totalSales;
  final num totalCash;
  final num totalCard;
  final List<TopProduct> topProducts;

  const SalesSummary({
    required this.ordersCount,
    required this.totalSales,
    required this.totalCash,
    required this.totalCard,
    required this.topProducts,
  });

  @override
  List<Object?> get props =>
      [ordersCount, totalSales, totalCash, totalCard, topProducts];
}
