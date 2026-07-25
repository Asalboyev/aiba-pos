/// Payment methods accepted by the backend (cash / card / qr).
enum PaymentMethod {
  cash('cash', 'Naqd'),
  card('card', 'Karta'),
  qr('qr', 'QR');

  const PaymentMethod(this.code, this.label);

  /// The wire value sent to the backend.
  final String code;

  /// The Uzbek UI label.
  final String label;

  static PaymentMethod fromCode(String code) =>
      PaymentMethod.values.firstWhere(
        (m) => m.code == code,
        orElse: () => PaymentMethod.cash,
      );
}

class Payment {
  final PaymentMethod method;
  final num amount;
  const Payment(this.method, this.amount);

  Map<String, dynamic> toJson() => {'method': method.code, 'amount': amount};

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        PaymentMethod.fromCode((j['method'] ?? 'cash').toString()),
        num.tryParse('${j['amount']}') ?? 0,
      );
}
