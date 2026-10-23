import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_new_app/data/local_tickers.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/providers/database_provider.dart';
import 'package:my_new_app/services/bse_bhavcopy_source.dart';
import 'package:my_new_app/services/price_service.dart';
import 'package:my_new_app/services/trading_day_service.dart';
import 'package:my_new_app/stocks/create_stock_card_flow.dart';

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

  test('BSE tickers are loaded into search index and searchable by scrip code or symbol', () {
    // Search by BSE scrip code (e.g. 500325 for RELIANCE)
    final scripResults = searchTickers('500325');
    expect(scripResults, isNotEmpty);
    expect(scripResults.any((t) => t.exchange == 'BSE' && t.scripCode == '500325'), isTrue);

    // Verify that ETFs, BEES, and Mutual Funds are NOT in search results
    final beesResults = searchTickers('BEES', exchange: 'BSE');
    expect(beesResults, isEmpty);

    final mfResults = searchTickers('MUTUAL FUND', exchange: 'BSE');
    expect(mfResults, isEmpty);

    final goldBees = searchTickers('GOLDBEES', exchange: 'BSE');
    expect(goldBees, isEmpty);

    // Verify NCDs, Bonds, REITs, and InvITs are excluded
    final ncdResults = searchTickers('NCD');
    expect(ncdResults, isEmpty);

    final reitResults = searchTickers('REIT');
    expect(reitResults, isEmpty);

    final invitResults = searchTickers('INVIT');
    expect(invitResults, isEmpty);

    final pfcBond = searchTickers('752PFCL30');
    expect(pfcBond, isEmpty);

    // Search by symbol across all exchanges returns both NSE and BSE
    final bseResults = searchTickers('RELIANCE');
    expect(bseResults.any((t) => t.exchange == 'BSE'), isTrue);
    expect(bseResults.any((t) => t.exchange == 'NSE'), isTrue);

    // Search with explicit exchange filter
    final onlyBse = searchTickers('RELIANCE', exchange: 'BSE');
    expect(onlyBse.isNotEmpty, isTrue);
    expect(onlyBse.every((t) => t.exchange == 'BSE'), isTrue);

    final onlyNse = searchTickers('RELIANCE', exchange: 'NSE');
    expect(onlyNse.isNotEmpty, isTrue);
    expect(onlyNse.every((t) => t.exchange == 'NSE'), isTrue);
  });

  test('Database allows same ticker on different exchanges (UNIQUE(ticker, exchange))', () async {
    final dao = db.stocksDao;

    final nseId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('RELIANCE'),
        exchange: Value('NSE'),
        stockName: Value('Reliance Industries Ltd (NSE)'),
      ),
    );
    expect(nseId, isPositive);

    // Same ticker on BSE should succeed because unique key is (ticker, exchange)
    final bseId = await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('RELIANCE'),
        exchange: Value('BSE'),
        stockName: Value('Reliance Industries Ltd (BSE)'),
      ),
    );
    expect(bseId, isPositive);
    expect(bseId, isNot(equals(nseId)));

    // Duplicate ticker on same exchange (BSE) should throw
    expect(
      () => dao.insertCard(
        const StockCardsCompanion(
          ticker: Value('RELIANCE'),
          exchange: Value('BSE'),
          stockName: Value('Duplicate BSE'),
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  testWidgets('Create flow duplicate check is exchange-aware: allows BSE even if NSE exists', (tester) async {
    final dao = db.stocksDao;
    // Pre-insert NSE card for RELIANCE
    await dao.insertCard(
      const StockCardsCompanion(
        ticker: Value('RELIANCE'),
        exchange: Value('NSE'),
        stockName: Value('Reliance Industries Ltd'),
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
    await tester.pump(const Duration(milliseconds: 200));

    // Type RELIANCE in search
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'RELIANCE');
    await tester.pump(const Duration(milliseconds: 300));

    // The NSE card should show "Already added"
    expect(find.text('Already added'), findsWidgets);

    // The BSE option should be available and active (not marked "Already added")
    final bseFinder = find.byKey(const ValueKey('stock_tile_BSE_RELIANCE'));
    expect(bseFinder, findsOneWidget);
    await tester.tap(bseFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Advances to Step 2 (Tags)!
    expect(find.text('Add Tags'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('BseBhavcopySource parses CSV and matches by scrip code, symbol, or ISIN', () async {
    final testDate = DateTime(2026, 9, 25);
    final mockCsv = '''
TradDt,BizDt,Sgmt,Src,FinInstrmTp,FinInstrmId,ISIN,TckrSymb,SctySrs,FinInstrmNm,HghPric,LwPric
2026-09-25,2026-09-25,CM,BSE,STK,500325,INE002A01018,RELIANCE,A,RELIANCE INDUSTRIES LTD,1420.50,1390.00
2026-09-25,2026-09-25,CM,BSE,STK,524348,INE767A01016,AARTIDRUGS,B,AARTI DRUGS LTD,380.00,365.25
''';

    final tempDir = await Directory.systemTemp.createTemp('bse_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    BseBhavcopySource.cacheDirOverrideForTesting = tempDir;
    addTearDown(() => BseBhavcopySource.cacheDirOverrideForTesting = null);

    final mockClient = MockClient((request) async {
      return http.Response(mockCsv, 200, headers: {'content-type': 'text/csv'});
    });
    BseBhavcopySource.httpClient = mockClient;
    addTearDown(() => BseBhavcopySource.httpClient = null);

    // Match by symbol
    final rangeBySymbol = await BseBhavcopySource.fetchDayPriceRange('RELIANCE', testDate);
    expect(rangeBySymbol.high, 1420.50);
    expect(rangeBySymbol.low, 1390.00);

    // Match by scrip code
    final rangeByScrip = await BseBhavcopySource.fetchDayPriceRange('524348', testDate);
    expect(rangeByScrip.high, 380.00);
    expect(rangeByScrip.low, 365.25);

    // Match by ISIN
    final rangeByIsin = await BseBhavcopySource.fetchDayPriceRange('UNKNOWN_SYM', testDate, isin: 'INE002A01018');
    expect(rangeByIsin.high, 1420.50);
    expect(rangeByIsin.low, 1390.00);

    // Route via fetchDayPriceRange with exchange = BSE
    final priceServiceRange = await fetchDayPriceRange(
      'RELIANCE',
      testDate,
      exchange: 'BSE',
    );
    expect(priceServiceRange.high, 1420.50);
    expect(priceServiceRange.low, 1390.00);
  });
}
