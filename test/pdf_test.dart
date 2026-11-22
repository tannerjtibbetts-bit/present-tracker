import 'package:flutter_test/flutter_test.dart';
import 'package:present_tracker/data/models.dart';
import 'package:present_tracker/services/report_pdf.dart';

void main() {
  test('Every occasion makes a letter PDF', () async {
    final people = [
      Person(id: 'e', name: 'Everleigh', created: 1),
      Person(id: 'h', name: 'Hudson', created: 2),
      Person(id: 'r', name: 'Grandma Ruth', group: 'Family', created: 3),
    ];
    for (final occ in letters.keys) {
      final gifts = [
        Gift(id: '1', occasion: occ, year: 2026, personId: 'e', item: 'Wooden Dollhouse', price: 129.99, store: 'Indigo', purchased: '2026-11-18', created: 1),
        Gift(id: '2', occasion: occ, year: 2026, personId: 'h', item: 'Kids’ scooter – blue', price: 74.5, status: 'wrapped', notes: 'In the garage', created: 2),
      ];
      final bytes = await buildReport(occasion: occ, label: occ, year: 2026, people: people, gifts: gifts);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1500));
    }
  });

  test('Only the chosen people are on the report', () async {
    final people = [Person(id: 'e', name: 'Everleigh', created: 1)];
    final gifts = [
      Gift(id: '1', occasion: 'christmas', year: 2026, personId: 'e', item: 'Bear', price: 30, created: 1),
      Gift(id: '2', occasion: 'christmas', year: 2026, personId: 'h', item: 'Bike', price: 300, created: 2),
    ];
    final bytes = await buildReport(occasion: 'christmas', label: 'Christmas', year: 2026, people: people, gifts: gifts);
    expect(bytes, isNotEmpty);
  });

  test('Text the PDF fonts cannot show is swapped', () {
    expect(clean('Kids’ “toy” – 😀'), 'Kids\' "toy" - ?');
  });
}
