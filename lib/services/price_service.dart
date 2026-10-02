// lib/services/price_service.dart
//
// Real price service routing between NSE official Bhavcopy (past dates)
// and Yahoo Finance (today's live quotes and chart data).

import 'bse_bhavcopy_source.dart';
import 'nse_bhavcopy_source.dart';
import 'yahoo_quote_source.dart';

/// Thrown when price data couldn't be fetched or parsed; user can retry.
class PriceFetchException implements Exception {
  final String message;
  const PriceFetchException(this.message);

  @override
  String toString() => message;
}

/// Thrown when today's trading range does not exist yet (pre-market or no trades).
class MarketNotOpenException implements Exception {
  final String message;
  const MarketNotOpenException([
    this.message =
        "Market hasn't opened yet today — pick a previous trading day or try after 9:15 AM IST",
  ]);

  @override
  String toString() => message;
}

/// The high/low price range for a given ticker on a specific trading day.
class PriceRange {
  final double low;
  final double high;

  const PriceRange({required this.low, required this.high});

  @override
  String toString() => 'PriceRange(low: $low, high: $high)';
}

/// Helper to check if a DateTime represents today in Indian Standard Time (IST, UTC+5:30).
bool isTodayIst(DateTime date) {
  final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  // Compare date components with date converted to IST if needed, or date-only
  return date.year == nowIst.year && date.month == nowIst.month && date.day == nowIst.day;
}

/// Returns the day's high/low range for [ticker] on [date].
///
/// Routing:
/// - If [date] is today (in IST) -> Yahoo Finance live chart meta.
/// - If [date] is a past trading day -> official NSE Bhavcopy.
///
/// Throws [MarketNotOpenException] if [date] is today and market is not open yet.
/// Throws [PriceFetchException] if data could not be retrieved, symbol is missing, or for BSE past dates.
Future<PriceRange> fetchDayPriceRange(
  String ticker,
  DateTime date, {
  String exchange = 'NSE',
  String? isin,
}) async {
  if (isTodayIst(date)) {
    return YahooQuoteSource.fetchTodayRange(ticker, exchange: exchange);
  } else {
    if (exchange.toUpperCase() == 'BSE') {
      return BseBhavcopySource.fetchDayPriceRange(ticker, date, isin: isin);
    }
    return NseBhavcopySource.fetchDayPriceRange(ticker, date, isin: isin);
  }
}

/// Returns the current market price for [ticker].
///
/// Uses Yahoo Finance.
Future<double> fetchCurrentPrice(String ticker, {String exchange = 'NSE'}) async {
  final quote = await YahooQuoteSource.fetchQuote(ticker, exchange: exchange);
  return quote.currentPrice;
}

/// Returns the previous closing price for [ticker].
///
/// Uses Yahoo Finance.
Future<double> fetchPreviousClose(String ticker, {String exchange = 'NSE'}) async {
  final quote = await YahooQuoteSource.fetchQuote(ticker, exchange: exchange);
  return quote.previousClose;
}
