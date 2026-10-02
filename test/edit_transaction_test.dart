import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/logic/stock_logic.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/services/trading_day_service.dart';
import 'package:my_new_app/stocks/add_transaction_sheet.dart';
import 'package:my_new_app/stocks/stock_card_detail.dart';

class AlwaysOpenTradingDayService extends TradingDayService {
  @override
  Future<TradingDayResult> checkTradingDayDetailed(DateTime date, {String exchange = 'NSE'}) async =>
      const TradingDayResult(status: TradingDayStatus.open);

  @override
  Future<TradingDayStatus> checkTradingDay(DateTime date, {String exchange = 'NSE'}) async =>
      TradingDayStatus.open;
}

void main() {
  late AppDatabase db;
  late TradingDayService originalService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    originalService = TradingDayService.instance;
    TradingDayService.instance = AlwaysOpenTradingDayService();
  });

  tearDown(() {
    TradingDayService.instance = originalService;
    return db.close();
  });

  Future<int> setupCardWithTransactions(AppDatabase db) async {
    final dao = db.stocksDao;
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );

    // TX 1: BUY 10 @ 100 on 2026-09-21 (Monday)
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('AVG'),
        date: Value(DateTime(2026, 9, 21)),
        price: const Value(100.0),
        quantity: const Value(10),
        totalAmount: const Value(1000.0),
      ),
    );

    // TX 2: BUY 10 @ 200 on 2026-09-22 (Tuesday)
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('AVG'),
        date: Value(DateTime(2026, 9, 22)),
        price: const Value(200.0),
        quantity: const Value(10),
        totalAmount: const Value(2000.0),
      ),
    );

    return cardId;
  }

  testWidgets('Cancel an edit leaves original transaction unchanged and intact', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final cardId = await setupCardWithTransactions(db);
    final dao = db.stocksDao;
    final card = (await dao.getCardById(cardId))!;
    final initialTxs = await dao.getTransactionsForCard(cardId);
    expect(initialTxs.length, equals(2));

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Open detail
    await tester.tap(find.text('Open Detail'));
    await tester.pumpAndSettle();

    // Find the edit button for the transaction
    final editButtons = find.byIcon(Icons.edit_outlined);
    expect(editButtons, findsNWidgets(2));
    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    // Sheet should be visible with "Edit Transaction"
    expect(find.text('Edit Transaction'), findsOneWidget);

    // Close/Cancel via close button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Pop the detail screen
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    // Verify both original transactions still exist unchanged
    final txsAfter = await dao.getTransactionsForCard(cardId);
    expect(txsAfter.length, equals(2));
    expect(txsAfter[0].id, equals(initialTxs[0].id));
    expect(txsAfter[0].quantity, equals(initialTxs[0].quantity));
    expect(txsAfter[0].price, equals(initialTxs[0].price));
    expect(txsAfter[0].totalAmount, equals(initialTxs[0].totalAmount));
    expect(txsAfter[1].id, equals(initialTxs[1].id));
    expect(txsAfter[1].quantity, equals(initialTxs[1].quantity));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Change only quantity updates in place with SAME id and no merge prompt', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final cardId = await setupCardWithTransactions(db);
    final dao = db.stocksDao;
    final initialTxs = await dao.getTransactionsForCard(cardId);
    final targetTx = initialTxs.firstWhere((t) => t.price == 200.0);

    await tester.pumpWidget(
      MaterialApp(
        home: AppDbProvider(
          db: db,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AddTransactionSheet(
                cardId: cardId,
                ticker: 'TMPV',
                existingTx: targetTx,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Change quantity from 10 to 25
    final qtyField = find.widgetWithText(TextFormField, '10');
    expect(qtyField, findsOneWidget);
    await tester.enterText(qtyField, '25');
    await tester.pumpAndSettle();

    // Scroll to save button and tap
    final saveBtn = find.text('Save Changes');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Confirm no merge dialog was shown
    expect(find.text('Duplicate Transaction'), findsNothing);

    // Verify row was updated in place with identical ID and recalculated total amount
    final txsAfter = await dao.getTransactionsForCard(cardId);
    expect(txsAfter.length, equals(2));
    final updatedTx = txsAfter.firstWhere((t) => t.id == targetTx.id);
    expect(updatedTx.id, equals(targetTx.id));
    expect(updatedTx.quantity, equals(25));
    expect(updatedTx.price, equals(200.0));
    expect(updatedTx.totalAmount, equals(25 * 200.0)); // 5000.0
  });

  testWidgets('Change price to match another transaction shows merge prompt and merges correctly', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final cardId = await setupCardWithTransactions(db);
    final dao = db.stocksDao;
    final initialTxs = await dao.getTransactionsForCard(cardId);
    // initialTxs has:
    // tx1: BUY 10 @ 100 on 2026-09-21 (total 1000)
    // tx2: BUY 10 @ 200 on 2026-09-22 (total 2000)
    final tx1 = initialTxs.firstWhere((t) => t.price == 100.0);
    final tx2 = initialTxs.firstWhere((t) => t.price == 200.0);

    await tester.pumpWidget(
      MaterialApp(
        home: AppDbProvider(
          db: db,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AddTransactionSheet(
                cardId: cardId,
                ticker: 'TMPV',
                existingTx: tx2,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Change date and price of tx2 to match tx1:
    // Price from 200 to 100. Quantity to 15.
    final priceField = find.widgetWithText(TextFormField, '200.00');
    await tester.enterText(priceField, '100');
    final qtyField = find.widgetWithText(TextFormField, '10');
    await tester.enterText(qtyField, '15');
    await tester.pumpAndSettle();

    // Tap date button and pick 2026-09-21
    await tester.tap(find.text('22 Sep 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Scroll to save button and tap
    final saveBtn = find.text('Save Changes');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Merge confirmation dialog must appear
    expect(find.text('Duplicate Transaction'), findsOneWidget);
    expect(find.text('Merge'), findsOneWidget);

    // Tap Merge
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    // Verify: tx2 was deleted, tx1 quantity increased by 15 (10 + 15 = 25),
    // and totalAmount is sum of amounts (1000 + 1500 = 2500)
    final txsAfter = await dao.getTransactionsForCard(cardId);
    expect(txsAfter.length, equals(1));
    expect(txsAfter.first.id, equals(tx1.id));
    expect(txsAfter.first.quantity, equals(25));
    expect(txsAfter.first.totalAmount, equals(2500.0));
  });

  testWidgets('Edit that would make quantity negative is blocked and data unchanged', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final dao = db.stocksDao;
    final cardId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('TMPV'),
        exchange: Value('NSE'),
        stockName: Value('Tata Motors Passenger Vehicles Limited'),
      ),
    );

    // Buy 10 on 2026-09-21
    final buyTxId = await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('BUY'),
        entryMode: const Value('AVG'),
        date: Value(DateTime(2026, 9, 21)),
        price: const Value(100.0),
        quantity: const Value(10),
        totalAmount: const Value(1000.0),
      ),
    );

    // Sell 8 on 2026-09-22
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: Value(cardId),
        type: const Value('SELL'),
        entryMode: const Value('AVG'),
        date: Value(DateTime(2026, 9, 22)),
        price: const Value(120.0),
        quantity: const Value(8),
        totalAmount: const Value(960.0),
      ),
    );

    final buyTx = (await dao.getTransactionsForCard(cardId)).firstWhere((t) => t.id == buyTxId);

    await tester.pumpWidget(
      MaterialApp(
        home: AppDbProvider(
          db: db,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AddTransactionSheet(
                cardId: cardId,
                ticker: 'TMPV',
                existingTx: buyTx,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reduce buy quantity from 10 to 5 (less than the 8 sold later)
    final qtyField = find.widgetWithText(TextFormField, '10');
    await tester.enterText(qtyField, '5');
    await tester.pumpAndSettle();

    // Scroll to save button and tap
    final saveBtn = find.text('Save Changes');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Should show error and stay open
    expect(find.textContaining('depends on this holding'), findsOneWidget);

    // Data in DB remains completely unchanged
    final txsAfter = await dao.getTransactionsForCard(cardId);
    final currentBuy = txsAfter.firstWhere((t) => t.id == buyTxId);
    expect(currentBuy.quantity, equals(10));
    expect(currentBuy.totalAmount, equals(1000.0));
  });

  test('DAO atomic editTransaction rolls back on failure leaving data untouched', () async {
    final dao = db.stocksDao;
    final cardId = await setupCardWithTransactions(db);
    final initialTxs = await dao.getTransactionsForCard(cardId);
    final tx1 = initialTxs.firstWhere((t) => t.price == 100.0);
    final tx2 = initialTxs.firstWhere((t) => t.price == 200.0);

    // Try an editTransaction merge targeting a nonexistent merge target
    // which should throw an exception inside the transaction
    try {
      await dao.editTransaction(
        updatedTx: StockTransactionsCompanion(
          id: Value(tx2.id),
          cardId: Value(cardId),
          type: const Value('BUY'),
          entryMode: const Value('AVG'),
          date: Value(DateTime(2026, 9, 22)),
          price: const Value(200.0),
          quantity: const Value(15),
          totalAmount: const Value(3000.0),
        ),
        mergeIntoTxId: 99999, // Non-existent target ID triggers StateError on getSingle
        deleteTxIdOnMerge: tx2.id,
        additionalQuantityOnMerge: 15,
        additionalAmountOnMerge: 3000.0,
      );
      fail('Expected exception from editTransaction');
    } catch (_) {
      // Expected failure
    }

    // Verify data remains 100% untouched
    final txsAfter = await dao.getTransactionsForCard(cardId);
    expect(txsAfter.length, equals(2));
    final tx1After = txsAfter.firstWhere((t) => t.id == tx1.id);
    final tx2After = txsAfter.firstWhere((t) => t.id == tx2.id);
    expect(tx1After.quantity, equals(10));
    expect(tx2After.quantity, equals(10));
    expect(tx2After.totalAmount, equals(2000.0));
  });

  test('Same-day order: replay BUYs before SELLs, then by id', () {
    final sameDay = DateTime(2026, 9, 21);
    final txSellId1 = TxRecord(
      id: 1,
      type: 'SELL',
      date: sameDay,
      price: 150.0,
      quantity: 5,
      totalAmount: 750.0,
    );
    final txBuyId2 = TxRecord(
      id: 2,
      type: 'BUY',
      date: sameDay,
      price: 100.0,
      quantity: 10,
      totalAmount: 1000.0,
    );
    final txBuyId3 = TxRecord(
      id: 3,
      type: 'BUY',
      date: sameDay,
      price: 100.0,
      quantity: 5,
      totalAmount: 500.0,
    );

    // If SELL (id 1) was processed before BUY (id 2), validation would fail as quantity would go negative (-5).
    // With BUYs before SELLs, the BUY (id 2) comes first (+10), then SELL (-5) is valid!
    final list = [txSellId1, txBuyId2, txBuyId3];
    list.sort(compareTransactions);

    expect(list[0].id, equals(2)); // BUY id 2
    expect(list[1].id, equals(3)); // BUY id 3
    expect(list[2].id, equals(1)); // SELL id 1

    final validation = validateQuantityNeverNegative(
      [txBuyId2, txBuyId3],
      ProposedOp.add(txSellId1),
    );
    expect(validation.isValid, isTrue);
  });

  test('Card creation is atomic: card, tags, and first transaction in one DB transaction', () async {
    final dao = db.stocksDao;
    final cardId = await dao.createCardWithInitialData(
      card: const StockCardsCompanion(
        ticker: Value('INFY'),
        exchange: Value('NSE'),
        stockName: Value('Infosys Limited'),
      ),
      tagNames: ['IT', 'Tech'],
      firstTransaction: StockTransactionsCompanion(
        type: const Value('BUY'),
        entryMode: const Value('AVG'),
        date: Value(DateTime(2026, 9, 21)),
        price: const Value(1500.0),
        quantity: const Value(10),
        totalAmount: const Value(15000.0),
      ),
    );

    final card = await dao.getCardById(cardId);
    expect(card, isNotNull);
    expect(card!.ticker, equals('INFY'));

    final tagIds = await dao.getTagIdsForCard(cardId, 'stock');
    expect(tagIds.length, equals(2));

    final txs = await dao.getTransactionsForCard(cardId);
    expect(txs.length, equals(1));
    expect(txs.first.quantity, equals(10));
    expect(txs.first.price, equals(1500.0));
  });

  test('PRAGMA foreign_keys is enabled', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data['foreign_keys'], equals(1));
  });
}
