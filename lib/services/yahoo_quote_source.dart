// lib/services/yahoo_quote_source.dart
//
// Yahoo Finance live quote and chart data provider.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';
import 'price_service.dart';

class YahooQuote {
  final double currentPrice;
  final double previousClose;
  final double dayHigh;
  final double dayLow;
  final DateTime marketTime;

  const YahooQuote({
    required this.currentPrice,
    required this.previousClose,
    required this.dayHigh,
    required this.dayLow,
    required this.marketTime,
  });
}

class YahooQuoteSource {
  static const Duration timeoutDuration = Duration(seconds: 10);

  /// Fetch live quote data for [ticker] on [exchange] ("NSE" or "BSE").
  static Future<YahooQuote> fetchQuote(String ticker, {String exchange = 'NSE'}) async {
    final suffix = exchange.toUpperCase() == 'BSE' ? '.BO' : '.NS';
    final symbol = '$ticker$suffix';
    final uri = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$symbol');

    final http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(timeoutDuration);
    } catch (e) {
      throw PriceFetchException('Failed to connect to price service: $e');
    }

    if (response.statusCode != 200) {
      throw PriceFetchException('Price service returned HTTP ${response.statusCode} for $ticker');
    }

    try {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = jsonMap['chart'] as Map<String, dynamic>?;
      final results = chart?['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw PriceFetchException('No quote data found for $ticker');
      }

      final meta = results[0]['meta'] as Map<String, dynamic>?;
      if (meta == null) {
        throw PriceFetchException('Malformed quote data for $ticker');
      }

      final regularMarketPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
      final regularMarketDayHigh = (meta['regularMarketDayHigh'] as num?)?.toDouble();
      final regularMarketDayLow = (meta['regularMarketDayLow'] as num?)?.toDouble();
      final previousClose = ((meta['previousClose'] ?? meta['chartPreviousClose']) as num?)?.toDouble();
      final regularMarketTimeSec = (meta['regularMarketTime'] as num?)?.toInt();

      if (regularMarketPrice == null || regularMarketPrice <= 0) {
        throw PriceFetchException('Invalid market price for $ticker');
      }
      if (previousClose == null || previousClose <= 0) {
        throw PriceFetchException('Invalid previous close for $ticker');
      }
      if (regularMarketTimeSec == null) {
        throw PriceFetchException('Missing market time for $ticker');
      }

      final marketTimeUtc = DateTime.fromMillisecondsSinceEpoch(regularMarketTimeSec * 1000, isUtc: true);
      // IST is UTC + 5:30
      final marketTimeIst = marketTimeUtc.add(const Duration(hours: 5, minutes: 30));

      return YahooQuote(
        currentPrice: regularMarketPrice,
        previousClose: previousClose,
        dayHigh: regularMarketDayHigh ?? 0,
        dayLow: regularMarketDayLow ?? 0,
        marketTime: marketTimeIst,
      );
    } on PriceFetchException {
      rethrow;
    } catch (e) {
      throw PriceFetchException('Failed to parse quote data for $ticker: $e');
    }
  }

  /// Fetch today's day price range with strict MarketNotOpenException check.
  static Future<PriceRange> fetchTodayRange(String ticker, {String exchange = 'NSE'}) async {
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    // Rule 1: IST time before 9:15 AM
    final marketOpenIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, kMarketOpenHourIst, kMarketOpenMinuteIst);
    if (nowIst.isBefore(marketOpenIst)) {
      throw const MarketNotOpenException();
    }

    final quote = await fetchQuote(ticker, exchange: exchange);

    // Rule 2: regularMarketTime must be from today in IST
    final quoteIst = quote.marketTime;
    final isSameDate = quoteIst.year == nowIst.year &&
        quoteIst.month == nowIst.month &&
        quoteIst.day == nowIst.day;

    if (!isSameDate) {
      throw const MarketNotOpenException();
    }

    // Rule 3: Day high / low missing or zero
    if (quote.dayHigh <= 0 || quote.dayLow <= 0) {
      throw const MarketNotOpenException();
    }

    return PriceRange(low: quote.dayLow, high: quote.dayHigh);
  }
}
