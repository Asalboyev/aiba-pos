import 'package:aiba_pos_terminal/features/orders/data/models/order_mapper.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/cart.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/order_draft.dart';
import 'package:aiba_pos_terminal/features/orders/domain/entities/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OrderDraft makeDraft({
    String uuid = 'uuid-123',
    num discount = 0,
    String? tableNo,
    String? note,
    List<CartItem>? items,
    List<Payment>? payments,
  }) {
    return OrderDraft(
      clientUuid: uuid,
      discount: discount,
      tableNo: tableNo,
      note: note,
      items: items ??
          const [
            CartItem(
              productId: 'p1',
              name: 'Burger',
              price: 25000,
              qty: 2,
              mxikCode: '12345678',
              vatPercent: 12,
            ),
          ],
      payments: payments ?? const [Payment(PaymentMethod.cash, 50000)],
    );
  }

  group('OrderMapper.draftToOrderIn', () {
    test('maps client_uuid, discount and item fields', () {
      final json = OrderMapper.draftToOrderIn(makeDraft());
      expect(json['client_uuid'], 'uuid-123');
      expect(json['discount'], 0);

      final items = json['items'] as List;
      expect(items.length, 1);
      final item = items.first as Map<String, dynamic>;
      expect(item['product_id'], 'p1');
      expect(item['name'], 'Burger');
      expect(item['qty'], 2);
      expect(item['price'], 25000);
      expect(item['mxik_code'], '12345678');
      expect(item['vat_percent'], 12);
    });

    test('maps payments with backend method codes', () {
      final json = OrderMapper.draftToOrderIn(makeDraft(
        payments: const [
          Payment(PaymentMethod.card, 30000),
          Payment(PaymentMethod.qr, 20000),
        ],
      ));
      final payments = json['payments'] as List;
      expect(payments.length, 2);
      expect((payments[0] as Map)['method'], 'card');
      expect((payments[1] as Map)['method'], 'qr');
      expect((payments[0] as Map)['amount'], 30000);
      // Har qism serverga label bilan ketadi (chekda ko'rinadigan nom).
      expect((payments[0] as Map)['label'], 'Karta');
      expect((payments[1] as Map)['label'], 'QR');
    });

    test('custom payment label overrides method label', () {
      final json = OrderMapper.draftToOrderIn(makeDraft(
        payments: const [Payment(PaymentMethod.card, 50000, label: 'Payme')],
      ));
      final p = (json['payments'] as List).first as Map;
      expect(p['method'], 'card'); // wire kodi karta
      expect(p['label'], 'Payme'); // ko'rinadigan nom
    });

    test('omits null/empty optional fields', () {
      final json = OrderMapper.draftToOrderIn(makeDraft());
      expect(json.containsKey('table_no'), isFalse);
      expect(json.containsKey('note'), isFalse);
    });

    test('includes table_no and note when present', () {
      final json = OrderMapper.draftToOrderIn(
        makeDraft(tableNo: '7', note: 'Tez'),
      );
      expect(json['table_no'], '7');
      expect(json['note'], 'Tez');
    });

    test('ad-hoc item without product_id omits the key', () {
      final json = OrderMapper.draftToOrderIn(makeDraft(
        items: const [CartItem(name: 'Manual', price: 1000, qty: 1)],
      ));
      final item = (json['items'] as List).first as Map<String, dynamic>;
      expect(item.containsKey('product_id'), isFalse);
      expect(item['name'], 'Manual');
    });
  });

  group('OrderMapper response parsing', () {
    final response = {
      'created': true,
      'order': {
        'id': 'order-1',
        'number': 'AB12CD34',
        'fiscal': {'status': 'success', 'qr_url': 'https://ofd/qr/1'},
      },
    };

    test('orderId extracts the order id', () {
      expect(OrderMapper.orderId(response), 'order-1');
    });

    test('orderNumber extracts the order number', () {
      expect(OrderMapper.orderNumber(response), 'AB12CD34');
    });

    test('fiscalMap extracts the fiscal object', () {
      final fiscal = OrderMapper.fiscalMap(response);
      expect(fiscal?['status'], 'success');
      expect(fiscal?['qr_url'], 'https://ofd/qr/1');
    });

    test('fiscalMap returns null when fiscal is null', () {
      final res = {
        'order': {'id': 'x', 'number': 'y', 'fiscal': null}
      };
      expect(OrderMapper.fiscalMap(res), isNull);
    });
  });
}
