// lib/database/tables/stock_cards_table.dart

import 'package:drift/drift.dart';

/// One row per tracked stock ticker.
/// The UNIQUE constraint on [ticker] enforces one card per stock.
class StockCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ticker => text()();
  TextColumn get exchange => text()(); // "NSE" or "BSE"
  TextColumn get stockName => text()();
  RealColumn get lastPrice => real().nullable()();
  DateTimeColumn get lastPriceFetchedAt => dateTime().nullable()();
  RealColumn get prevClose => real().nullable()();
  DateTimeColumn get dividendsFetchedUpto => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ticker, exchange},
      ];
}
