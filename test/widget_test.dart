import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/main.dart';

void main() {
  testWidgets('App shell smoke test - two tabs are present',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(InvestmentTrackerApp(db: db));
    await tester.pump();

    // Both bottom-nav labels should be visible.
    expect(find.text('Investments'), findsWidgets);
    expect(find.text('Analysis'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Tapping Analysis tab shows Analysis screen',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(InvestmentTrackerApp(db: db));
    await tester.pump();

    // Switch to the Analysis tab.
    await tester.tap(find.text('Analysis').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The app bar should now show "Analysis".
    expect(find.widgetWithText(AppBar, 'Analysis'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
