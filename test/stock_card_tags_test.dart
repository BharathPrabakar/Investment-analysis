import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/stocks/stock_card_detail.dart';
import 'package:my_new_app/stocks/stock_card_tile.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> createTestCard() async {
    final dao = db.stocksDao;
    return dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );
  }

  test('DAO: add a tag to card', () async {
    final dao = db.stocksDao;
    final cardId = await createTestCard();

    await dao.addTagToCard(cardId, 'stock', 'Auto');

    final tags = await dao.getTagsForCard(cardId, 'stock');
    expect(tags.length, equals(1));
    expect(tags.first.name, equals('Auto'));
  });

  test('DAO: add an existing tag by different casing reuses the same tag', () async {
    final dao = db.stocksDao;
    final cardId1 = await createTestCard();
    final cardId2 = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('INFY'),
        exchange: Value('NSE'),
        stockName: Value('Infosys Limited'),
      ),
    );

    // Add "Long Term" on card 1
    await dao.addTagToCard(cardId1, 'stock', 'Long Term');

    // Add "long term" on card 2
    await dao.addTagToCard(cardId2, 'stock', 'long term');

    final allTags = await dao.getAllTags();
    // Only 1 tag row created in tags table
    expect(allTags.length, equals(1));
    expect(allTags.first.name, equals('Long Term'));

    // Both cards linked to same tag id
    final card1Tags = await dao.getTagsForCard(cardId1, 'stock');
    final card2Tags = await dao.getTagsForCard(cardId2, 'stock');
    expect(card1Tags.first.id, equals(card2Tags.first.id));
  });

  test('DAO: add the same tag twice is blocked', () async {
    final dao = db.stocksDao;
    final cardId = await createTestCard();

    await dao.addTagToCard(cardId, 'stock', 'Tech');

    // Adding same tag with exact name
    expect(
      () => dao.addTagToCard(cardId, 'stock', 'Tech'),
      throwsA(isA<StateError>()),
    );

    // Adding same tag with different casing
    expect(
      () => dao.addTagToCard(cardId, 'stock', 'tech'),
      throwsA(isA<StateError>()),
    );
  });

  test('DAO: remove a tag removes card_tags row while tag row still exists', () async {
    final dao = db.stocksDao;
    final cardId = await createTestCard();

    await dao.addTagToCard(cardId, 'stock', 'Banking');
    final tagsBefore = await dao.getTagsForCard(cardId, 'stock');
    expect(tagsBefore.length, equals(1));
    final tagId = tagsBefore.first.id;

    // Remove from card
    await dao.removeTagFromCard(cardId, 'stock', tagId);

    // Card has no tags now
    final tagsAfter = await dao.getTagsForCard(cardId, 'stock');
    expect(tagsAfter, isEmpty);

    // Tag still exists in tags table for other cards
    final allTags = await dao.getAllTags();
    expect(allTags.any((t) => t.id == tagId && t.name == 'Banking'), isTrue);
  });

  testWidgets('Minimized StockCardTile does not render tags', (tester) async {
    final cardId = await createTestCard();
    await db.stocksDao.addTagToCard(cardId, 'stock', 'EV');

    final card = await db.stocksDao.getCardById(cardId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDbProvider(
            db: db,
            child: StockCardTile(
              card: card!,
              transactions: const [],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Tile should not show tag chips
    expect(find.text('EV'), findsNothing);
  });

  testWidgets('Enlarged card: removing the last tag shows the empty state', (tester) async {
    final cardId = await createTestCard();
    await db.stocksDao.addTagToCard(cardId, 'stock', 'Growth');

    final card = await db.stocksDao.getCardById(cardId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDbProvider(
            db: db,
            child: StockCardDetail(card: card!),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tag chip should be visible with delete icon
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('No tags yet - tap + to add one'), findsNothing);

    // Tap delete icon on chip
    final deleteIcon = find.descendant(
      of: find.byType(Chip),
      matching: find.byIcon(Icons.cancel),
    );
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Empty state text should now appear
    expect(find.text('No tags yet - tap + to add one'), findsOneWidget);
    expect(find.text('Growth'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
