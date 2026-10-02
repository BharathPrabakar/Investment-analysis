// lib/database/app_database.dart
//
// Drift database — Investment Tracker.
// Tables: StockCards, StockTransactions, Tags, CardTags
//
// After modifying tables/DAOs run:
//   dart run build_runner build --delete-conflicting-outputs

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/stock_cards_table.dart';
import 'tables/stock_transactions_table.dart';
import 'tables/tags_table.dart';
import 'daos/stocks_dao.dart';

export 'tables/stock_cards_table.dart';
export 'tables/stock_transactions_table.dart';
export 'tables/tags_table.dart';
export 'daos/stocks_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [StockCards, StockTransactions, Tags, CardTags],
  daos: [StocksDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// Create a composite index on stock_transactions(card_id, date) for
  /// efficient per-card queries sorted by date.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_stock_tx_card_date '
            'ON stock_transactions(card_id, date)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'investment_tracker');
  }
}
