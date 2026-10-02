// lib/database/tables/stock_transactions_table.dart

import 'package:drift/drift.dart';
import 'stock_cards_table.dart';

/// Each row is a single BUY or SELL transaction for a stock card.
class StockTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key -> stock_cards.id
  /// The cascade delete is handled by the DB migration (SQLite pragma + FK clause).
  IntColumn get cardId => integer().references(StockCards, #id)();

  /// "BUY", "SELL", or "DIVIDEND"
  TextColumn get type => text()();

  /// "NORMAL", "AVG", or "AUTO"
  TextColumn get entryMode => text()();

  /// Date-only (time portion is ignored in business logic)
  DateTimeColumn get date => dateTime()();

  RealColumn get price => real()();
  IntColumn get quantity => integer()();

  /// Stored as price * quantity at the time of entry. Never recomputed on read.
  RealColumn get totalAmount => real()();
}
