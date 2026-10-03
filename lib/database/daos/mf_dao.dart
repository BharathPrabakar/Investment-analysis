// lib/database/daos/mf_dao.dart

import 'package:drift/drift.dart';
import '../app_database.dart';

part 'mf_dao.g.dart';

@DriftAccessor(tables: [MfCards, MfTransactions, Tags, CardTags])
class MfDao extends DatabaseAccessor<AppDatabase> with _$MfDaoMixin {
  MfDao(super.db);

  Future<List<MfCard>> getAllMfCards() => select(mfCards).get();

  Stream<List<MfCard>> watchAllMfCards() => select(mfCards).watch();

  Future<MfCard?> getMfCardById(int id) =>
      (select(mfCards)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertMfCard(MfCardsCompanion card) =>
      into(mfCards).insert(card);

  Future<bool> updateMfCard(MfCard card) =>
      update(mfCards).replace(card);

  Future<int> deleteMfCard(int id) => transaction(() async {
        await (delete(cardTags)
              ..where((t) => t.cardId.equals(id) & t.cardType.equals('mf')))
            .go();
        return await (delete(mfCards)..where((t) => t.id.equals(id))).go();
      });

  Future<List<MfTransaction>> getTransactionsForCard(int cardId) =>
      (select(mfTransactions)
            ..where((t) => t.cardId.equals(cardId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.date),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Stream<List<MfTransaction>> watchTransactionsForCard(int cardId) =>
      (select(mfTransactions)
            ..where((t) => t.cardId.equals(cardId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.date),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Future<int> insertTransaction(MfTransactionsCompanion tx) =>
      into(mfTransactions).insert(tx);

  Future<bool> updateTransaction(MfTransaction tx) =>
      update(mfTransactions).replace(tx);

  Future<int> deleteTransaction(int id) =>
      (delete(mfTransactions)..where((t) => t.id.equals(id))).go();

  Future<void> linkTag(int cardId, int tagId) async {
    await into(cardTags).insert(
      CardTagsCompanion.insert(
        cardId: cardId,
        tagId: tagId,
        cardType: 'mf',
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<int> unlinkTag(int cardId, int tagId) =>
      (delete(cardTags)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.tagId.equals(tagId) &
                t.cardType.equals('mf')))
          .go();

  Future<List<Tag>> getTagsForCard(int cardId) async {
    final query = select(tags).join([
      innerJoin(
        cardTags,
        cardTags.tagId.equalsExp(tags.id) &
            cardTags.cardId.equals(cardId) &
            cardTags.cardType.equals('mf'),
      )
    ]);
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList();
  }
}
