import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/fiscal_info.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/payment_method.dart';
import 'package:aiba_pos_terminal/features/printing/data/receipt_builder.dart';
import 'package:aiba_pos_terminal/features/printing/domain/receipt_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('card-payment receipt bytes contain the restaurant name header',
      () async {
    final data = ReceiptData(
      restaurantName: 'Milli Grill',
      terminalName: 'Kassa 1',
      orderNumber: 'A-12',
      items: const [
        CartItem(
            name: 'Palov',
            price: 35000,
            qty: 2,
            mxikCode: '10112001001000000'),
      ],
      subtotal: 70000,
      discount: 0,
      total: 70000,
      payments: const [Payment(PaymentMethod.card, 70000)],
      fiscal: const FiscalInfo(
        status: 'success',
        fiscalSign: '9014415339544288',
        qrUrl: 'https://ofd.soliq.uz/epi/check?fp=9014415339544288&s=70000',
      ),
      createdAt: DateTime(2026, 6, 11, 12, 0),
    );

    final bytes = await ReceiptBuilder.build(data);
    final text = String.fromCharCodes(bytes);

    File('/tmp/receipt-card.bin').writeAsBytesSync(bytes);

    expect(text.contains('Milli Grill'), isTrue,
        reason: 'restaurant name missing from ESC/POS byte stream');
    expect(text.contains('Karta'), isTrue);
  });
}
