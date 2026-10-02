import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_new_app/services/trading_day_service.dart';
import 'package:my_new_app/services/yahoo_quote_source.dart';

void main() {
  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('trading_day_test_');
    TradingDayService.cacheDirOverrideForTesting = tempTestDir;
    TradingDayService.clearCacheForTesting();
  });

  tearDown(() async {
    TradingDayService.cacheDirOverrideForTesting = null;
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('TradingDayService tests', () {
    // (a) weekend is closed with no fetch
    test('(a) weekend is closed with no fetch', () async {
      var fetchAttempted = false;
      final mockClient = MockClient((request) async {
        fetchAttempted = true;
        return http.Response('OK', 200);
      });

      final service = TradingDayService(
        client: mockClient,
        quoteFetcher: (ticker, {exchange = 'NSE'}) async {
          fetchAttempted = true;
          throw Exception('Should not be called');
        },
      );

      // Saturday
      final sat = DateTime(2026, 9, 26);
      final satStatus = await service.checkTradingDay(sat);
      expect(satStatus, equals(TradingDayStatus.closed));

      // Sunday
      final sun = DateTime(2026, 9, 27);
      final sunStatus = await service.checkTradingDay(sun);
      expect(sunStatus, equals(TradingDayStatus.closed));

      expect(fetchAttempted, isFalse);
    });

    // (b) a past weekday whose file 404s while a neighbouring day's file exists is closed
    test('(b) a past weekday whose file 404s while a neighbouring day\'s file exists is closed', () async {
      // Date: 2026-09-24 (Thursday) returns 404
      // Neighbor: 2026-09-23 (Wednesday) returns 200
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('20260924')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path.contains('20260923')) {
          return http.Response('OK', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = TradingDayService(client: mockClient);
      final status = await service.checkTradingDay(DateTime(2026, 9, 24));
      expect(status, equals(TradingDayStatus.closed));
    });

    // (c) a 404 where no neighbouring file downloads is unknown
    test('(c) a 404 where no neighbouring file downloads is unknown', () async {
      // Date and all neighbors return 404 or fail
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = TradingDayService(client: mockClient);
      final status = await service.checkTradingDay(DateTime(2026, 9, 24));
      expect(status, equals(TradingDayStatus.unknown));
    });

    // (d) a normal past weekday is open
    test('(d) a normal past weekday is open', () async {
      final mockClient = MockClient((request) async {
        return http.Response('OK', 200);
      });

      final service = TradingDayService(client: mockClient);
      final status = await service.checkTradingDay(DateTime(2026, 9, 25));
      expect(status, equals(TradingDayStatus.open));
    });

    // (e) network error is unknown
    test('(e) network error is unknown', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network connection failed');
      });

      final service = TradingDayService(client: mockClient);
      final status = await service.checkTradingDay(DateTime(2026, 9, 25));
      expect(status, equals(TradingDayStatus.unknown));
    });

    // (f) today with a stale quote timestamp after 9:15 AM IST is closed
    test('(f) today with a stale quote timestamp after 9:15 AM IST is closed', () async {
      final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final todayIstDate = DateTime(nowIst.year, nowIst.month, nowIst.day);

      // Create a stale quote (from yesterday)
      final staleDate = nowIst.subtract(const Duration(days: 1));

      final service = TradingDayService(
        quoteFetcher: (ticker, {exchange = 'NSE'}) async {
          return YahooQuote(
            currentPrice: 1000,
            previousClose: 990,
            dayHigh: 1010,
            dayLow: 980,
            marketTime: staleDate,
          );
        },
      );

      final status = await service.checkTradingDay(todayIstDate);
      expect(status, equals(TradingDayStatus.closed));
    });

    // (g) a closed result older than 3 days is cached and not re-fetched
    test('(g) a closed result older than 3 days is cached and not re-fetched', () async {
      final targetDate = DateTime(2026, 9, 15); // > 3 days in past
      var networkCallCount = 0;

      final mockClient = MockClient((request) async {
        networkCallCount++;
        if (request.url.path.contains('20260915')) {
          return http.Response('Not Found', 404);
        }
        // Neighboring day returns 200
        return http.Response('OK', 200);
      });

      final service = TradingDayService(client: mockClient);

      // First check: should probe network and determine closed, then persist to cache
      final status1 = await service.checkTradingDay(targetDate);
      expect(status1, equals(TradingDayStatus.closed));
      final callsAfterFirstCheck = networkCallCount;
      expect(callsAfterFirstCheck, greaterThan(0));

      // Second check: should read from cache with 0 additional network calls
      final status2 = await service.checkTradingDay(targetDate);
      expect(status2, equals(TradingDayStatus.closed));
      expect(networkCallCount, equals(callsAfterFirstCheck));
    });
  });
}
