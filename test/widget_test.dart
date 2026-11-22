import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:present_tracker/data/logic.dart';
import 'package:present_tracker/data/models.dart';
import 'package:present_tracker/data/store.dart';
import 'package:present_tracker/main.dart';

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('ptw');
    final s = await AppStore.open(at: dir);
    s.gifts.add(Gift(id: 'g1', occasion: 'christmas', year: defaultYear('christmas'), personId: s.people.first.id, item: 'Wooden Dollhouse', price: 129.99, created: 1));
  });

  testWidgets('Home, occasion and person screens open', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PresentTrackerApp());
    await tester.pump();
    expect(find.text('Christmas'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Everleigh'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Everleigh'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Christmas').first, -300, scrollable: find.byType(Scrollable).first);

    await tester.tap(find.text('Christmas').first);
    await tester.pumpAndSettle();
    expect(find.text('Fairness check'), findsOneWidget);
    expect(find.text('Wooden Dollhouse'), findsOneWidget);

    await tester.tap(find.text('By gifts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('fewer than Everleigh'), findsOneWidget);

    final open = find.textContaining('OPEN').first;
    await tester.scrollUntilVisible(open, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to Christmas'), findsOneWidget);
    expect(find.text('Wooden Dollhouse'), findsOneWidget);
  });
}
