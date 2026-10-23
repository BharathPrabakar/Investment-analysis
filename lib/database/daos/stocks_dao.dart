// lib/database/daos/stocks_dao.dart

import 'package:drift/drift.dart';
import '../../utils/app_constants.dart';
import '../app_database.dart';

part 'stocks_dao.g.dart';

@DriftAccessor(tables: [StockCards, StockTransactions, Tags, CardTags])
class StocksDao extends DatabaseAccessor<AppDatabase> with _$StocksDaoMixin {
  StocksDao(super.db);

  // ─── Stock Cards ────────────────────────────────────────────────────────────

  /// Get all stock cards.
  Future<List<StockCard>> getAllCards() =>
      (select(stockCards)..orderBy([(t) => OrderingTerm.asc(t.ticker)])).get();

  /// Watch all stock cards ordered by ticker.
  Stream<List<StockCard>> watchAllCards() =>
      (select(stockCards)..orderBy([(t) => OrderingTerm.asc(t.ticker)])).watch();

  /// Get a single card by id.
  Future<StockCard?> getCardById(int id) =>
      (select(stockCards)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Watch a single card by id for reactive UI updates.
  Stream<StockCard?> watchCardById(int id) =>
      (select(stockCards)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Get a single card by ticker and exchange.
  Future<StockCard?> getCardByTickerAndExchange(String ticker, String exchange) =>
      (select(stockCards)
            ..where((t) =>
                t.ticker.equals(ticker) & t.exchange.equals(exchange)))
          .getSingleOrNull();

  /// Get a single card by ticker.
  Future<StockCard?> getCardByTicker(String ticker) =>
      (select(stockCards)..where((t) => t.ticker.equals(ticker))).getSingleOrNull();

  /// Insert a new stock card. Returns the new row id.
  Future<int> insertCard(StockCardsCompanion card) =>
      into(stockCards).insert(card);

  /// Atomically creates a stock card, its tags, and its first transaction in ONE database transaction.
  Future<int> createCardWithInitialData({
    required StockCardsCompanion card,
    required List<String> tagNames,
    required StockTransactionsCompanion firstTransaction,
  }) {
    return transaction(() async {
      final cardId = await into(stockCards).insert(card);

      if (tagNames.isNotEmpty) {
        final tagIds = <int>[];
        for (final name in tagNames) {
          final existing = await (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
          final id = existing?.id ?? await into(tags).insert(TagsCompanion(name: Value(name)));
          tagIds.add(id);
        }
        await setTagsForCard(cardId, 'stock', tagIds);
      }

      await into(stockTransactions).insert(
        firstTransaction.copyWith(cardId: Value(cardId)),
      );

      return cardId;
    });
  }

  /// Update cached price fields.
  Future<void> updateCardPrice({
    required int cardId,
    required double lastPrice,
    required double prevClose,
    required DateTime fetchedAt,
  }) =>
      (update(stockCards)..where((t) => t.id.equals(cardId))).write(
        StockCardsCompanion(
          lastPrice: Value(lastPrice),
          prevClose: Value(prevClose),
          lastPriceFetchedAt: Value(fetchedAt),
        ),
      );

  /// Update the date up to which dividends have been fetched for this card.
  Future<void> updateDividendsFetchedUpto({
    required int cardId,
    required DateTime fetchedUpto,
  }) =>
      (update(stockCards)..where((t) => t.id.equals(cardId))).write(
        StockCardsCompanion(
          dividendsFetchedUpto: Value(fetchedUpto),
        ),
      );

  /// Delete a card and all its transactions (cascade handled by FK).
  Future<int> deleteCard(int cardId) =>
      (delete(stockCards)..where((t) => t.id.equals(cardId))).go();

  /// Deletes a stock card and all associated data inside a single database transaction.
  /// Explicitly deletes:
  /// (a) all rows in stock_transactions where card_id = cardId,
  /// (b) all rows in card_tags where card_id = cardId AND card_type = 'stock',
  /// (c) the stock_cards row itself.
  /// Rows in the tags table are preserved for other cards.
  Future<void> deleteCardWithAllData(int cardId) {
    return transaction(() async {
      // (a) Delete child transactions
      await (delete(stockTransactions)..where((t) => t.cardId.equals(cardId))).go();
      // (b) Delete card tag associations
      await (delete(cardTags)
            ..where((t) => t.cardId.equals(cardId) & t.cardType.equals('stock')))
          .go();
      // (c) Delete the stock card itself
      await (delete(stockCards)..where((t) => t.id.equals(cardId))).go();
    });
  }

  // ─── Transactions ────────────────────────────────────────────────────────────

  /// Get all transactions for a card, sorted by date ASC then id ASC (WAC order).
  Future<List<StockTransaction>> getTransactionsForCard(int cardId) =>
      (select(stockTransactions)
            ..where((t) => t.cardId.equals(cardId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.date),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  /// Watch transactions for a card sorted date DESC (display order).
  Stream<List<StockTransaction>> watchTransactionsForCard(int cardId) =>
      (select(stockTransactions)
            ..where((t) => t.cardId.equals(cardId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.date),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch();

  /// Insert a transaction. Returns the new row id.
  Future<int> insertTransaction(StockTransactionsCompanion tx) =>
      into(stockTransactions).insert(tx);

  /// Update an existing transaction row.
  Future<bool> updateTransaction(StockTransactionsCompanion tx) =>
      update(stockTransactions).replace(tx);

  /// Delete a transaction by id.
  Future<int> deleteTransaction(int txId) =>
      (delete(stockTransactions)..where((t) => t.id.equals(txId))).go();

  /// Delete all auto-generated transactions (DIVIDEND, BONUS with entryMode = 'AUTO') for a card.
  Future<int> deleteAutoTransactionsForCard(int cardId) =>
      (delete(stockTransactions)
            ..where((t) => t.cardId.equals(cardId) & t.entryMode.equals('AUTO')))
          .go();

  /// Find a possible duplicate: same card, same date (date only), same price, same type.
  Future<StockTransaction?> findDuplicate({
    required int cardId,
    required DateTime date,
    required double price,
    required String type,
  }) async {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    return (select(stockTransactions)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.date.isBiggerOrEqualValue(dateStart) &
              t.date.isSmallerThanValue(dateEnd) &
              t.price.equals(price) &
              t.type.equals(type)))
        .getSingleOrNull();
  }

  /// Checks if a dividend transaction already exists for this card, date, and price (per-share dividend).
  Future<bool> hasDividendTransaction({
    required int cardId,
    required DateTime date,
    required double price,
  }) async {
    final existing = await findDividendTransaction(
      cardId: cardId,
      date: date,
      price: price,
    );
    return existing != null;
  }

  /// Finds an existing dividend transaction for this card, date, and price (per-share dividend).
  Future<StockTransaction?> findDividendTransaction({
    required int cardId,
    required DateTime date,
    required double price,
  }) async {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    return (select(stockTransactions)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.type.equals('DIVIDEND') &
              t.date.isBiggerOrEqualValue(dateStart) &
              t.date.isSmallerThanValue(dateEnd) &
              t.price.equals(price)))
        .getSingleOrNull();
  }

  /// Checks if a bonus transaction already exists for this card and date.
  Future<bool> hasBonusTransaction({
    required int cardId,
    required DateTime date,
  }) async {
    final existing = await findBonusTransaction(
      cardId: cardId,
      date: date,
    );
    return existing != null;
  }

  /// Finds an existing bonus transaction for this card and date.
  Future<StockTransaction?> findBonusTransaction({
    required int cardId,
    required DateTime date,
  }) async {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    return (select(stockTransactions)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.type.equals('BONUS') &
              t.date.isBiggerOrEqualValue(dateStart) &
              t.date.isSmallerThanValue(dateEnd)))
        .getSingleOrNull();
  }

  /// Merge into an existing transaction (duplicate merge).
  Future<void> mergeIntoExistingTransaction({
    required int txId,
    required int additionalQuantity,
    required double additionalAmount,
  }) async {
    final existing = await (select(stockTransactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    await (update(stockTransactions)..where((t) => t.id.equals(txId))).write(
      StockTransactionsCompanion(
        quantity: Value(existing.quantity + additionalQuantity),
        totalAmount: Value(existing.totalAmount + additionalAmount),
      ),
    );
  }

  /// Atomically edit a transaction:
  /// - Either updates the transaction in place (preserving its id)
  /// - Or if [mergeIntoTxId] is provided, merges quantity and amount into that existing
  ///   transaction and deletes the edited transaction ([deleteTxIdOnMerge]).
  Future<void> editTransaction({
    required StockTransactionsCompanion updatedTx,
    int? mergeIntoTxId,
    int? deleteTxIdOnMerge,
    double? additionalAmountOnMerge,
    int? additionalQuantityOnMerge,
  }) async {
    return transaction(() async {
      if (mergeIntoTxId != null) {
        final existing = await (select(stockTransactions)
              ..where((t) => t.id.equals(mergeIntoTxId)))
            .getSingle();
        await (update(stockTransactions)
              ..where((t) => t.id.equals(mergeIntoTxId)))
            .write(
          StockTransactionsCompanion(
            quantity: Value(existing.quantity + (additionalQuantityOnMerge ?? 0)),
            totalAmount: Value(existing.totalAmount + (additionalAmountOnMerge ?? 0.0)),
          ),
        );
        if (deleteTxIdOnMerge != null) {
          await (delete(stockTransactions)
                ..where((t) => t.id.equals(deleteTxIdOnMerge)))
              .go();
        }
      } else {
        await update(stockTransactions).replace(updatedTx);
      }
    });
  }

  // ─── Tags ────────────────────────────────────────────────────────────────────

  /// All known tags.
  Future<List<Tag>> getAllTags() => select(tags).get();

  /// Watch all tags.
  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  /// Insert or get a tag by name. Returns the tag id.
  Future<int> upsertTag(String name) async {
    final existing =
        await (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(tags).insert(TagsCompanion(name: Value(name)));
  }

  /// Get tag ids for a card.
  Future<List<int>> getTagIdsForCard(int cardId, String cardType) async {
    final rows = await (select(cardTags)
          ..where((t) => t.cardId.equals(cardId) & t.cardType.equals(cardType)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Get full tags for a card.
  Future<List<Tag>> getTagsForCard(int cardId, String cardType) async {
    final ids = await getTagIdsForCard(cardId, cardType);
    if (ids.isEmpty) return [];
    return (select(tags)..where((t) => t.id.isIn(ids))).get();
  }

  /// Watch full tags for a card.
  Stream<List<Tag>> watchTagsForCard(int cardId, String cardType) {
    // Re-query on any change to cardTags or tags.
    return (select(cardTags)
          ..where((t) => t.cardId.equals(cardId) & t.cardType.equals(cardType)))
        .watch()
        .asyncMap((rows) async {
      final ids = rows.map((r) => r.tagId).toList();
      if (ids.isEmpty) return <Tag>[];
      return (select(tags)..where((t) => t.id.isIn(ids))).get();
    });
  }

  /// Set tags for a card (replaces existing tags).
  Future<void> setTagsForCard(
      int cardId, String cardType, List<int> tagIds) async {
    await (delete(cardTags)
          ..where((t) => t.cardId.equals(cardId) & t.cardType.equals(cardType)))
        .go();
    for (final tagId in tagIds) {
      await into(cardTags).insertOnConflictUpdate(
        CardTagsCompanion(
          cardId: Value(cardId),
          tagId: Value(tagId),
          cardType: Value(cardType),
        ),
      );
    }
  }

  /// Atomically adds a tag to a card inside its own db transaction.
  /// Validates rules: trimmed, not empty, max 30 chars, case-insensitive match, not already on card.
  /// Throws [ArgumentError] or [StateError] if blocked.
  Future<void> addTagToCard(int cardId, String cardType, String tagName) {
    return transaction(() async {
      final trimmed = tagName.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Tag name cannot be empty.');
      }
      if (trimmed.length > kMaxTagLength) {
        throw ArgumentError('Tag name cannot exceed $kMaxTagLength characters.');
      }

      // Check if tag already exists case-insensitively
      final allExistingTags = await getAllTags();
      Tag? matchedTag;
      for (final t in allExistingTags) {
        if (t.name.trim().toLowerCase() == trimmed.toLowerCase()) {
          matchedTag = t;
          break;
        }
      }

      final int tagId;
      if (matchedTag != null) {
        tagId = matchedTag.id;
      } else {
        tagId = await into(tags).insert(TagsCompanion(name: Value(trimmed)));
      }

      // Check if this tag is already on this card
      final existingCardTag = await (select(cardTags)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.cardType.equals(cardType) &
                t.tagId.equals(tagId)))
          .getSingleOrNull();

      if (existingCardTag != null) {
        throw StateError('This tag is already added to this card.');
      }

      await into(cardTags).insert(
        CardTagsCompanion(
          cardId: Value(cardId),
          tagId: Value(tagId),
          cardType: Value(cardType),
        ),
      );
    });
  }

  /// Atomically removes a tag from a card inside its own db transaction.
  /// Does NOT delete the tag from the tags table.
  Future<void> removeTagFromCard(int cardId, String cardType, int tagId) {
    return transaction(() async {
      await (delete(cardTags)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.cardType.equals(cardType) &
                t.tagId.equals(tagId)))
          .go();
    });
  }
}
