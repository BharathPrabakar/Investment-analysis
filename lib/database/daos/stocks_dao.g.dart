// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stocks_dao.dart';

// ignore_for_file: type=lint
mixin _$StocksDaoMixin on DatabaseAccessor<AppDatabase> {
  $StockCardsTable get stockCards => attachedDatabase.stockCards;
  $StockTransactionsTable get stockTransactions =>
      attachedDatabase.stockTransactions;
  $TagsTable get tags => attachedDatabase.tags;
  $CardTagsTable get cardTags => attachedDatabase.cardTags;
  StocksDaoManager get managers => StocksDaoManager(this);
}

class StocksDaoManager {
  final _$StocksDaoMixin _db;
  StocksDaoManager(this._db);
  $$StockCardsTableTableManager get stockCards =>
      $$StockCardsTableTableManager(_db.attachedDatabase, _db.stockCards);
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.stockTransactions,
      );
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$CardTagsTableTableManager get cardTags =>
      $$CardTagsTableTableManager(_db.attachedDatabase, _db.cardTags);
}
