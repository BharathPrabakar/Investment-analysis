// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mf_dao.dart';

// ignore_for_file: type=lint
mixin _$MfDaoMixin on DatabaseAccessor<AppDatabase> {
  $MfCardsTable get mfCards => attachedDatabase.mfCards;
  $MfTransactionsTable get mfTransactions => attachedDatabase.mfTransactions;
  $TagsTable get tags => attachedDatabase.tags;
  $CardTagsTable get cardTags => attachedDatabase.cardTags;
  MfDaoManager get managers => MfDaoManager(this);
}

class MfDaoManager {
  final _$MfDaoMixin _db;
  MfDaoManager(this._db);
  $$MfCardsTableTableManager get mfCards =>
      $$MfCardsTableTableManager(_db.attachedDatabase, _db.mfCards);
  $$MfTransactionsTableTableManager get mfTransactions =>
      $$MfTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.mfTransactions,
      );
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$CardTagsTableTableManager get cardTags =>
      $$CardTagsTableTableManager(_db.attachedDatabase, _db.cardTags);
}
