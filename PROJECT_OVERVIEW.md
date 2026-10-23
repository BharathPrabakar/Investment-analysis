# Project Overview — Investment Tracker (Stocks Edition)

> **CRITICAL DIRECTIVE FOR ALL AI AGENTS & COLLABORATORS:**
> - **MANDATORY READING:** Every AI assistant must read this file in full at the start of any work session.
> - **CONTINUOUS SYNCHRONIZATION:** Whenever you make *any* change to the codebase (schema, features, services, UI components, file removals, or business logic), you **MUST** update this file and [FILE_MAP.md](FILE_MAP.md) to reflect the new state. Do not leave this document stale.
> - **PROACTIVE DEAD CODE PURGING:** When any refactor or modification makes previous methods, parameters, unused imports, or files redundant, you **MUST delete them immediately**. Do not leave zombie code or commented-out blocks in the repository.

---

## 1. Project Vision & Purpose

**Investment Tracker** is a professional, offline-first personal portfolio management application focused exclusively on **Indian Equities (NSE and BSE)**. 

### Core Highlights:
* **Zero Bloat / Pure Equities:** Tracks individual stock investments with high precision. All non-equity asset classes (such as Mutual Funds) are deliberately excluded.
* **Offline-First & Local Storage:** No user account creation, no mandatory remote servers, and no cloud data tracking. All portfolios, transaction histories, and custom tags reside in a local SQLite database.
* **Deterministic Price Verification:** Uses authentic daily Bhavcopy downloads (NSE Archives & BSE UDiFF/Equity) for past execution validation, and Yahoo Finance for live quotes. No fake numbers or mocked static price tables.
* **Automated Corporate Actions:** Automatically scans and detects Dividends and Bonuses directly matching actual shareholder record dates.

---

## 2. Technology Stack & Architecture

| Layer | Technology | Details |
|---|---|---|
| **Language** | **Dart** (`^3.13.4`) | Strict typing, null-safety, async/await streams. |
| **Framework** | **Flutter** (Material 3) | Cross-platform (Windows Desktop primary target, Android/iOS ready). |
| **Database** | **SQLite** via **Drift** (`^2.35.0`) | Strongly typed ORM/query builder (`drift_flutter` native platform backend). |
| **Data Parsing** | `archive`, `intl`, `http`, `path_provider` | ZIP unpacking of Bhavcopy archives, date formatting, HTTP REST client. |
| **Code Generation** | `build_runner`, `drift_dev` | For compiling SQLite schema and DAO mappings (`dart run build_runner build`). |

---

## 3. Directory Structure & Key Components

> *For an itemized, per-file index with symbols, dependencies, and targeted edit pointers, see [FILE_MAP.md](FILE_MAP.md).*

```text
my_new_app/
├── assets/
│   ├── EQUITY_L.csv                # Official NSE Equities master list
│   ├── nse_tickers.json            # Indexed NSE symbol, company name, ISIN
│   └── bse_tickers.json            # Indexed BSE symbol, scrip code, ISIN
├── lib/
│   ├── data/
│   │   └── local_tickers.dart       # In-memory ticker search index (NSE & BSE)
│   ├── database/
│   │   ├── app_database.dart       # Drift database configuration & migration
│   │   ├── daos/
│   │   │   └── stocks_dao.dart     # Stock cards, transactions & tags data access
│   │   └── tables/
│   │       ├── stock_cards_table.dart
│   │       ├── stock_transactions_table.dart
│   │       └── tags_table.dart     # Tags & CardTags tables
│   ├── logic/
│   │   └── stock_logic.dart        # Pure portfolio math (WAC, P&L, returns)
│   ├── providers/
│   │   └── database_provider.dart  # InheritedWidget / Provider for AppDatabase
│   ├── screens/
│   │   ├── investments_screen.dart # Main investments view (StocksSection)
│   │   └── analysis_screen.dart    # Performance metrics & portfolio analytics
│   ├── services/
│   │   ├── bse_bhavcopy_source.dart   # BSE UDiFF / Bhavcopy ZIP downloader & parser
│   │   ├── dividend_source.dart       # Corporate actions & dividend tracker
│   │   ├── nse_bhavcopy_source.dart   # NSE Bhavcopy downloader & disk cache
│   │   ├── price_service.dart         # Price routing (Yahoo live vs. Bhavcopy past)
│   │   ├── trading_day_service.dart   # Live trading day probe & holiday detection
│   │   └── yahoo_quote_source.dart    # Yahoo Finance live quote integration
│   ├── stocks/
│   │   ├── add_transaction_sheet.dart # Modal to record Buy, Sell, Dividend, Bonus
│   │   ├── create_stock_card_flow.dart# Multi-step wizard to create stock cards
│   │   ├── stock_card_detail.dart     # Comprehensive card view & transaction ledger
│   │   ├── stock_card_tile.dart       # Summary tile on the portfolio list
│   │   └── stocks_section.dart        # Holdings grid/list, filtering & summary
│   ├── utils/
│   │   ├── app_constants.dart         # Central constants (IST market times, probe tickers)
│   │   └── market_calendar.dart       # Weekend validation utilities
│   ├── widgets/
│   │   └── tag_chip.dart              # Reusable tag chip component
│   └── main.dart                      # App entry point & initialization
├── test/                              # Automated unit and widget tests
├── AGENTS.md                          # Mandatory agent instructions
└── PROJECT_OVERVIEW.md                # THIS FILE (Comprehensive project documentation)
```

---

## 4. Database Schema (SQLite)

Foreign keys are strictly enforced via `PRAGMA foreign_keys = ON;`.

### A. Tables Description

1. **`stock_cards`**:
   * Represents an investment holding card for an equity.
   * Columns: `id` (PK), `symbol`, `company_name`, `exchange` (NSE/BSE), `isin`, `scrip_code`, `created_at`.
2. **`stock_transactions`**:
   * Complete audit trail of individual buy/sell/dividend/bonus/split events.
   * Columns: `id` (PK), `card_id` (FK -> `stock_cards.id` ON DELETE CASCADE), `type` (`BUY`, `SELL`, `DIVIDEND`, `BONUS`, `SPLIT`), `entry_mode` (`MANUAL`, `AUTO`), `date`, `quantity`, `price`, `total_amount`, `notes`, `created_at`.
   * Indexes: `idx_stock_tx_card_date` on `(card_id, date)`.
3. **`tags`**:
   * User-defined categories (e.g., "Long Term", "Core Portfolio").
   * Columns: `id` (PK), `name` (Unique TEXT).
4. **`card_tags`**:
   * Join table for many-to-many relationship.
   * Columns: `card_id`, `tag_id` (FK -> `tags.id` ON DELETE CASCADE), `card_type` (Discriminator, `'stock'`).
   * Primary Key: Composite `(card_id, tag_id, card_type)`.

### B. Raw SQL Definition

```sql
CREATE TABLE IF NOT EXISTS "stock_cards" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "symbol" TEXT NOT NULL,
    "company_name" TEXT NOT NULL,
    "exchange" TEXT NOT NULL DEFAULT 'NSE',
    "isin" TEXT NULL,
    "scrip_code" TEXT NULL,
    "created_at" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "stock_transactions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "card_id" INTEGER NOT NULL REFERENCES "stock_cards" ("id") ON DELETE CASCADE,
    "type" TEXT NOT NULL,
    "entry_mode" TEXT NOT NULL DEFAULT 'MANUAL',
    "date" INTEGER NOT NULL,
    "quantity" REAL NOT NULL,
    "price" REAL NOT NULL,
    "total_amount" REAL NOT NULL,
    "notes" TEXT NULL,
    "created_at" INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS "idx_stock_tx_card_date" 
ON "stock_transactions" ("card_id", "date");

CREATE TABLE IF NOT EXISTS "tags" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "card_tags" (
    "card_id" INTEGER NOT NULL,
    "tag_id" INTEGER NOT NULL REFERENCES "tags" ("id") ON DELETE CASCADE,
    "card_type" TEXT NOT NULL,
    PRIMARY KEY ("card_id", "tag_id", "card_type")
);
```

---

## 5. Live Pricing & Market Data Architecture

1. **Today / Live Quotes:**
   * Handled by [`YahooQuoteSource`](lib/services/yahoo_quote_source.dart).
   * Queries `query1.finance.yahoo.com` with `.NS` suffix for NSE stocks and `.BO` for BSE stocks.
   * Extracts `regularMarketPrice`, `regularMarketDayLow`, `regularMarketDayHigh`, and `regularMarketPreviousClose`.
2. **Historical Trading Day Prices:**
   * Handled by [`NseBhavcopySource`](lib/services/nse_bhavcopy_source.dart) and [`BseBhavcopySource`](lib/services/bse_bhavcopy_source.dart).
   * Automatically downloads, caches in local disk (`bhavcopy_cache/`), and parses official daily Bhavcopy archives.
   * Validates transaction prices against the authenticated traded range (`[low, high]`) of that day.
3. **Dynamic Market Session Verification:**
   * Weekends are immediately classified as closed without internet calls.
   * Market hours (IST 9:15 AM to 3:30 PM) are observed via anchor probe tickers (`RELIANCE`) to detect real-time trading holidays.
4. **Strict Equity Filtering (Pure Stock Focus):**
   * Non-equity instruments are strictly filtered out from the local search index ([`lib/data/local_tickers.dart`](lib/data/local_tickers.dart)):
     - **BSE Debt / NCDs:** Scrip codes starting with `9` (e.g. `93xxxx`) and coupon rate/NCD patterns.
     - **REITs & InvITs:** Real estate and infrastructure trusts.
     - **Bonds & Debentures:** Secured/unsecured redeemable debentures, tax-free bonds.
     - **Mutual Funds, ETFs & SGBs:** Gold bonds, index funds, BEES series, and funds with `INF`/`IN0` ISIN prefixes.

---

## 6. Business Logic Rules

All financial calculations reside in [`lib/logic/stock_logic.dart`](lib/logic/stock_logic.dart) without Flutter UI dependencies:
* **Weighted Average Cost (WAC):** Recalculates dynamically as new buy orders occur. Sell orders reduce holding quantity without distorting the historical purchase price average of remaining shares.
* **Realized P&L:** Calculated per sell transaction against the average cost at the execution timestamp.
* **Unrealized P&L:** `(Current Price - Average Cost) * Holding Quantity`.
* **Day Gain / Loss:** `(Current Price - Previous Close) * Holding Quantity`.
* **Corporate Action Reconciliation (Dividends, Bonuses & Stock Splits):** Whenever holding transactions (`BUY`, `SELL`, `SPLIT`, `BONUS`) are inserted, edited, or deleted, corporate actions are recomputed end-to-end:
  - **Stock Splits:** Detected from NSE, BSE corporate actions, and Yahoo Finance (`sub-division`, `FV 10 to 1`, `split 1:5`, etc.). Auto-inserts `SPLIT` transactions (`price: 0, totalAmount: 0, entryMode: 'AUTO'`). Quantities are adjusted dynamically: net additional shares equal `((quantityHeld * oldFV) / newFV) - quantityHeld`. Total invested capital is conserved, proportionally lowering the weighted-average purchase cost without falsifying historic buy transactions.
  - **Bonus Issues:** Re-executed chronologically based on eligible holding count on record date (`(quantityHeld * bonus) ~/ existing`). Cross-checked against detected stock splits to avoid duplicated Yahoo Finance split records masquerading as bonus issues.
  - **Strict Corporate Action Classification & Disambiguation:** Announcements are guarded against false cross-classifications. Announcements featuring stock subdivision or split keywords are excluded from dividend parsing unless explicit per-share dividend payout phrases exist, preventing face value reductions (e.g. from Rs 10 to Rs 2) from being misread as cash dividends.
  - **Purge on Ineligibility:** If all non-auto holding transactions are deleted, all auto-generated dividends, bonuses, and splits for the card are immediately purged from the database.
  - **Orphan Cleanup:** For modified holdings or shifted dates, any orphaned or previously credited auto corporate actions on dates where zero shares were held or where the event is no longer eligible are permanently removed.

---

## 7. Development Guidelines & Maintenance Protocols

1. **Running the App Locally:**
   ```bash
   flutter run -d windows
   ```
2. **Re-generating Database Code after Schema changes:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
3. **Running Quality Checks & Tests:**
   ```bash
   flutter analyze
   flutter test
   ```
4. **Agent Maintenance Contract:**
   * Any change made to the project **must be accompanied by an update to this `PROJECT_OVERVIEW.md` file**.
   * Keep documentation accurate, professional, and free from outdated historical artifacts.
