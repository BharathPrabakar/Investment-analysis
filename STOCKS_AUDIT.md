# STOCKS AUDIT: Comprehensive Implementation Verification

This audit document details what is **actually implemented** in the codebase as of now. Every section is based directly on the actual source code files without smoothing over design discrepancies.

---

## 1. DATABASE SCHEMA

### 1.1 Drift Table Classes (Source Code)

#### `StockCards` (`lib/database/tables/stock_cards_table.dart`)
```dart
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

  @override
  List<Set<Column>> get uniqueKeys => [
        {ticker},
      ];
}
```

#### `StockTransactions` (`lib/database/tables/stock_transactions_table.dart`)
```dart
// lib/database/tables/stock_transactions_table.dart

import 'package:drift/drift.dart';
import 'stock_cards_table.dart';

/// Each row is a single BUY or SELL transaction for a stock card.
class StockTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key -> stock_cards.id
  /// The cascade delete is handled by the DB migration (SQLite pragma + FK clause).
  IntColumn get cardId => integer().references(StockCards, #id)();

  /// "BUY" or "SELL"
  TextColumn get type => text()();

  /// "NORMAL" or "AVG"
  TextColumn get entryMode => text()();

  /// Date-only (time portion is ignored in business logic)
  DateTimeColumn get date => dateTime()();

  RealColumn get price => real()();
  IntColumn get quantity => integer()();

  /// Stored as price * quantity at the time of entry. Never recomputed on read.
  RealColumn get totalAmount => real()();
}
```

#### `Tags` and `CardTags` (`lib/database/tables/tags_table.dart`)
```dart
// lib/database/tables/tags_table.dart

import 'package:drift/drift.dart';

/// Generic tags that can be associated with any card type.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Tag names are globally unique across all investment types.
  TextColumn get name => text().unique()();
}

/// Join table linking tags to cards of any investment type.
/// [cardType] disambiguates which table [cardId] belongs to (e.g. "stock").
class CardTags extends Table {
  IntColumn get cardId => integer()();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// Discriminator: "stock", "fd", "mf", etc.
  TextColumn get cardType => text()();

  @override
  Set<Column> get primaryKey => {cardId, tagId, cardType};
}
```

---

### 1.2 Plain Column List per Table

#### Table: `stock_cards`
- **`id`**: `INTEGER`, NOT NULL, AUTOINCREMENT, Primary Key. Default: none.
- **`ticker`**: `TEXT`, NOT NULL. Default: none. Unique constraint: `{ticker}`.
- **`exchange`**: `TEXT`, NOT NULL ("NSE" / "BSE"). Default: none.
- **`stock_name`**: `TEXT`, NOT NULL. Default: none.
- **`last_price`**: `REAL`, NULLABLE. Default: null.
- **`last_price_fetched_at`**: `DATETIME` (stored as integer timestamp by Drift), NULLABLE. Default: null.
- **`prev_close`**: `REAL`, NULLABLE. Default: null.
- **Created/Updated timestamps**: None.

#### Table: `stock_transactions`
- **`id`**: `INTEGER`, NOT NULL, AUTOINCREMENT, Primary Key. Default: none.
- **`card_id`**: `INTEGER`, NOT NULL. Foreign Key -> `stock_cards(id)`. Default: none. Note: references `StockCards(#id)` without explicit `onDelete: KeyAction.cascade` in Dart DSL.
- **`type`**: `TEXT`, NOT NULL ("BUY" / "SELL"). Default: none.
- **`entry_mode`**: `TEXT`, NOT NULL ("NORMAL" / "AVG"). Default: none.
- **`date`**: `DATETIME` (integer timestamp), NOT NULL. Default: none.
- **`price`**: `REAL`, NOT NULL. Default: none.
- **`quantity`**: `INTEGER`, NOT NULL. Default: none.
- **`total_amount`**: `REAL`, NOT NULL. Default: none.
- **Created/Updated timestamps**: None.

#### Table: `tags`
- **`id`**: `INTEGER`, NOT NULL, AUTOINCREMENT, Primary Key. Default: none.
- **`name`**: `TEXT`, NOT NULL, UNIQUE. Default: none.
- **Created/Updated timestamps**: None.

#### Table: `card_tags`
- **`card_id`**: `INTEGER`, NOT NULL. Part of Composite Primary Key `{card_id, tag_id, card_type}`. Foreign key constraint to `stock_cards`: **None** in Dart schema definition (declared as raw `IntColumn get cardId => integer()();` because it is polymorphic across card types via `cardType`).
- **`tag_id`**: `INTEGER`, NOT NULL. Part of Composite Primary Key `{card_id, tag_id, card_type}`. Foreign Key -> `tags(id)` with `onDelete: KeyAction.cascade`.
- **`card_type`**: `TEXT`, NOT NULL ("stock", etc.). Part of Composite Primary Key `{card_id, tag_id, card_type}`.
- **Created/Updated timestamps**: None.

---

### 1.3 Schema Version, MigrationStrategy, and Indexes

#### Schema Version & MigrationStrategy (`lib/database/app_database.dart`)
```dart
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
      );
```

#### Indexes Actually Created
1. **Explicit Custom Index**:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_stock_tx_card_date ON stock_transactions(card_id, date)
   ```
2. **Implicit Index from Unique Constraints**:
   - `stock_cards(ticker)` &rarr; SQLite automatically generates a unique index for `{ticker}`.
   - `tags(name)` &rarr; SQLite automatically generates a unique index for `{name}`.
3. **Implicit Index from Primary Keys**:
   - Primary key indexes for `stock_cards(id)`, `stock_transactions(id)`, `tags(id)`, and composite `card_tags(card_id, tag_id, card_type)`.

---

### 1.4 SQLite Foreign Key Enforcement & Delete Behavior

- **`PRAGMA foreign_keys`**: **NOT explicitly enabled in code**. Drift on native platforms (via `driftDatabase` or `NativeDatabase`) does not execute `PRAGMA foreign_keys = ON;` unless specified in `beforeOpen` callback of `MigrationStrategy`.
- **Relationship delete behavior**:
  - `cardTags.cardId` does **not** have a foreign key definition to `stock_cards` in the Drift table class.
  - `stockTransactions.cardId` references `StockCards, #id`, but has no `onDelete: KeyAction.cascade` in Dart, and foreign keys are not guaranteed active at the SQLite connection pragma level.
  - **Actual Deletion Mechanism**: The application handles this explicitly at the DAO layer: `StocksDao.deleteCardWithAllData` explicitly deletes child `stock_transactions` and child `card_tags` rows first inside an explicit database `transaction(...)` before deleting the `stock_cards` row itself.

---

### 1.5 Ticker List Storage
- **Storage Location**: Stored as a bundled asset and loaded into an in-memory index; **NOT stored in the SQLite database**.
- **File Name**: `assets/nse_tickers.json` (derived from `assets/EQUITY_L.csv` via `scripts/update_nse_tickers.dart`).
- **Number of Entries**: **2,565** equities.
- **Fields kept per entry**:
  - `symbol`
  - `company_name`
  - `exchange` ("NSE")
  - `isin`
- **Series filter**: Filtered strictly to series `EQ` and `BE` only.

---

## 2. DAO (`lib/database/daos/stocks_dao.dart`)

### 2.1 Complete List of DAO Methods

| Method Signature | Description |
|---|---|
| `Stream<List<StockCard>> watchAllCards()` | Watches all stock cards ordered ascending by ticker. |
| `Future<StockCard?> getCardById(int id)` | Gets a single stock card by primary key ID or null. |
| `Stream<StockCard?> watchCardById(int id)` | Reactive stream watching a single stock card by ID. |
| `Future<StockCard?> getCardByTicker(String ticker)` | Queries a single stock card by unique ticker. |
| `Future<int> insertCard(StockCardsCompanion card)` | Inserts a new row into `stock_cards` and returns generated ID. |
| `Future<void> updateCardPrice({required int cardId, required double lastPrice, required double prevClose, required DateTime fetchedAt})` | Updates cached market price, prev close, and timestamp. |
| `Future<int> deleteCard(int cardId)` | Deletes a single card from `stock_cards` table by ID. |
| `Future<void> deleteCardWithAllData(int cardId)` | Deletes transactions, card tags, and the card row inside a single DB transaction. |
| `Future<List<StockTransaction>> getTransactionsForCard(int cardId)` | Returns transactions for a card sorted `date ASC, id ASC`. |
| `Stream<List<StockTransaction>> watchTransactionsForCard(int cardId)` | Watches transactions for a card sorted `date DESC, id DESC`. |
| `Future<int> insertTransaction(StockTransactionsCompanion tx)` | Inserts a single transaction row into `stock_transactions`. |
| `Future<bool> updateTransaction(StockTransactionsCompanion tx)` | Replaces an existing transaction row by primary key. |
| `Future<int> deleteTransaction(int txId)` | Deletes a single transaction by primary key ID. |
| `Future<StockTransaction?> findDuplicate({required int cardId, required DateTime date, required double price, required String type})` | Queries DB for existing transaction with identical cardId, day, price, and type. |
| `Future<void> mergeIntoExistingTransaction({required int txId, required int additionalQuantity, required double additionalAmount})` | Adds quantity and total amount into an existing transaction row. |
| `Future<List<Tag>> getAllTags()` | Fetches all tags from the `tags` table. |
| `Stream<List<Tag>> watchAllTags()` | Watches all tags from the `tags` table. |
| `Future<int> upsertTag(String name)` | Inserts tag if missing or returns existing tag ID. |
| `Future<List<int>> getTagIdsForCard(int cardId, String cardType)` | Queries `card_tags` for tag IDs associated with a card. |
| `Future<List<Tag>> getTagsForCard(int cardId, String cardType)` | Resolves full `Tag` entities associated with a card. |
| `Stream<List<Tag>> watchTagsForCard(int cardId, String cardType)` | Reactive stream resolving full `Tag` entities for a card. |
| `Future<void> setTagsForCard(int cardId, String cardType, List<int> tagIds)` | Replaces existing card tag associations for a card. |

---

### 2.2 Quoted DAO Code

#### `findDuplicate`
```dart
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
```

#### `mergeIntoExistingTransaction`
```dart
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
```

#### `deleteCardWithAllData`
```dart
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
```

#### Method inserting card together with its first transaction
**Finding**: There is **no combined method in `StocksDao`** that inserts both the card and first transaction inside a single database transaction.
Instead, creation is orchestrated in the UI layer in `CreateStockCardFlow._createCard` (`lib/stocks/create_stock_card_flow.dart` lines 54-93):

```dart
  Future<void> _createCard() async {
    assert(_selectedTicker != null && _pendingTx != null);
    final db = AppDbProvider.of(context);
    final dao = db.stocksDao;

    // Insert card
    final cardId = await dao.insertCard(
      StockCardsCompanion(
        ticker: drift.Value(_selectedTicker!.symbol),
        exchange: drift.Value(_selectedTicker!.exchange),
        stockName: drift.Value(_selectedTicker!.companyName),
      ),
    );

    // Upsert tags and associate
    final tagIds = <int>[];
    for (final name in _selectedTagNames) {
      final id = await dao.upsertTag(name);
      tagIds.add(id);
    }
    if (tagIds.isNotEmpty) {
      await dao.setTagsForCard(cardId, 'stock', tagIds);
    }

    // Insert first transaction
    final tx = _pendingTx!;
    await dao.insertTransaction(
      StockTransactionsCompanion(
        cardId: drift.Value(cardId),
        type: drift.Value(tx.type),
        entryMode: drift.Value(tx.entryMode),
        date: drift.Value(tx.date),
        price: drift.Value(tx.price),
        quantity: drift.Value(tx.quantity),
        totalAmount: drift.Value(tx.totalAmount),
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }
```
- **Does card + first transaction creation happen inside one database transaction?**: **No.** It currently executes multiple sequential awaits (`dao.insertCard`, `dao.upsertTag`, `dao.setTagsForCard`, and `dao.insertTransaction`) without wrapping them in `db.transaction(...)`.

---

## 3. BUSINESS LOGIC (`lib/logic/stock_logic.dart`)

### 3.1 Quoted Core Logic

#### `computeHoldingState`
```dart
HoldingState computeHoldingState(List<TxRecord> transactions) {
  int qty = 0;
  double totalCost = 0;

  for (final tx in transactions) {
    if (tx.type == 'BUY') {
      totalCost += tx.totalAmount;
      qty += tx.quantity;
    } else {
      // SELL: reduce quantity; cost basis per remaining share is unchanged
      qty -= tx.quantity;
      if (qty <= 0) {
        qty = 0;
        totalCost = 0;
      } else {
        // Remove proportional cost
        final avgCost = totalCost / (qty + tx.quantity);
        totalCost -= avgCost * tx.quantity;
      }
    }
  }

  if (qty == 0) return HoldingState.zero;

  final avg = totalCost / qty;
  return HoldingState(
    quantityHeld: qty,
    avgBuyPrice: double.parse(avg.toStringAsFixed(4)),
    investedValue: double.parse(totalCost.toStringAsFixed(2)),
  );
}
```

#### `validateQuantityNeverNegative`
```dart
ValidationResult validateQuantityNeverNegative(
  List<TxRecord> existing,
  ProposedOp op,
) {
  // Build the proposed list
  List<TxRecord> proposed = List.of(existing);

  switch (op.kind) {
    case ProposedOpKind.delete:
      proposed.removeWhere((t) => t.id == op.deleteId);
    case ProposedOpKind.add:
      proposed.add(op.record!);
    case ProposedOpKind.edit:
      proposed.removeWhere((t) => t.id == op.editTargetId);
      proposed.add(op.record!);
  }

  // Sort: date ASC, then id ASC (use 0 for new records without a real id)
  proposed.sort((a, b) {
    final dateCmp = a.date.compareTo(b.date);
    if (dateCmp != 0) return dateCmp;
    return a.id.compareTo(b.id);
  });

  // Replay
  int runningQty = 0;
  for (final tx in proposed) {
    if (tx.type == 'BUY') {
      runningQty += tx.quantity;
    } else {
      runningQty -= tx.quantity;
      if (runningQty < 0) {
        return ValidationResult.invalid(tx);
      }
    }
  }
  return const ValidationResult.valid();
}
```

#### `findDuplicateTransaction`
```dart
DuplicateCheckResult findDuplicateTransaction(
  List<TxRecord> existing,
  TxRecord proposed,
) {
  final proposedDay = _dateOnly(proposed.date);
  for (final tx in existing) {
    if (tx.type == proposed.type &&
        tx.price == proposed.price &&
        _dateOnly(tx.date) == proposedDay) {
      return DuplicateCheckResult.duplicate(tx);
    }
  }
  return const DuplicateCheckResult.noDuplicate();
}
```

#### Gain / Loss Functions
```dart
double overallGainLoss({
  required double currentValue,
  required double investedValue,
}) =>
    currentValue - investedValue;

double overallGainLossPercent({
  required double currentValue,
  required double investedValue,
}) {
  if (investedValue == 0) return 0;
  return ((currentValue - investedValue) / investedValue) * 100;
}

double dayGainLoss({
  required int quantityHeld,
  required double currentPrice,
  required double prevClose,
}) =>
    (currentPrice - prevClose) * quantityHeld;

double dayGainLossPercent({
  required double currentPrice,
  required double prevClose,
}) {
  if (prevClose == 0) return 0;
  return ((currentPrice - prevClose) / prevClose) * 100;
}
```

---

### 3.2 Logic Questions Analysis

1. **Sort order used when replaying**:
   - `date ASC`, then `id ASC` as tiebreaker:
     ```dart
     proposed.sort((a, b) {
       final dateCmp = a.date.compareTo(b.date);
       if (dateCmp != 0) return dateCmp;
       return a.id.compareTo(b.id);
     });
     ```
   - Matches the intended design.

2. **How a Sell affects average buy price**:
   - On Sell, `qty -= tx.quantity`. If `qty > 0`, it computes `avgCost = totalCost / (qty + tx.quantity)` and sets `totalCost -= avgCost * tx.quantity`. The resulting `totalCost / qty` is mathematically identical to `avgCost`.
   - Matches the intended design: Average buy price stays the same; quantity and invested value reduce proportionally.

3. **What happens when quantity reaches zero and then a new Buy is added**:
   - When `qty <= 0`, it sets `qty = 0; totalCost = 0;`.
   - When subsequent Buy transactions occur, `qty` and `totalCost` start fresh from 0 (`HoldingState.zero`), so the cost basis resets completely for the new cycle.

4. **Whether same-day transactions are handled correctly when a Sell and Buy share a date (which is replayed first?)**:
   - Tiebreaking is **solely by `id ASC`** (`a.id.compareTo(b.id)`).
   - For a newly added record, its ID is set to `0` (`ProposedOp.add(TxRecord(id: 0, ...))`). Therefore, a newly proposed SELL with `id: 0` sorts **before** existing BUY transactions of the same day (whose IDs are `>= 1`), which can fail validation even if buys happened earlier in the day unless explicit type-ordering or timestamps are used.
   - For existing transactions sharing a date, whichever was inserted first (smaller `id`) is replayed first.

5. **Whether validation runs for add, edit AND delete, and whether editing validates the resulting sequence (not just the new row)**:
   - **Yes**. `ProposedOp` has explicit cases: `ProposedOpKind.add`, `ProposedOpKind.edit`, and `ProposedOpKind.delete`.
   - In `ProposedOpKind.edit`, the target record is removed and the replacement record is added, followed by a full re-sort and replay of the complete chain to ensure running quantity is never negative anywhere in the timeline.

6. **Are the point-in-time quantity messages implemented as designed**:
   - **Yes**. In `AddTransactionSheet._submit()`, when a SELL fails validation, it filters `records.where((r) => !d.isAfter(sellDateOnly))` to calculate quantity held as of that specific date, producing:
     `'You held $heldQty share${heldQty == 1 ? '' : 's'} as of ${_dateFmt.format(_date)} — can\'t sell $qty.'`

---

## 4. RULES ACTUALLY ENFORCED

| Rule | Where Enforced | Enforcement Layer | How Enforced in Actual Code |
|---|---|---|---|
| **One card per ticker** | `StockCards.uniqueKeys` in `stock_cards_table.dart` | **Database** (SQLite UNIQUE constraint) | `uniqueKeys => [{ticker}]` creates a UNIQUE index in SQLite. |
| **First transaction in card creation must be Buy** | `_Step3TransactionState` in `create_stock_card_flow.dart` | **UI only** | In `_Step3TransactionState`, `final String _type = 'BUY';` is hardcoded as a constant; no toggle to Sell is provided. |
| **Sell can't exceed quantity held at that date** | `AddTransactionSheet._submit`, `StockCardDetail._tryDeleteTransaction`, and `_editTransaction` via `validateQuantityNeverNegative` | **UI + Logic Layer** (Not in Database) | Validated in memory before calling DAO methods by running full replay simulation. |
| **No transactions on weekends or listed holidays (both entry modes)** | `isMarketOpen(_date)` in `market_calendar.dart`, checked in `_pickDate()` and `_submit()` in both `AddTransactionSheet` and `_Step3Transaction` | **UI only** | `isMarketOpen()` checks Saturday, Sunday, and `nseHolidays2026`. Form displays inline banner and blocks submission. |
| **No future dates** | Date picker: `lastDate: DateTime.now()` in `_pickDate()` | **UI only** | Material `showDatePicker` disables future calendar days. No database constraint exists. |
| **Quantity > 0 and integer** | `TextFormField` validator and `FilteringTextInputFormatter.digitsOnly` | **UI only** | Validates `int.tryParse(v) > 0` and blocks non-digits. Drift column is standard `IntColumn`. |
| **Price >= 0 (Avg) / inside day range (Normal)** | `TextFormField` validator in `AddTransactionSheet` / `CreateStockCardFlow` | **UI only** | For Normal mode: `price >= _priceRange.low && price <= _priceRange.high`. For Avg mode: `price > 0`. |
| **Duplicate date+price+type merge with confirmation** | `findDuplicateTransaction` in `stock_logic.dart` and `StocksDao.findDuplicate` | **UI + Logic Layer** | Detected in UI prior to submit; presents `AlertDialog` asking to merge into existing transaction; calls `mergeIntoExistingTransaction`. |
| **Normal mode price-range validation and re-fetch at submit for today** | `_submit()` in `AddTransactionSheet` and `_Step3TransactionState` | **UI + Service Layer** | If `_entryMode == 'NORMAL'` and `isTodayIst(_date)`, calls `fetchDayPriceRange` before validating price against fresh range. |
| **total_amount computation and where it's stored** | UI calculate `price * qty`; stored in `StockTransactions.totalAmount` | **UI & Database** | Stored directly in `total_amount` column of `stock_transactions`. Never dynamically recomputed on read. |

### What happens to `total_amount` and the merged quantity after a merge or an edit?
- **After a merge** (`StocksDao.mergeIntoExistingTransaction`):
  - `quantity` becomes: `existing.quantity + additionalQuantity`.
  - `totalAmount` becomes: `existing.totalAmount + additionalAmount` (where `additionalAmount = newPrice * newQuantity`).
  - Note: Since `findDuplicate` matches on exact price, the effective cost basis of the row remains consistent. The individual `price` column is **not** modified.
- **After an edit** (`StockCardDetail._editTransaction`):
  - In `_editTransaction`, `AddTransactionSheet` is opened with `existingTx: tx`. When submitted, `AddTransactionSheet` creates a new transaction record with newly computed `totalAmount = price * qty`.
  - After `showModalBottomSheet` returns, line 187 of `stock_card_detail.dart` calls:
    `if (mounted) await dao.deleteTransaction(tx.id);`
  - So the edit is executed as: **insert new transaction row & delete old transaction row**.
  - **Important Subtlety / Risk**: If a user opens edit, triggers a *duplicate merge* against an existing transaction, and then returns, the sheet merges into the duplicate, but line 187 still deletes `tx.id`. If `tx.id` was not the duplicate target, this functions as expected; if it attempted to edit in place, it actually replaces by inserting a new ID and removing the old ID.

---

## 5. PRICE SERVICE

### 5.1 Routing
- **Past dates**: Routed to `NseBhavcopySource.fetchDayPriceRange(ticker, date, isin: isin)`.
- **Today (in IST)**: Routed to `YahooQuoteSource.fetchTodayRange(ticker, exchange: exchange)`.
- **Current price (`fetchCurrentPrice`)**: Routed to `YahooQuoteSource.fetchQuote(ticker, exchange: exchange) -> quote.currentPrice`.
- **Previous close (`fetchPreviousClose`)**: Routed to `YahooQuoteSource.fetchQuote(ticker, exchange: exchange) -> quote.previousClose`.

### 5.2 Exact URL Patterns, Headers, Timeouts, Symbol/ISIN Mapping, & Caching

#### 1. Yahoo Finance (`YahooQuoteSource`)
- **URL Pattern**: `https://query1.finance.yahoo.com/v8/finance/chart/$symbol`
- **Symbol Mapping**:
  - NSE: `$ticker.NS` (e.g. `RELIANCE.NS`, `TMPV.NS`)
  - BSE: `$ticker.BO` (e.g. `RELIANCE.BO`)
- **Headers Sent**:
  - `User-Agent`: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`
  - `Accept`: `application/json`
- **Timeout**: `Duration(seconds: 10)`

#### 2. NSE Bhavcopy (`NseBhavcopySource`)
- **URL Pattern**: `https://nsearchives.nseindia.com/content/cm/BhavCopy_NSE_CM_0_0_0_${dateKey}_F_0000.csv.zip` where `dateKey` is `yyyyMMdd` (e.g. `20260925`).
- **Headers Sent**:
  - `User-Agent`: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`
  - `Accept`: `*/*`
  - `Accept-Language`: `en-US,en;q=0.9`
  - `Referer`: `https://www.nseindia.com/`
- **Timeout**: `Duration(seconds: 15)`
- **ISIN / Symbol Matching**:
  - Lookups match by **ISIN first** (resolved via `local_tickers.dart` if not provided).
  - Falls back to **symbol match** if ISIN is not found or empty.
- **Series Filter**:
  - Accepts **`EQ` and `BE`** series (newly listed / demerged / surveillance stocks trade in `BE`).
  - If a stock has entries in both, `EQ` is preferred over `BE`.
- **Disk Cache**:
  - Location: `<getApplicationDocumentsDirectory()>/bhavcopy_cache/bhavcopy_${dateKey}.json` (falls back to system temp if path provider fails).
  - Format: JSON object containing two sub-maps:
    ```json
    {
      "isin": { "INE155A01022": [288.0, 297.7], ... },
      "sym": { "TMPV": [288.0, 297.7], ... }
    }
    ```
  - In-memory cache: static map `_memoryCache[dateKey]` storing `_DayBhavcopyData` for zero-latency lookups during app run.

### 5.3 Exception Handling & UI Messages

| Situation | Exception Thrown | UI Presentation |
|---|---|---|
| Today's time is before 9:15 AM IST | `MarketNotOpenException` | Form displays amber banner: *"Market hasn't opened yet today — pick a previous trading day or try after 9:15 AM IST"*. Submit button is blocked. |
| Today's market quote has zero or negative day high/low | `MarketNotOpenException` | Form displays amber banner with same message. |
| Quote market time is from a previous day while checking today | `MarketNotOpenException` | Form displays amber banner with same message. |
| BSE stock requested for past date price range | `PriceFetchException("Price range validation isn't available for BSE stocks yet")` | Form displays red error banner: *"Price range validation isn't available for BSE stocks yet"*. |
| NSE Bhavcopy returns HTTP 404 (holiday / missing date) | `PriceFetchException('NSE Bhavcopy not available for date $dateKey')` | Form displays red error banner: *"NSE Bhavcopy not available for date..."* with a **Retry** button. |
| Network timeout or connection drop | `PriceFetchException('Failed to download NSE Bhavcopy: ...')` or `PriceFetchException('Failed to connect to price service: ...')` | Red error banner with message and **Retry** button; or SnackBar: *"Couldn't fetch fresh price data — please retry."* |
| Stock ticker/ISIN not present in Bhavcopy CSV | `PriceFetchException('Stock $targetTicker ($targetIsin) not found in NSE Bhavcopy for $dateKey')` | Red error banner with message. |
| Price refresh failure on StockCardDetail | Caught `e` | SnackBar: *"Price refresh failed: $e. Kept cached price."* |
| Price refresh success on StockCardDetail | None | SnackBar: *"Price updated successfully."* |

### 5.4 IST and Market Open Calculation
- Computed via:
  ```dart
  final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final marketOpenIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, 9, 15);
  if (nowIst.isBefore(marketOpenIst)) {
    throw const MarketNotOpenException();
  }
  ```
- `isTodayIst(date)` checks if `date.year == nowIst.year && date.month == nowIst.month && date.day == nowIst.day`.

### 5.5 BSE Exchange Cards
- BSE cards are allowed in ticker selection and database.
- Live prices (`fetchQuote`, `fetchCurrentPrice`, `fetchPreviousClose`, and today's range) work via Yahoo Finance with suffix `.BO`.
- Past-date range validation via Bhavcopy is **unsupported**: `price_service.dart` line 62 explicitly throws `PriceFetchException("Price range validation isn't available for BSE stocks yet")`.

### 5.6 Market Holiday List
- File: `lib/utils/market_calendar.dart`.
- Year covered: **2026 only** (contains a comment `// TODO: update this list yearly`).
- Number of dates: **17 dates** in `nseHolidays2026`.

---

## 6. UI FLOWS (Factual Descriptions)

### 6.1 Card Creation Steps (`CreateStockCardFlow`)
1. **Step 1: Select Stock**: Search box queries `searchTickers` with instant autocomplete. Displays matching stock tiles with ticker, company name, and exchange. Selecting a stock advances to Step 2.
2. **Step 2: Add Tags**: Optional chip input. User can select existing tags or create new ones. Tap "Next" to advance.
3. **Step 3: First Transaction**: Transaction entry form. Hardcoded to `BUY`. Supports `NORMAL` and `AVG` modes. In Normal mode, date selection validates against weekends/holidays and auto-fetches high/low price range. Form validates price within range and quantity > 0.
4. **Step 4: Confirm**: Summary view showing stock info, tags, and transaction details. Tapping "Create Card" inserts the card, tags, and transaction, then pops back to the stocks list.

### 6.2 Add/Edit Transaction Sheet (`AddTransactionSheet`)
- Modal bottom sheet.
- Segmented buttons for `Type` (`Buy` / `Sell`) and `Entry Mode` (`Normal` / `Avg Price`).
- Date picker: allows past dates up to today, blocks weekends and listed holidays.
- Normal mode: fetches day price range (from Bhavcopy for past dates or Yahoo Finance for today) and validates entered price within `[low, high]`.
- Selling validation: checks that proposed Sell does not drive holding negative at that point in time. Shows inline error banner if violated.
- Duplicate detection: if matching transaction exists (same day, price, type), shows dialog prompting to merge quantity.
- Submit saves transaction and dismisses sheet.

### 6.3 Minimized Tile (`StockCardTile`)
- Displays:
  - Top row: Ticker, exchange badge (NSE/BSE), company name, total current value (or `—`), and quantity of shares held.
  - Middle: Tag chips (if any).
  - Bottom: Container with two columns:
    - Overall Gain/Loss: absolute ₹ and % (green for positive, red for negative).
    - Today's Gain/Loss: absolute ₹ and % based on previous close.
- Tap opens `StockCardDetail`. Long-press triggers card deletion confirmation dialog.

### 6.4 Enlarged Card (`StockCardDetail`)
- App bar: Title `${card.ticker} · ${card.exchange}`, refresh icon, and 3-dot overflow menu (`Delete card`).
- Header: Live/cached price, today's price change (₹ and %), last updated timestamp.
- Tags row with `+` button to edit tags via dialog.
- Performance grid: Quantity held, Avg buy price, Total invested, Current value, Overall G/L, Day's G/L.
- Floating action / prompt button: `+ Add Transaction`.
- Scrollable transaction history: sorted date DESC. Each transaction shows date, type badge (BUY/SELL), entry mode badge, price, quantity, total amount, and edit/delete icons.

### 6.5 Delete Transaction (`StockCardDetail._tryDeleteTransaction`)
- Triggered by trash icon on a transaction row in `StockCardDetail`.
- Validates whether deleting this transaction would cause subsequent holdings to drop below 0 using `validateQuantityNeverNegative(records, ProposedOp.delete(tx.id))`.
- If invalid: shows SnackBar: *"Cannot delete: a [type] of [qty] shares on [date] depends on this transaction."*
- If valid: shows AlertDialog *"Delete Transaction? This transaction will be permanently deleted."* with Cancel and red Delete buttons. On confirmation, deletes transaction from database.

### 6.6 Delete Card (`delete_stock_card_dialog.dart`)
- Triggered from:
  1. 3-dot overflow menu in `StockCardDetail` -> `Delete card`.
  2. Long-press on `StockCardTile` in `StocksSection`.
- Confirmation Dialog:
  - Title: `Delete [TICKER]?`
  - Content: `"This permanently deletes the card and all its [N] transactions. This can't be undone."` (N is actual transaction count).
  - Actions: `Cancel` and red `Delete` filled button.
- On Confirm: Calls `StocksDao.deleteCardWithAllData(card.id)`, pops detail screen if open, returns to Stocks list, and shows SnackBar: `"[TICKER] deleted"`.

### 6.7 Price Refresh Behavior
- Triggered manually by tapping the refresh icon in `StockCardDetail` AppBar.
- Fetches `fetchCurrentPrice` and `fetchPreviousClose` from Yahoo Finance.
- Updates database via `dao.updateCardPrice(...)`.
- Success SnackBar: *"Price updated successfully."*
- Failure SnackBar: *"Price refresh failed: [error]. Kept cached price."* (retains existing cached price).

### 6.8 Complete Catalog of UI Error Messages
1. **Weekend/Holiday date**: *"Markets are closed on [date] (weekend/holiday) — please pick a trading day."*
2. **Market not open**: *"Market hasn't opened yet today — pick a previous trading day or try after 9:15 AM IST"*
3. **Price range fetch error**: *"Couldn't fetch fresh price data — please retry."* / *"[error message]"*
4. **Price range waiting**: *"Please wait while price data is being fetched."*
5. **Price not fetched yet**: *"Please fetch the price range before submitting."* / *"Day price range not loaded yet"*
6. **Price outside range**: *"Price must be within range ₹[low] – ₹[high]"*
7. **Negative holding (Sell validation)**: *"You held [N] shares as of [date] — can't sell [qty]."*
8. **Delete transaction violation**: *"Cannot delete: a [type] of [qty] shares on [date] depends on this transaction."*
9. **Edit transaction violation**: *"This transaction cannot be edited because removing it would make quantity negative."*
10. **Price refresh failure**: *"Price refresh failed: [error]. Kept cached price."*
11. **Delete card failure**: *"Failed to delete [TICKER]: [error]"*
12. **Form field validators**: *"Required"*, *"Enter a valid price"*, *"Must be greater than 0"*.

---

## 7. KNOWN GAPS AND RISKS

1. **Card + First Transaction Creation is NOT Atomic**:
   - In `CreateStockCardFlow._createCard`, `dao.insertCard`, `dao.upsertTag`, `dao.setTagsForCard`, and `dao.insertTransaction` are individual asynchronous calls not wrapped in `db.transaction(...)`. If the app crashes or fails midway, an empty card with no transactions or tags can be left in the database.

2. **SQLite Foreign Keys Not Enabled via PRAGMA**:
   - `PRAGMA foreign_keys = ON;` is never executed on SQLite connection startup. Reliance is placed entirely on application-level deletion logic (`deleteCardWithAllData`). Direct table deletes outside this DAO method will produce orphaned transactions.

3. **Same-Day BUY and SELL Ordering**:
   - Because `validateQuantityNeverNegative` tiebreaks same-day transactions using `a.id.compareTo(b.id)` and assigns newly proposed transactions `id: 0`, a proposed SELL on the same day as an existing BUY sorts **before** the BUY during replay and can falsely fail validation.

4. **Holiday Calendar Hardcoded for 2026 Only**:
   - `nseHolidays2026` in `lib/utils/market_calendar.dart` contains 17 hardcoded dates for 2026. A `// TODO: update this list yearly` comment exists. Dates in 2025 or 2027 will not have holiday checks (weekends will still be blocked).

5. **BSE Stocks Lack Historical Bhavcopy Support**:
   - BSE stocks can be added and live prices work via Yahoo Finance (`.BO`), but range validation on past dates throws `PriceFetchException` because BSE Bhavcopy parsing is stubbed/unimplemented.

6. **Swallowed Failures / Silent Catches**:
   - In `nse_bhavcopy_source.dart` line 251: Disk cache write failures are silently caught:
     `catch (_) { /* Disk write error shouldn't crash query */ }`
   - In `nse_bhavcopy_source.dart` lines 123 & 132: Corrupt cache file deletion ignores errors:
     `await cacheFile.delete().catchError((_) => cacheFile);`
   - In `local_tickers.dart` line 147: If search is triggered before `ensureTickersLoaded()` finishes, search silently returns empty `[]` and asynchronously initiates the load.

7. **Edit Transaction Deletion Race**:
   - In `StockCardDetail._editTransaction`, the edit sheet inserts a new transaction, and after returning, line 187 deletes the old transaction `tx.id`. If a user merges during the edit sheet, the old transaction is still deleted, which could alter the intended outcome.

---

## 8. FILE MAP

Current file tree of `lib/`:

- [lib/main.dart](file:///c:/my_new_app/lib/main.dart): App entrypoint, initializes Flutter bindings, loads ticker asset index, sets up theme and top-level `AppShell`.
- [lib/data/local_tickers.dart](file:///c:/my_new_app/lib/data/local_tickers.dart): **[Updated]** Offline ticker dataset management; loads `assets/nse_tickers.json` (2,565 stocks), builds search index, ranks symbol prefix/words, and provides ISIN/symbol lookup.
- [lib/database/app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart): Drift database root, schema definition, migration strategy, and connection manager.
- [lib/database/app_database.g.dart](file:///c:/my_new_app/lib/database/app_database.g.dart): Drift generated database code, table managers, and query mappers.
- [lib/database/daos/stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart): **[Updated]** Stocks DAO containing queries for cards, transactions, tags, duplicates, and `deleteCardWithAllData`.
- [lib/database/daos/stocks_dao.g.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.g.dart): Drift generated accessor mixin for `StocksDao`.
- [lib/database/tables/stock_cards_table.dart](file:///c:/my_new_app/lib/database/tables/stock_cards_table.dart): Schema table definition for `StockCards` with unique ticker constraint.
- [lib/database/tables/stock_transactions_table.dart](file:///c:/my_new_app/lib/database/tables/stock_transactions_table.dart): Schema table definition for `StockTransactions`.
- [lib/database/tables/tags_table.dart](file:///c:/my_new_app/lib/database/tables/tags_table.dart): Schema table definitions for `Tags` and polymorphic join table `CardTags`.
- [lib/logic/stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart): Pure business logic: WAC holding state, quantity-never-negative validation, duplicate checks, and gain/loss formulas.
- [lib/providers/database_provider.dart](file:///c:/my_new_app/lib/providers/database_provider.dart): `InheritedWidget` making `AppDatabase` accessible throughout the widget tree.
- [lib/screens/analysis_screen.dart](file:///c:/my_new_app/lib/screens/analysis_screen.dart): Placeholder screen for future Analysis tab.
- [lib/screens/investments_screen.dart](file:///c:/my_new_app/lib/screens/investments_screen.dart): Investments screen wrapper currently housing `StocksSection`.
- [lib/services/nse_bhavcopy_source.dart](file:///c:/my_new_app/lib/services/nse_bhavcopy_source.dart): **[Updated]** Downloader and parser for NSE UDiFF equity Bhavcopy ZIPs; supports ISIN matching, series EQ & BE, memory & disk caching.
- [lib/services/price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart): **[Updated]** Routing layer dispatching price requests between Yahoo Finance (today) and NSE Bhavcopy (past dates).
- [lib/services/yahoo_quote_source.dart](file:///c:/my_new_app/lib/services/yahoo_quote_source.dart): Yahoo Finance API client for live quotes, today's trading range, and market open validation.
- [lib/stocks/add_transaction_sheet.dart](file:///c:/my_new_app/lib/stocks/add_transaction_sheet.dart): Modal bottom sheet for adding or editing stock transactions with validation and duplicate merging.
- [lib/stocks/create_stock_card_flow.dart](file:///c:/my_new_app/lib/stocks/create_stock_card_flow.dart): Multi-step wizard for searching tickers, attaching tags, entering the initial Buy transaction, and creating cards.
- [lib/stocks/stocks_section.dart](file:///c:/my_new_app/lib/stocks/stocks_section.dart): **[Updated]** Stocks list view managing reactive card stream, empty state, and long-press card deletion.
- [lib/stocks/stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart): **[Updated]** Enlarged card detail view with price refresh, properties grid, transaction history, and 3-dot overflow menu for card deletion.
- [lib/stocks/stock_card_tile.dart](file:///c:/my_new_app/lib/stocks/stock_card_tile.dart): **[Updated]** Stock card tile widget with holding summary, gain/loss metrics, and long-press callback.
- [lib/stocks/widgets/delete_stock_card_dialog.dart](file:///c:/my_new_app/lib/stocks/widgets/delete_stock_card_dialog.dart): **[New File]** Confirmation dialog and deletion handler with transaction count and SnackBar feedback.
- [lib/stocks/widgets/tag_chip.dart](file:///c:/my_new_app/lib/stocks/widgets/tag_chip.dart): Visual tag chip widget.
- [lib/utils/market_calendar.dart](file:///c:/my_new_app/lib/utils/market_calendar.dart): Market trading day validation (weekend and 2026 holiday checks).

---

## 9. FLUTTER ANALYZE RESULT

Execution command: `flutter analyze`
Result:
```
Analyzing my_new_app...
No issues found! (ran in 13.8s)
```
- Total diagnostics / issues: **0**.
