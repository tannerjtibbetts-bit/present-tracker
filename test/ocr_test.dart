import 'package:flutter_test/flutter_test.dart';
import 'package:present_tracker/services/ocr.dart';

void main() {
  test('Price tag', () {
    final r = parsePhotoText('Wooden Dollhouse\n\$129.99\nIndigo');
    expect(r.item, 'Wooden Dollhouse');
    expect(r.price, 129.99);
    expect(r.store, 'Indigo');
  });

  test('Online order screenshot skips shipping and totals', () {
    final r = parsePhotoText('''amazon.ca
Your order has been placed
Order #702-4455123-9911
Ordered on November 18, 2026
LEGO City Fire Station 60321
Qty: 1
Price: \$89.99
Shipping: \$5.99
Order total: \$102.08
Arriving Friday, Dec 4''');
    expect(r.store, 'Amazon');
    expect(r.price, 89.99);
    expect(r.orderNumber, '702-4455123-9911');
    expect(r.orderDate, '2026-11-18');
    expect(r.item, contains('LEGO City Fire Station'));
    expect(r.details, contains('Qty 1'));
    expect(r.details, contains('Arrives Dec 4'));
  });

  test('Receipt with sale price and date', () {
    final r = parsePhotoText('''CANADIAN TIRE
Store #123
2026/11/20
KIDS KICK SCOOTER
Reg \$89.99
Sale \$74.50
HST \$9.69
TOTAL \$84.19''');
    expect(r.store, 'Canadian Tire');
    expect(r.price, 74.50);
    expect(r.orderDate, '2026-11-20');
  });

  test('Lines and prices for tapping', () {
    final r = PhotoRead('Plush Teddy Bear\nMastermind Toys\nWas \$44.99\nNow \$34.99\n123', parsePhotoText('Plush Teddy Bear\nMastermind Toys\nWas \$44.99\nNow \$34.99\n123'));
    expect(r.lines, ['Plush Teddy Bear', 'Mastermind Toys', r'Was $44.99', r'Now $34.99']);
    expect(r.prices, [44.99, 34.99]);
    expect(r.info.price, 34.99);
  });

  test('Nothing readable', () {
    expect(parsePhotoText('').isEmpty, isTrue);
  });
}
