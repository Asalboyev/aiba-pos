import 'package:equatable/equatable.dart';

class Shift extends Equatable {
  final String id;
  final String status; // open / closed
  final DateTime? openedAt;
  final DateTime? closedAt;
  final num openingCash;
  final num totalCash;
  final num totalCard;
  final num totalSales;
  final int ordersCount;
  final int errorChecksCount;

  /// To'lov turlari kesimi (server `by_method`): karta terminali / Click /
  /// Uzum alohida — smena hisobotida har biri o'z ustunida.
  final num cardOnly;
  final num clickTotal;
  final num uzumTotal;
  final num keldiTotal;

  /// Smena rasxodlari (manager Telegram botdan yozadi) — kassadan minus.
  final num expensesTotal;

  const Shift({
    required this.id,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.totalCash = 0,
    this.totalCard = 0,
    this.totalSales = 0,
    this.ordersCount = 0,
    this.errorChecksCount = 0,
    this.cardOnly = 0,
    this.clickTotal = 0,
    this.uzumTotal = 0,
    this.keldiTotal = 0,
    this.expensesTotal = 0,
  });

  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => [
        id,
        status,
        openedAt,
        closedAt,
        openingCash,
        totalCash,
        totalCard,
        totalSales,
        ordersCount,
        errorChecksCount,
        cardOnly,
        clickTotal,
        uzumTotal,
        keldiTotal,
        expensesTotal,
      ];
}
