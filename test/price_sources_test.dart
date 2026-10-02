import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/data/local_tickers.dart';
import 'package:my_new_app/services/nse_bhavcopy_source.dart';
import 'package:my_new_app/services/yahoo_quote_source.dart';

void main() {
  HttpOverrides.global = _UnmockedHttpOverrides();

  setUpAll(() async {
    final file = File('assets/nse_tickers.json');
    if (await file.exists()) {
      final jsonStr = await file.readAsString();
      final list = (jsonDecode(jsonStr) as List<dynamic>)
          .map((e) => TickerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      setLocalTickersForTesting(list);
    }
  });

  test('YahooQuoteSource fetches real live quote for RELIANCE', () async {
    final quote = await YahooQuoteSource.fetchQuote('RELIANCE', exchange: 'NSE');
    expect(quote.currentPrice, greaterThan(0));
    expect(quote.previousClose, greaterThan(0));
    expect(quote.dayHigh, greaterThan(0));
    expect(quote.dayLow, greaterThan(0));
  });

  test('NseBhavcopySource downloads and parses real Bhavcopy for 2026-09-25', () async {
    final range = await NseBhavcopySource.fetchDayPriceRange('RELIANCE', DateTime(2026, 9, 25));
    expect(range.low, equals(1210.5));
    expect(range.high, equals(1227.4));
  });

  test('Local ticker search matches IDEA, vodafone, tata motors, TMPV, TMCV', () {
    final resIdea = searchTickers('IDEA');
    expect(resIdea.any((t) => t.symbol == 'IDEA'), isTrue);

    final resVodafone = searchTickers('vodafone');
    expect(resVodafone.any((t) => t.symbol == 'IDEA'), isTrue);

    final resTataMotors = searchTickers('tata motors');
    expect(resTataMotors.any((t) => t.symbol == 'TMPV'), isTrue);
    expect(resTataMotors.any((t) => t.symbol == 'TMCV'), isTrue);

    final resTmpv = searchTickers('TMPV');
    expect(resTmpv.first.symbol, equals('TMPV'));

    final resTmcv = searchTickers('TMCV');
    expect(resTmcv.first.symbol, equals('TMCV'));
  });

  test('TMPV matches via ISIN on past dates before October 2025 rename', () async {
    // Before Oct 2025, TMPV traded under symbol TATAMOTORS with ISIN INE155A01022.
    final range = await NseBhavcopySource.fetchDayPriceRange('TMPV', DateTime(2025, 10, 10));
    expect(range.low, equals(666.9));
    expect(range.high, equals(688.6));
  });

  test('IDEA matches on past dates', () async {
    final range = await NseBhavcopySource.fetchDayPriceRange('IDEA', DateTime(2026, 9, 25));
    expect(range.low, equals(14.08));
    expect(range.high, equals(14.38));
  });
}

class _UnmockedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = null;
  }
}
