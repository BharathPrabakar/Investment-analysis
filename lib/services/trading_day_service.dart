// lib/services/trading_day_service.dart
//
// Automatic trading day validation service for Indian stock exchanges (NSE/BSE).
// Checks weekends, today (via Yahoo Finance quote RegularMarketTime),
// and past weekdays (via NSE Bhavcopy file existence with neighbor sanity checks).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_constants.dart';
import '../utils/market_calendar.dart';
import 'bse_bhavcopy_source.dart';
import 'nse_bhavcopy_source.dart';
import 'price_service.dart';
import 'yahoo_quote_source.dart';

enum TradingDayStatus {
  open,
  closed,
  unknown,
}

class TradingDayResult {
  final TradingDayStatus status;
  final String? message;

  const TradingDayResult({
    required this.status,
    this.message,
  });

  bool get isOpen => status == TradingDayStatus.open;
  bool get isClosed => status == TradingDayStatus.closed;
  bool get isUnknown => status == TradingDayStatus.unknown;
}

/// Function signature for fetching quote data (for testing)
typedef QuoteFetcher = Future<YahooQuote> Function(String ticker, {String exchange});

/// Service that checks whether a given date is a trading day on Indian exchanges.
class TradingDayService {
  final http.Client? _client;
  final QuoteFetcher? _quoteFetcher;

  TradingDayService({
    http.Client? client,
    QuoteFetcher? quoteFetcher,
  })  : _client = client, // ignore: prefer_initializing_formals
        _quoteFetcher = quoteFetcher; // ignore: prefer_initializing_formals

  // ignore: unnecessary_getters_setters
  static TradingDayService get instance => _instance;
  static set instance(TradingDayService service) => _instance = service;
  static TradingDayService _instance = TradingDayService();

  static const String _defaultTicker = kTradingDayProbeTicker;

  // In-memory cache of verified closed dates ("YYYYMMDD")
  static final Set<String> _closedDatesCache = {};
  static bool _diskCacheLoaded = false;

  static String _formatDate(DateTime date) => DateFormat('yyyyMMdd').format(date);

  static Directory? cacheDirOverrideForTesting;

  static Future<Directory> _getCacheDirectory() async {
    if (cacheDirOverrideForTesting != null) {
      return cacheDirOverrideForTesting!;
    }
    Directory parentDir;
    try {
      parentDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      parentDir = Directory.systemTemp;
    }
    final dir = Directory('${parentDir.path}/bhavcopy_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _loadClosedCacheIfNeeded() async {
    if (_diskCacheLoaded) return;
    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/closed_trading_days.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (jsonDecode(content) as List<dynamic>).cast<String>();
        _closedDatesCache.addAll(list);
      }
    } catch (_) {
      // Ignore cache load failure
    } finally {
      _diskCacheLoaded = true;
    }
  }

  static void clearCacheForTesting() {
    _closedDatesCache.clear();
    _diskCacheLoaded = false;
  }

  static Future<void> _persistClosedDate(DateTime date) async {
    // Only cache permanently when date is more than 3 days in the past
    final now = DateTime.now();
    final differenceInDays = now.difference(date).inDays;
    if (differenceInDays <= 3) return;

    final dateKey = _formatDate(date);
    _closedDatesCache.add(dateKey);

    try {
      final dir = await _getCacheDirectory();
      final file = File('${dir.path}/closed_trading_days.json');
      await file.writeAsString(jsonEncode(_closedDatesCache.toList()));
    } catch (_) {
      // Ignore disk write failure
    }
  }

  /// Exposed method returning [TradingDayStatus] as specified in prompt.
  Future<TradingDayStatus> checkTradingDay(DateTime date, {String exchange = 'NSE'}) async {
    final result = await checkTradingDayDetailed(date, exchange: exchange);
    return result.status;
  }

  /// Detailed check providing optional failure/status message.
  Future<TradingDayResult> checkTradingDayDetailed(DateTime date, {String exchange = 'NSE'}) async {
    // a) Weekend -> closed (no fetch)
    if (isWeekend(date)) {
      return const TradingDayResult(
        status: TradingDayStatus.closed,
        message: 'Weekends are closed.',
      );
    }

    // Check disk-persisted closed cache
    await _loadClosedCacheIfNeeded();
    final dateKey = '${exchange.toUpperCase()}_${_formatDate(date)}';
    final legacyKey = _formatDate(date);
    if (_closedDatesCache.contains(dateKey) || _closedDatesCache.contains(legacyKey)) {
      return const TradingDayResult(
        status: TradingDayStatus.closed,
        message: 'Market closed on this holiday.',
      );
    }

    // b) Today (IST date)
    if (isTodayIst(date)) {
      return _checkTodayIst(exchange: exchange);
    }

    // c) Past weekday
    return _checkPastWeekday(date, exchange: exchange);
  }

  Future<TradingDayResult> _checkTodayIst({String exchange = 'NSE'}) async {
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    // If current IST time is before 9:15 AM -> return/throw market hasn't opened yet
    final marketOpenIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, kMarketOpenHourIst, kMarketOpenMinuteIst);
    if (nowIst.isBefore(marketOpenIst)) {
      return const TradingDayResult(
        status: TradingDayStatus.unknown,
        message: "Market hasn't opened yet today — pick a previous trading day or try after 9:15 AM IST",
      );
    }

    // After 9:15 AM: check Yahoo quote regularMarketTime
    try {
      final quoteFetcher = _quoteFetcher;
      final quote = quoteFetcher != null
          ? await quoteFetcher(_defaultTicker, exchange: exchange)
          : await YahooQuoteSource.fetchQuote(_defaultTicker, exchange: exchange);
      final quoteIst = quote.marketTime;
      final isSameDay = quoteIst.year == nowIst.year &&
          quoteIst.month == nowIst.month &&
          quoteIst.day == nowIst.day;

      if (!isSameDay) {
        // regularMarketTime is NOT today's IST date -> closed (holiday)
        return const TradingDayResult(
          status: TradingDayStatus.closed,
          message: 'Markets are closed today (holiday).',
        );
      }

      // Quote is from today -> open
      return const TradingDayResult(status: TradingDayStatus.open);
    } catch (_) {
      // Fetch failure -> unknown (never cache unknown)
      return const TradingDayResult(
        status: TradingDayStatus.unknown,
        message: "Couldn't verify the market calendar — please retry",
      );
    }
  }

  Future<TradingDayResult> _checkPastWeekday(DateTime date, {String exchange = 'NSE'}) async {
    final isBse = exchange.toUpperCase() == 'BSE';
    final dateKey = _formatDate(date);

    // If already downloaded and cached locally on disk or memory -> open
    final cacheDir = await _getCacheDirectory();
    final cacheFile = isBse
        ? File('${cacheDir.path}/bse_bhavcopy_$dateKey.json')
        : File('${cacheDir.path}/bhavcopy_$dateKey.json');
    if (await cacheFile.exists()) {
      return const TradingDayResult(status: TradingDayStatus.open);
    }

    // Try downloading/probing the Bhavcopy for that date
    final status = await _probeBhavcopy(date, isBse: isBse);
    if (status == 200) {
      return const TradingDayResult(status: TradingDayStatus.open);
    }

    if (status == 404) {
      // Sanity check: try bhavcopy of up to two nearby weekdays
      // (previous and next weekday that are not this date).
      final prevWeekday = _getPreviousWeekday(date);
      final nextWeekday = _getNextWeekday(date);

      final now = DateTime.now();
      // Only check next weekday if it's not today or future
      final isNextEligible = !isTodayIst(nextWeekday) && nextWeekday.isBefore(now);

      var anyNeighborDownloaded = false;

      // Check previous weekday
      final prevStatus = await _probeBhavcopy(prevWeekday, isBse: isBse);
      if (prevStatus == 200) {
        anyNeighborDownloaded = true;
      }

      // Check next weekday if eligible and not already confirmed
      if (!anyNeighborDownloaded && isNextEligible) {
        final nextStatus = await _probeBhavcopy(nextWeekday, isBse: isBse);
        if (nextStatus == 200) {
          anyNeighborDownloaded = true;
        }
      }

      // If next weekday is not eligible (e.g. today or future), check 2 weekdays before
      if (!anyNeighborDownloaded && !isNextEligible) {
        final prevPrevWeekday = _getPreviousWeekday(prevWeekday);
        final prevPrevStatus = await _probeBhavcopy(prevPrevWeekday, isBse: isBse);
        if (prevPrevStatus == 200) {
          anyNeighborDownloaded = true;
        }
      }

      if (anyNeighborDownloaded) {
        // At least one neighbor downloads fine -> confirmed closed (holiday)
        await _persistClosedDate(date);
        return const TradingDayResult(
          status: TradingDayStatus.closed,
          message: 'Markets were closed (holiday).',
        );
      } else {
        // None do -> unknown (source probably down or blocked, never cache unknown)
        return const TradingDayResult(
          status: TradingDayStatus.unknown,
          message: "Couldn't verify the market calendar — please retry",
        );
      }
    }

    // Network error, timeout, 403, 5xx -> unknown
    return const TradingDayResult(
      status: TradingDayStatus.unknown,
      message: "Couldn't verify the market calendar — please retry",
    );
  }

  /// Probes the bhavcopy for [date].
  /// If cached on disk, returns 200 immediately.
  /// Otherwise performs HTTP GET or delegates to BhavcopySource.
  /// Returns HTTP status code (e.g. 200, 404) or -1 on network exception/timeout.
  Future<int> _probeBhavcopy(DateTime date, {bool isBse = false}) async {
    final dateKey = _formatDate(date);
    final cacheDir = await _getCacheDirectory();
    final cacheFile = isBse
        ? File('${cacheDir.path}/bse_bhavcopy_$dateKey.json')
        : File('${cacheDir.path}/bhavcopy_$dateKey.json');
    if (await cacheFile.exists()) {
      return 200;
    }

    final client = _client ?? http.Client();
    final headers = const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': 'https://www.nseindia.com/',
    };

    if (isBse) {
      final isUdiff = !date.isBefore(BseBhavcopySource.bseUdiffCutoff);
      final url = BseBhavcopySource.getBseBhavcopyUrl(date);
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await client.get(
            Uri.parse(url),
            headers: {
              ...headers,
              'Referer': 'https://www.bseindia.com/',
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            if (isUdiff) {
              final body = response.body.trim();
              if (body.startsWith('<!DOCTYPE') || body.startsWith('<html') || body.length < 200) {
                return 404; // BSE returns HTML error page on closed days
              }
            } else {
              // Legacy ZIP archive: check that it contains a valid zip header or has content
              if (response.bodyBytes.length < 50) {
                return 404;
              }
            }
            try {
              await BseBhavcopySource.ensureBhavcopyCached(date);
            } catch (_) {}
            return 200;
          }
          if (response.statusCode == 404) {
            return 404;
          }
          if (attempt == 1) {
            return response.statusCode;
          }
        } catch (e) {
          if (attempt == 1) {
            return -1;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      return -1;
    }

    final url = NseBhavcopySource.getNseBhavcopyUrl(date);
    final uri = Uri.parse(url);

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await client.get(
          uri,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          // When downloaded ok, we can cache it by parsing via NseBhavcopySource
          // so it's ready for price range queries without re-downloading.
          try {
            await NseBhavcopySource.ensureBhavcopyCached(date);
          } catch (_) {
            // Even if full parsing failed, we got 200 from NSE
          }
          return 200;
        }
        if (response.statusCode == 404) {
          return 404;
        }
        if (attempt == 1) {
          return response.statusCode;
        }
      } catch (e) {
        if (attempt == 1) {
          return -1; // Network error / timeout
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return -1;
  }

  static DateTime _getPreviousWeekday(DateTime date) {
    var prev = date.subtract(const Duration(days: 1));
    while (isWeekend(prev)) {
      prev = prev.subtract(const Duration(days: 1));
    }
    return prev;
  }

  static DateTime _getNextWeekday(DateTime date) {
    var next = date.add(const Duration(days: 1));
    while (isWeekend(next)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}
