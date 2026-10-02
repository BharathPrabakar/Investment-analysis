import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_new_app/data/local_tickers.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/logic/stock_logic.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/services/dividend_source.dart';
import 'package:my_new_app/services/trading_day_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('div_test_');
    DividendSource.cacheDirOverrideForTesting = tempDir;
    await ensureTickersLoaded();
  });

  tearDown(() async {
    DividendSource.cacheDirOverrideForTesting = null;
    DividendSource.httpClient = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    return db.close();
  });

  group('Section 1 & 2: Business Logic & Data Model', () {
    test('computeHoldingState output is identical before and after adding dividend feature (regression check)', () {
      final txsWithoutDiv = [
        TxRecord(id: 1, type: 'BUY', date: DateTime(2024, 1, 10), price: 100.0, quantity: 10, totalAmount: 1000.0),
        TxRecord(id: 2, type: 'BUY', date: DateTime(2024, 2, 10), price: 120.0, quantity: 10, totalAmount: 1200.0),
        TxRecord(id: 3, type: 'SELL', date: DateTime(2024, 3, 10), price: 150.0, quantity: 5, totalAmount: 750.0),
      ];

      final state1 = computeHoldingState(txsWithoutDiv);
      expect(state1.quantityHeld, 15);
      expect(state1.avgBuyPrice, 110.0);
      expect(state1.investedValue, 1650.0);

      // Now add DIVIDEND row
      final txsWithDiv = [
        ...txsWithoutDiv,
        TxRecord(id: 4, type: 'DIVIDEND', date: DateTime(2024, 2, 20), price: 5.0, quantity: 20, totalAmount: 100.0),
      ];

      final state2 = computeHoldingState(txsWithDiv);
      // DIVIDEND must not participate in quantity, avgBuyPrice, or investedValue
      expect(state2.quantityHeld, state1.quantityHeld);
      expect(state2.avgBuyPrice, state1.avgBuyPrice);
      expect(state2.investedValue, state1.investedValue);

      // totalDividendEarned returns 100.0
      expect(totalDividendEarned(txsWithDiv), 100.0);
    });

    test('validateQuantityNeverNegative excludes DIVIDEND rows', () {
      final existing = [
        TxRecord(id: 1, type: 'BUY', date: DateTime(2024, 1, 10), price: 100.0, quantity: 10, totalAmount: 1000.0),
        TxRecord(id: 2, type: 'DIVIDEND', date: DateTime(2024, 1, 15), price: 5.0, quantity: 10, totalAmount: 50.0),
      ];

      // Propose selling 10 shares: should be valid
      final op1 = ProposedOp.add(
        TxRecord(id: 0, type: 'SELL', date: DateTime(2024, 2, 1), price: 110.0, quantity: 10, totalAmount: 1100.0),
      );
      expect(validateQuantityNeverNegative(existing, op1).isValid, isTrue);

      // Propose selling 11 shares: should be invalid
      final op2 = ProposedOp.add(
        TxRecord(id: 0, type: 'SELL', date: DateTime(2024, 2, 1), price: 110.0, quantity: 11, totalAmount: 1210.0),
      );
      expect(validateQuantityNeverNegative(existing, op2).isValid, isFalse);
    });

    test('findDuplicateTransaction excludes DIVIDEND rows', () {
      final existing = [
        TxRecord(id: 1, type: 'DIVIDEND', date: DateTime(2024, 1, 15), price: 5.0, quantity: 10, totalAmount: 50.0),
      ];

      // Proposed dividend is not reported as duplicate in transaction entry
      final proposedDiv = TxRecord(id: 0, type: 'DIVIDEND', date: DateTime(2024, 1, 15), price: 5.0, quantity: 10, totalAmount: 50.0);
      expect(findDuplicateTransaction(existing, proposedDiv).isDuplicate, isFalse);

      final proposedBuy = TxRecord(id: 0, type: 'BUY', date: DateTime(2024, 1, 15), price: 5.0, quantity: 10, totalAmount: 50.0);
      expect(findDuplicateTransaction(existing, proposedBuy).isDuplicate, isFalse);
    });

    test('compareTransactions orders BUY before SELL before DIVIDEND on same date', () {
      final date = DateTime(2024, 5, 1);
      final div = TxRecord(id: 1, type: 'DIVIDEND', date: date, price: 5.0, quantity: 10, totalAmount: 50.0);
      final buy = TxRecord(id: 2, type: 'BUY', date: date, price: 100.0, quantity: 10, totalAmount: 1000.0);
      final sell = TxRecord(id: 3, type: 'SELL', date: date, price: 110.0, quantity: 5, totalAmount: 550.0);

      final list = [div, sell, buy]..sort(compareTransactions);
      expect(list.map((t) => t.type).toList(), ['BUY', 'SELL', 'DIVIDEND']);
    });
  });

  group('Section 3: DividendSource parsing & caching', () {
    test('parseDividendAmount extracts various currency patterns', () {
      expect(DividendSource.parseDividendAmount('Dividend - Rs 6 Per Share'), 6.0);
      expect(DividendSource.parseDividendAmount('Interim Dividend - Rs 12 Per Share'), 12.0);
      expect(DividendSource.parseDividendAmount('Interim Dividend - Rs 5.50  Per Share'), 5.5);
      expect(DividendSource.parseDividendAmount('Dividend - Re 1 Per Share'), 1.0);
      expect(DividendSource.parseDividendAmount('Interim Dividend Rs 11 Per Share/ Special Dividend Rs 46 Per Share'), 57.0);
      expect(DividendSource.parseDividendAmount('Bonus 1:1'), isNull);
    });

    test('parseMarketDate handles NSE and BSE date formats', () {
      expect(DividendSource.parseMarketDate('15-Jul-2026'), DateTime(2026, 7, 15));
      expect(DividendSource.parseMarketDate('05 Jun 2026'), DateTime(2026, 6, 5));
      expect(DividendSource.parseMarketDate('2026-06-05'), DateTime(2026, 6, 5));
      expect(DividendSource.parseMarketDate('-'), isNull);
      expect(DividendSource.parseMarketDate(null), isNull);
    });

    test('DividendSource fetches and caches NSE dividend responses', () async {
      DividendSource.httpClient = MockClient((request) async {
        if (request.url.toString() == 'https://www.nseindia.com') {
          return http.Response('', 200, headers: {'set-cookie': 'nsit=12345; path=/'});
        }
        if (request.url.toString().contains('corporates-corporateActions')) {
          final sampleNse = [
            {
              "symbol": "TCS",
              "comp": "Tata Consultancy Services Limited",
              "series": "EQ",
              "faceVal": "1",
              "subject": "Interim Dividend - Rs 12 Per Share",
              "exDate": "15-Jul-2026",
              "recDate": "15-Jul-2026"
            }
          ];
          return http.Response(jsonEncode(sampleNse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final events = await DividendSource.fetchDividends('TCS', exchange: 'NSE');
      expect(events.length, 1);
      expect(events.first.amountPerShare, 12.0);
      expect(events.first.recordDate, DateTime(2026, 7, 15));
      expect(events.first.source, 'NSE');

      // Check cache file exists
      final cacheFile = File('${tempDir.path}/div_NSE_TCS.json');
      expect(await cacheFile.exists(), isTrue);
    });

    test('DividendSource fetches and caches BSE dividend responses', () async {
      DividendSource.httpClient = MockClient((request) async {
        if (request.url.toString().contains('corporate_act.aspx')) {
          return http.Response('', 200, headers: {'set-cookie': 'bse_cookie=xyz; path=/'});
        }
        if (request.url.toString().contains('CorporateAction/w')) {
          final sampleBse = {
            "Table": [
              {
                "purpose_name": "Final Dividend",
                "BCRD_from": "05 Jun 2026",
                "Amount": 6.0
              }
            ]
          };
          return http.Response(jsonEncode(sampleBse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final events = await DividendSource.fetchDividends('500325', exchange: 'BSE', scripCode: '500325');
      expect(events.length, 1);
      expect(events.first.amountPerShare, 6.0);
      expect(events.first.recordDate, DateTime(2026, 6, 5));
      expect(events.first.source, 'BSE');

      final cacheFile = File('${tempDir.path}/div_BSE_500325.json');
      expect(await cacheFile.exists(), isTrue);
    });
  });

  group('Section 4 & 5: Auto-Detection & UI in StockCardDetail', () {
    testWidgets('Opening card auto-inserts DIVIDEND row if user held shares on record date', (tester) async {
      final dao = db.stocksDao;
      final cardId = await dao.insertCard(
        const StockCardsCompanion(
          ticker: Value('TCS'),
          exchange: Value('NSE'),
          stockName: Value('Tata Consultancy Services Limited'),
          lastPrice: Value(3500.0),
          prevClose: Value(3450.0),
        ),
      );

      // Buy transaction dated before record date (15-Jul-2026)
      await dao.insertTransaction(
        StockTransactionsCompanion.insert(
          cardId: cardId,
          type: 'BUY',
          entryMode: 'NORMAL',
          date: DateTime(2026, 6, 1),
          price: 3400.0,
          quantity: 10,
          totalAmount: 34000.0,
        ),
      );

      // Mock client that returns a dividend on 15-Jul-2026 of Rs 12
      DividendSource.httpClient = MockClient((request) async {
        if (request.url.host.contains('nseindia.com') && !request.url.path.contains('corporateActions')) {
          return http.Response('', 200, headers: {'set-cookie': 'nsit=123; path=/'});
        }
        if (request.url.toString().contains('corporates-corporateActions')) {
          final sampleNse = [
            {
              "symbol": "TCS",
              "comp": "Tata Consultancy Services Limited",
              "series": "EQ",
              "faceVal": "1",
              "subject": "Interim Dividend - Rs 12 Per Share",
              "exDate": "15-Jul-2026",
              "recDate": "15-Jul-2026"
            }
          ];
          return http.Response(jsonEncode(sampleNse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final card = (await dao.getCardById(cardId))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDbProvider(
              db: db,
              child: StockCardDetail(card: card),
            ),
          ),
        ),
      );

      final state = tester.state<StockCardDetailState>(find.byType(StockCardDetail));
      await state.checkDividends(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that DIVIDEND row was inserted
      final txs = await dao.getTransactionsForCard(cardId);
      final divTxs = txs.where((t) => t.type == 'DIVIDEND').toList();
      expect(divTxs.length, 1);
      expect(divTxs.first.quantity, 10);
      expect(divTxs.first.price, 12.0);
      expect(divTxs.first.totalAmount, 120.0);
      expect(divTxs.first.entryMode, 'AUTO');

      // Verify UI displays DIVIDEND badge, date, and payout
      expect(find.text('DIVIDEND'), findsOneWidget);
      expect(find.text('₹12/share · 10 shares held'), findsOneWidget);
      expect(find.text('+ ₹120'), findsOneWidget);
      expect(find.text('Dividend Earned (till date)'), findsOneWidget);
      expect(find.text('₹ 120'), findsOneWidget);

      // Verify DIVIDEND row has NO edit or delete buttons
      // (Only the BUY transaction should have edit/delete icons)
      final editButtons = find.byIcon(Icons.edit_outlined);
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(editButtons, findsNWidgets(1)); // exactly 1 for the BUY row
      expect(deleteButtons, findsNWidgets(1)); // exactly 1 for the BUY row
    });

    testWidgets('Buy dated AFTER record date does NOT generate a dividend', (tester) async {
      final dao = db.stocksDao;
      final cardId = await dao.insertCard(
        const StockCardsCompanion(
          ticker: Value('TCS'),
          exchange: Value('NSE'),
          stockName: Value('Tata Consultancy Services Limited'),
          lastPrice: Value(3500.0),
          prevClose: Value(3450.0),
        ),
      );

      // Buy transaction dated AFTER record date (20-Jul-2026 > 15-Jul-2026)
      await dao.insertTransaction(
        StockTransactionsCompanion.insert(
          cardId: cardId,
          type: 'BUY',
          entryMode: 'NORMAL',
          date: DateTime(2026, 7, 20),
          price: 3400.0,
          quantity: 10,
          totalAmount: 34000.0,
        ),
      );

      DividendSource.httpClient = MockClient((request) async {
        if (request.url.host.contains('nseindia.com') && !request.url.path.contains('corporateActions')) {
          return http.Response('', 200, headers: {'set-cookie': 'nsit=123; path=/'});
        }
        if (request.url.toString().contains('corporates-corporateActions')) {
          final sampleNse = [
            {
              "symbol": "TCS",
              "comp": "Tata Consultancy Services Limited",
              "series": "EQ",
              "faceVal": "1",
              "subject": "Interim Dividend - Rs 12 Per Share",
              "exDate": "15-Jul-2026",
              "recDate": "15-Jul-2026"
            }
          ];
          return http.Response(jsonEncode(sampleNse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final card = (await dao.getCardById(cardId))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDbProvider(
              db: db,
              child: StockCardDetail(card: card),
            ),
          ),
        ),
      );

      final state = tester.state<StockCardDetailState>(find.byType(StockCardDetail));
      await state.checkDividends(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final txs = await dao.getTransactionsForCard(cardId);
      final divTxs = txs.where((t) => t.type == 'DIVIDEND').toList();
      expect(divTxs, isEmpty);
      expect(find.text('DIVIDEND'), findsNothing);
    });

    testWidgets('Reopening the card does NOT duplicate the dividend row', (tester) async {
      final dao = db.stocksDao;
      final cardId = await dao.insertCard(
        const StockCardsCompanion(
          ticker: Value('TCS'),
          exchange: Value('NSE'),
          stockName: Value('Tata Consultancy Services Limited'),
          lastPrice: Value(3500.0),
          prevClose: Value(3450.0),
        ),
      );

      await dao.insertTransaction(
        StockTransactionsCompanion.insert(
          cardId: cardId,
          type: 'BUY',
          entryMode: 'NORMAL',
          date: DateTime(2026, 6, 1),
          price: 3400.0,
          quantity: 10,
          totalAmount: 34000.0,
        ),
      );

      DividendSource.httpClient = MockClient((request) async {
        if (request.url.host.contains('nseindia.com') && !request.url.path.contains('corporateActions')) {
          return http.Response('', 200, headers: {'set-cookie': 'nsit=123; path=/'});
        }
        if (request.url.toString().contains('corporates-corporateActions')) {
          final sampleNse = [
            {
              "symbol": "TCS",
              "comp": "Tata Consultancy Services Limited",
              "series": "EQ",
              "faceVal": "1",
              "subject": "Interim Dividend - Rs 12 Per Share",
              "exDate": "15-Jul-2026",
              "recDate": "15-Jul-2026"
            }
          ];
          return http.Response(jsonEncode(sampleNse), 200);
        }
        return http.Response('Not Found', 404);
      });

      final card = (await dao.getCardById(cardId))!;

      // First open
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDbProvider(
              db: db,
              child: StockCardDetail(card: card),
            ),
          ),
        ),
      );
      final state1 = tester.state<StockCardDetailState>(find.byType(StockCardDetail));
      await state1.checkDividends(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      var txs = await dao.getTransactionsForCard(cardId);
      expect(txs.where((t) => t.type == 'DIVIDEND').length, 1);

      // Reopen (new widget instance with updated card)
      final updatedCard = (await dao.getCardById(cardId))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDbProvider(
              db: db,
              child: StockCardDetail(card: updatedCard),
            ),
          ),
        ),
      );
      final state2 = tester.state<StockCardDetailState>(find.byType(StockCardDetail));
      await state2.checkDividends(updatedCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      txs = await dao.getTransactionsForCard(cardId);
      expect(txs.where((t) => t.type == 'DIVIDEND').length, 1);
    });
  });
}
