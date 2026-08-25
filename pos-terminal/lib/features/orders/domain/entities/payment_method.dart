/// Payment methods accepted by the backend (cash / card / qr).
enum PaymentMethod {
  cash('cash', 'Naqd'),
  card('card', 'Karta'),
  qr('qr', 'QR'),
  // Click / Uzum — QR to'lovlari alohida hisoblanadi (admin panel va smena
  // hisobotida har biri o'z ustunida ko'rinadi).
  click('click', 'Click'),
  uzum('uzum', 'Uzum'),
  // VIP mehmon (katta akalar pul to'lamaydi) — manager Telegram kodi bilan
  // tasdiqlanib, chek "keldi-ketdi" deb yopiladi (pul to'langanday).
  keldiKetdi('keldi_ketdi', 'Keldi-ketdi');

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

  /// Chekda/UI'da ko'rinadigan nom. Berilmasa `method.label` ishlatiladi.
  /// Kelajakdagi usullar (Payme, Click) uchun ko'rinadigan nomni method
  /// kodidan ajratib turadi.
  final String? _label;

  const Payment(this.method, this.amount, {String? label}) : _label = label;

  String get label => _label ?? method.label;

  Map<String, dynamic> toJson() =>
      {'method': method.code, 'amount': amount, 'label': label};

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        PaymentMethod.fromCode((j['method'] ?? 'cash').toString()),
        num.tryParse('${j['amount']}') ?? 0,
        label: j['label']?.toString(),
      );
}
