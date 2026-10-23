import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/logic/stock_logic.dart';
import 'package:my_new_app/services/dividend_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stock Splits - String Ratio Parsing', () {
    test('parses standard sub-division with Rs and slash', () {
      final ratio = DividendSource.parseSplitRatio(
          'Sub-division of equity shares from Rs. 10/- to Rs. 2/- each');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 10.0);
      expect(ratio.newFaceValue, 2.0);
      expect(ratio.oldFaceValue / ratio.newFaceValue, 5.0);
    });

    test('parses Face Value Split From Rs 10 To Rs 1', () {
      final ratio = DividendSource.parseSplitRatio(
          'Face Value Split From Rs 10 To Rs 1');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 10.0);
      expect(ratio.newFaceValue, 1.0);
    });

    test('parses Split - Rs 5/- to Re 1/-', () {
      final ratio = DividendSource.parseSplitRatio(
          'Split - Rs 5/- to Re 1/- per share');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 5.0);
      expect(ratio.newFaceValue, 1.0);
    });

    test('parses colon ratio Stock Split 1:5', () {
      final ratio = DividendSource.parseSplitRatio('Stock Split 1:5');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 5.0);
      expect(ratio.newFaceValue, 1.0);
    });

    test('parses colon ratio Subdivision 1:10', () {
      final ratio = DividendSource.parseSplitRatio('Subdivision 1:10');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 10.0);
      expect(ratio.newFaceValue, 1.0);
    });

    test('parses colon ratio Split 10:1 (old:new representation)', () {
      final ratio = DividendSource.parseSplitRatio('Split 10:1');
      expect(ratio, isNotNull);
      expect(ratio!.oldFaceValue, 10.0);
      expect(ratio.newFaceValue, 1.0);
    });

    test('returns null for unrelated corporate actions', () {
      expect(DividendSource.parseSplitRatio('Dividend - Rs 5 per share'), isNull);
      expect(DividendSource.parseSplitRatio('Bonus issue 1:1'), isNull);
      expect(DividendSource.parseSplitRatio('Annual General Meeting'), isNull);
    });
  });

  group('Stock Splits - Logic & Ledger Computation', () {
    test('SPLIT adds quantity without increasing total invested capital', () {
      final txs = [
        TxRecord(
          id: 1,
          date: DateTime(2023, 1, 15),
          type: 'BUY',
          price: 500.0,
          quantity: 100,
          totalAmount: 50000.0,
        ),
        // Split 5:1 (FV 10 -> 2) gives +400 additional shares
        TxRecord(
          id: 2,
          date: DateTime(2023, 6, 1),
          type: 'SPLIT',
          price: 0.0,
          quantity: 400,
          totalAmount: 0.0,
        ),
      ];

      final state = computeHoldingState(txs);
      expect(state.quantityHeld, 500);
      // Invested capital is still 50,000
      expect(state.investedValue, 50000.0);
      // Average buy price dropped from 500.0 to 100.0
      expect(state.avgBuyPrice, 100.0);
    });

    test('Sell after split calculates remaining invested value on reduced cost', () {
      final txs = [
        TxRecord(
          id: 1,
          date: DateTime(2023, 1, 15),
          type: 'BUY',
          price: 1000.0,
          quantity: 10,
          totalAmount: 10000.0,
        ),
        // 10:1 split (+90 shares, total 100, avg cost 100.0)
        TxRecord(
          id: 2,
          date: DateTime(2023, 5, 1),
          type: 'SPLIT',
          price: 0.0,
          quantity: 90,
          totalAmount: 0.0,
        ),
        // Sell 50 shares at 150.0
        TxRecord(
          id: 3,
          date: DateTime(2023, 8, 1),
          type: 'SELL',
          price: 150.0,
          quantity: 50,
          totalAmount: 7500.0,
        ),
      ];

      final state = computeHoldingState(txs);
      expect(state.quantityHeld, 50);
      expect(state.avgBuyPrice, 100.0);
      expect(state.investedValue, 5000.0);
    });

    test('validateQuantityNeverNegative respects split quantity additions', () {
      final txs = [
        TxRecord(
          id: 1,
          date: DateTime(2023, 1, 1),
          type: 'BUY',
          price: 100.0,
          quantity: 10,
          totalAmount: 1000.0,
        ),
        TxRecord(
          id: 2,
          date: DateTime(2023, 2, 1),
          type: 'SPLIT',
          price: 0.0,
          quantity: 90,
          totalAmount: 0.0,
        ),
      ];
      final opValid = ProposedOp.add(
        TxRecord(
          id: 3,
          date: DateTime(2023, 3, 1),
          type: 'SELL',
          price: 120.0,
          quantity: 50,
          totalAmount: 6000.0,
        ),
      );
      expect(validateQuantityNeverNegative(txs, opValid).isValid, isTrue);

      // Attempting to sell 150 more would make qty negative (runningQty was 100)
      final opInvalid = ProposedOp.add(
        TxRecord(
          id: 4,
          date: DateTime(2023, 4, 1),
          type: 'SELL',
          price: 120.0,
          quantity: 150,
          totalAmount: 18000.0,
        ),
      );
      expect(validateQuantityNeverNegative(txs, opInvalid).isValid, isFalse);
    });

    test('compareTransactions orders SPLIT and BONUS before SELL and DIVIDEND on the same day', () {
      final sameDate = DateTime(2023, 5, 10);
      final buy = TxRecord(id: 1, date: sameDate, type: 'BUY', price: 100, quantity: 10, totalAmount: 1000);
      final split = TxRecord(id: 2, date: sameDate, type: 'SPLIT', price: 0, quantity: 10, totalAmount: 0);
      final bonus = TxRecord(id: 3, date: sameDate, type: 'BONUS', price: 0, quantity: 10, totalAmount: 0);
      final sell = TxRecord(id: 4, date: sameDate, type: 'SELL', price: 110, quantity: 5, totalAmount: 550);
      final div = TxRecord(id: 5, date: sameDate, type: 'DIVIDEND', price: 5, quantity: 10, totalAmount: 50);

      expect(compareTransactions(buy, split), -1); // BUY (0) before SPLIT (1)
      expect(compareTransactions(split, sell), -1); // SPLIT (1) before SELL (2)
      expect(compareTransactions(bonus, sell), -1); // BONUS (1) before SELL (2)
      expect(compareTransactions(sell, div), -1);   // SELL (2) before DIVIDEND (3)
    });
  });

  group('StocksDao - Split Transactions Database Operations', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insert and query split transactions via StocksDao', () async {
      final cardId = await db.stocksDao.insertCard(
        const StockCardsCompanion(
          ticker: Value('INFY'),
          exchange: Value('NSE'),
          stockName: Value('Infosys Ltd'),
        ),
      );

      final splitDate = DateTime(2023, 7, 1);
      final hasBefore = await db.stocksDao.hasSplitTransaction(
        cardId: cardId,
        date: splitDate,
      );
      expect(hasBefore, isFalse);

      await db.stocksDao.insertTransaction(
        StockTransactionsCompanion.insert(
          cardId: cardId,
          date: splitDate,
          type: 'SPLIT',
          price: 0.0,
          quantity: 100,
          totalAmount: 0.0,
          entryMode: 'AUTO',
        ),
      );

      final hasAfter = await db.stocksDao.hasSplitTransaction(
        cardId: cardId,
        date: splitDate,
      );
      expect(hasAfter, isTrue);

      final found = await db.stocksDao.findSplitTransaction(
        cardId: cardId,
        date: splitDate,
      );
      expect(found, isNotNull);
      expect(found!.type, 'SPLIT');
      expect(found.quantity, 100);
      expect(found.price, 0.0);
    });
  });
}
