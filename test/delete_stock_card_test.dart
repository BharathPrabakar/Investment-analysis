import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/stocks/stock_card_detail.dart';
import 'package:my_new_app/stocks/stocks_section.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('StocksDao.deleteCardWithAllData deletes transactions, cardTags, and card', () async {
    final dao = db.stocksDao;

    // 1. Insert card
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );

    // 2. Insert tags and link to card
    final tagId = await dao.upsertTag('Auto');
    await dao.setTagsForCard(cardId, 'stock', [tagId]);

    // 3. Insert transactions
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('NORMAL'),
        date: Value(DateTime(2026, 9, 25)),
        price: const Value(290.0),
        quantity: const Value(10),
        totalAmount: const Value(2900.0),
      ),
    );
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('NORMAL'),
        date: Value(DateTime(2026, 9, 26)),
        price: const Value(292.0),
        quantity: const Value(5),
        totalAmount: const Value(1460.0),
      ),
    );

    // Verify presence
    final txBefore = await dao.getTransactionsForCard(cardId);
    expect(txBefore.length, equals(2));
    final tagsBefore = await dao.getTagIdsForCard(cardId, 'stock');
    expect(tagsBefore, contains(tagId));
    final cardBefore = await dao.getCardById(cardId);
    expect(cardBefore, isNotNull);

    // 4. Perform deletion
    await dao.deleteCardWithAllData(cardId);

    // 5. Verify all associated data removed without orphans
    final txAfter = await dao.getTransactionsForCard(cardId);
    expect(txAfter, isEmpty);
    final tagsAfter = await dao.getTagIdsForCard(cardId, 'stock');
    expect(tagsAfter, isEmpty);
    final cardAfter = await dao.getCardById(cardId);
    expect(cardAfter, isNull);

    // Tags table itself should preserve the tag
    final allTags = await dao.getAllTags();
    expect(allTags.any((t) => t.id == tagId && t.name == 'Auto'), isTrue);

    // 6. Verify same ticker can be inserted again (UNIQUE constraint freed)
    final newCardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );
    expect(newCardId, isNotNull);
  });

  testWidgets('Cancel in delete confirmation dialog leaves card intact', (tester) async {
    final dao = db.stocksDao;
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('IDEA'),
        exchange: Value('NSE'),
        stockName: Value('Vodafone Idea Limited'),
      ),
    );
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('NORMAL'),
        date: Value(DateTime(2026, 9, 25)),
        price: const Value(14.0),
        quantity: const Value(100),
        totalAmount: const Value(1400.0),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppDbProvider(
          db: db,
          child: const StocksSection(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Long press on IDEA card
    await tester.longPress(find.text('IDEA'));
    await tester.pumpAndSettle();

    // Confirm dialog is shown with correct prompt and transaction count
    expect(find.text('Delete IDEA?'), findsOneWidget);
    expect(
      find.text(
          "This permanently deletes the card and all its 1 transactions. This can't be undone."),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Card should still exist
    expect(find.text('IDEA'), findsOneWidget);
    final card = await dao.getCardById(cardId);
    expect(card, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Deleting card from detail screen removes card and pops screen', (tester) async {
    final dao = db.stocksDao;
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('IDEA'),
        exchange: Value('NSE'),
        stockName: Value('Vodafone Idea Limited'),
      ),
    );
    final card = (await dao.getCardById(cardId))!;

    await tester.pumpWidget(
      MaterialApp(
        home: AppDbProvider(
          db: db,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppDbProvider(
                          db: db,
                          child: StockCardDetail(card: card),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Open detail screen
    await tester.tap(find.text('Open Detail'));
    await tester.pumpAndSettle();
    expect(find.text('IDEA · NSE'), findsOneWidget);

    // Open overflow menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Delete card
    expect(find.text('Delete card'), findsOneWidget);
    await tester.tap(find.text('Delete card'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Delete IDEA?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Detail screen popped, back to root screen
    expect(find.text('Open Detail'), findsOneWidget);
    expect(find.text('IDEA · NSE'), findsNothing);
    expect(find.text('IDEA deleted'), findsOneWidget);

    // Card deleted from db
    final deletedCard = await dao.getCardById(cardId);
    expect(deletedCard, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
