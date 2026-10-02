import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/data/local_tickers.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/stocks/create_stock_card_flow.dart';

import 'package:my_new_app/services/trading_day_service.dart';

class AlwaysOpenTradingDayService extends TradingDayService {
  @override
  Future<TradingDayResult> checkTradingDayDetailed(DateTime date, {String exchange = 'NSE'}) async =>
      const TradingDayResult(status: TradingDayStatus.open);

  @override
  Future<TradingDayStatus> checkTradingDay(DateTime date, {String exchange = 'NSE'}) async =>
      TradingDayStatus.open;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late TradingDayService originalService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await ensureTickersLoaded();

    originalService = TradingDayService.instance;
    TradingDayService.instance = AlwaysOpenTradingDayService();
  });

  tearDown(() {
    TradingDayService.instance = originalService;
    return db.close();
  });

  testWidgets('A ticker with an existing card is marked Already added and tapping shows message', (tester) async {
    final dao = db.stocksDao;
    // Add existing card for RELIANCE
    await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('RELIANCE'),
        exchange: Value('NSE'),
        stockName: Value('Reliance Industries Limited'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDbProvider(
            db: db,
            child: const CreateStockCardFlow(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Type RELIANCE in search
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'RELIANCE');
    await tester.pump();

    // Verify "Already added" label is shown
    expect(find.text('Already added'), findsOneWidget);

    // Tap on RELIANCE
    await tester.tap(find.text('Already added'));
    await tester.pump();

    // Verify snackbar message is shown
    expect(find.text('RELIANCE is already in your stocks.'), findsOneWidget);

    // Verify still on Step 1 (Select Stock) and not moved to Step 2 (Add Tags)
    expect(find.text('Select Stock'), findsOneWidget);
    expect(find.text('Add Tags'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('After deleting that card, the same ticker becomes selectable again', (tester) async {
    final dao = db.stocksDao;
    // Add card for INFY
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('INFY'),
        exchange: Value('NSE'),
        stockName: Value('Infosys Limited'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDbProvider(
            db: db,
            child: const CreateStockCardFlow(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Search INFY
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'INFY');
    await tester.pump();

    expect(find.text('Already added'), findsOneWidget);

    // Now delete INFY card from database
    await dao.deleteCardWithAllData(cardId);
    // Allow stream to emit
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // "Already added" should disappear reactively
    expect(find.text('Already added'), findsNothing);

    // Tapping INFY now advances to Step 2
    await tester.tap(find.byKey(const ValueKey('stock_tile_NSE_INFY')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Add Tags'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('The create step handles a unique-constraint failure with friendly message and no partial data saved', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final dao = db.stocksDao;

    // Simulate scenario: flow is open for TMPV
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDbProvider(
            db: db,
            child: const CreateStockCardFlow(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Search TMPV
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'TMPV');
    await tester.pump();

    // Select TMPV
    await tester.tap(find.byKey(const ValueKey('stock_tile_NSE_TMPV')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Step 2: Skip / Next
    expect(find.text('Add Tags'), findsOneWidget);
    await tester.tap(find.text('Skip & Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Step 3: First Transaction
    expect(find.text('First Transaction'), findsOneWidget);
    // Switch to AVG mode to avoid price-range fetch
    await tester.tap(find.text('Avg Price'));
    await tester.pump();

    // Fill price & qty
    final priceField = find.widgetWithText(TextFormField, 'Enter price');
    final qtyField = find.widgetWithText(TextFormField, 'Number of shares');
    await tester.enterText(priceField, '300');
    await tester.enterText(qtyField, '10');
    await tester.pump();

    // Wait for calendar check to finish
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Checking market calendar...').evaluate().isEmpty) {
        break;
      }
    }

    // Tap Continue to confirm step
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Step 4: Confirm
    expect(find.text('Confirm'), findsOneWidget);

    // Now insert TMPV card directly into DB to simulate a race/duplicate
    await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );

    // Tap Create Card
    await tester.tap(find.text('Create Card'));
    await tester.pump();

    // Friendly error snackbar must be shown
    expect(find.text('This stock was already added'), findsOneWidget);

    // Confirm that only the 1 existing card is in DB and no transactions or extra cards were saved
    final allCards = await dao.getAllCards();
    expect(allCards.length, equals(1));
    final txs = await dao.getTransactionsForCard(allCards.first.id);
    expect(txs, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
