// lib/utils/market_calendar.dart
//
// Utility functions for market schedule validation (NSE/BSE).

/// Checks if [date] falls on a weekend (Saturday or Sunday).
///
/// Weekends are always closed with no network call required.
bool isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Checks if [date] is a trading day on Indian exchanges based on weekend rules.
///
/// Returns `false` if [date] is a Saturday or Sunday.
/// Holiday determination is performed dynamically via [TradingDayService].
bool isMarketOpen(DateTime date) {
  return !isWeekend(date);
}
