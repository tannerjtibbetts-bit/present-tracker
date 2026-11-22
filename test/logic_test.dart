import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:present_tracker/data/logic.dart';
import 'package:present_tracker/data/models.dart';
import 'package:present_tracker/data/store.dart';

Person kid(String id, String name, {String group = 'Kids', String bday = ''}) => Person(id: id, name: name, group: group, birthday: bday, created: 1);
Gift gift(String person, double? price, {String occ = 'christmas', int year = 2026}) =>
    Gift(id: '$person$price', occasion: occ, year: year, personId: person, price: price, created: 1);

void main() {
  test('Easter dates', () {
    expect(easterDate(2026), DateTime(2026, 4, 5));
    expect(easterDate(2027), DateTime(2027, 3, 28));
    expect(easterDate(2025), DateTime(2025, 4, 20));
  });

  test('Default year moves to next year once the day has passed', () {
    final nov = DateTime(2026, 11, 22);
    expect(defaultYear('christmas', nov), 2026);
    expect(defaultYear('valentines', nov), 2027);
    expect(defaultYear('easter', nov), 2027);
    expect(defaultYear('birthday', nov), 2026);
  });

  test('Next birthday and age', () {
    final nb = nextBirthday(kid('h', 'Hudson', bday: '2016-12-08'), DateTime(2026, 11, 22))!;
    expect(nb.days, 16);
    expect(nb.turns, 10);
    expect(nextBirthday(kid('n', 'Nevaeh'), DateTime(2026, 11, 22)), isNull);
  });

  test('Money format', () {
    expect(money(164.98), r'$164.98');
    expect(money(1234.5), r'$1,234.50');
  });

  test('Fairness by spending and by number of gifts', () {
    final people = [kid('e', 'Everleigh'), kid('h', 'Hudson'), kid('n', 'Nevaeh'), kid('r', 'Grandma Ruth', group: 'Family')];
    final gifts = [gift('e', 129.99), gift('e', 34.99), gift('h', 89.99), gift('h', 74.50), gift('n', 42), gift('n', 119), gift('n', 18.5), gift('r', 85)];
    final g = fairness(people, gifts);
    expect(g.map((x) => x.name), ['Kids', 'Family']);
    expect(g.first.note(false), r'Hudson is $15.01 behind, Everleigh is $14.52 behind Nevaeh.');
    expect(g.first.note(true), 'Everleigh has 1 gift fewer, Hudson has 1 gift fewer than Nevaeh.');
    expect(g.last.note(false), '');
    final note = personNote(people[0], people, gifts);
    expect(note, contains(r'$14.52 behind Nevaeh'));
    expect(note, contains('1 gift fewer than Nevaeh'));
  });

  test('Date lines', () {
    final people = [kid('h', 'Hudson', bday: '2016-12-08')];
    expect(occasionDateLine('christmas', 2026, people, DateTime(2026, 11, 22)), 'Dec 25, 2026 · 33 days to go');
    expect(occasionDateLine('birthday', 2026, people, DateTime(2026, 11, 22)), 'Hudson · Dec 8 · in 16 days');
  });

  test('Store saves, reloads and removes people with their gifts', () async {
    final dir = await Directory.systemTemp.createTemp('pt');
    final s = await AppStore.open(at: dir);
    expect(s.people.map((p) => p.name), ['Everleigh', 'Hudson', 'Nevaeh']);
    final e = s.people.first;
    await s.saveGift(Gift(id: 'g1', occasion: 'christmas', year: 2026, personId: e.id, item: 'Dollhouse', price: 129.99, purchased: '2026-11-18', orderNo: 'IND-1', created: 5));
    final again = await AppStore.open(at: dir);
    expect(again.gifts.single.item, 'Dollhouse');
    expect(again.gifts.single.orderNo, 'IND-1');
    await again.deletePerson(e.id);
    final third = await AppStore.open(at: dir);
    expect(third.gifts, isEmpty);
    expect(third.people.length, 2);
    await dir.delete(recursive: true);
  });
}
