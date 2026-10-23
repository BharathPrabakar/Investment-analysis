# File & Module Map — Investment Tracker (Stocks Edition)

> **PURPOSE FOR AI AGENTS & COLLABORATORS:**
> Use this document to directly pinpoint files responsible for specific logic, UI screens, data models, or services without running broad searches or reading full directories. 
> Whenever you add, rename, or delete a file, keep this file synchronized.

---

## 0. Documentation & System Directives

* [AGENTS.md](file:///c:/my_new_app/AGENTS.md)
  - **Purpose:** Mandatory agent rules and operational constraints (session startup reading, zero dead code, remote git push discipline).
  - **Dependents / Links:** Consulted by all AI agents.

* [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md)
  - **Purpose:** Comprehensive architecture guide, technology stack, database schema definitions, and feature contracts.
  - **Dependents / Links:** [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md)

* [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md)
  - **Purpose:** Rapid-reference file and symbol index for targeted edits with minimal token consumption.
  - **Dependents / Links:** [AGENTS.md](file:///c:/my_new_app/AGENTS.md), [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md)

* [COMMITS_HISTORY.md](file:///c:/my_new_app/COMMITS_HISTORY.md)
  - **Purpose:** Human-readable ledger of all git commits, tracking commit hashes, timestamps, and detailed descriptions of what was changed and why.
  - **Dependents / Links:** [AGENTS.md](file:///c:/my_new_app/AGENTS.md)

---

## 1. Top-Level / Core

* [lib/main.dart](file:///c:/my_new_app/lib/main.dart)
  - **Purpose:** Application entry point. Configures Flutter desktop window size, initializes `AppDatabase`, sets up `AppDbProvider`, and hosts the bottom/side navigation shell.
  - **Key Symbols:** `main()`, `InvestmentTrackerApp`, `MainShell`
  - **Dependents / Links:** [investments_screen.dart](file:///c:/my_new_app/lib/screens/investments_screen.dart), [analysis_screen.dart](file:///c:/my_new_app/lib/screens/analysis_screen.dart), [app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart), [database_provider.dart](file:///c:/my_new_app/lib/providers/database_provider.dart)

---

## 2. Data & Search Index

* [lib/data/local_tickers.dart](file:///c:/my_new_app/lib/data/local_tickers.dart)
  - **Purpose:** In-memory search index for NSE and BSE listed stocks. Loads `nse_tickers.json` and `bse_tickers.json` from assets and provides fuzzy search by symbol, company name, or ISIN.
  - **Key Symbols:** `LocalTickers`, `StockSearchResult`, `search(query, {exchange})`, `getBySymbol(symbol, exchange)`
  - **Dependents / Links:** [create_stock_card_flow.dart](file:///c:/my_new_app/lib/stocks/create_stock_card_flow.dart)

---

## 3. Database Layer (Drift / SQLite)

* [lib/database/app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart) *(and `.g.dart`)*
  - **Purpose:** Root Drift database class. Manages database connection, table schemas, schema versions, migrations, and instantiates DAOs.
  - **Key Symbols:** `AppDatabase`, `@DriftDatabase(...)`
  - **Dependents / Links:** [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart), [database_provider.dart](file:///c:/my_new_app/lib/providers/database_provider.dart)

* [lib/database/tables/stock_cards_table.dart](file:///c:/my_new_app/lib/database/tables/stock_cards_table.dart)
  - **Purpose:** SQLite table definition for stock cards/holdings. Holds ticker, company name, exchange (NSE/BSE), ISIN, and timestamps.
  - **Key Symbols:** `StockCards`, `StockCard` (generated data class)
  - **Dependents / Links:** [app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

* [lib/database/tables/stock_transactions_table.dart](file:///c:/my_new_app/lib/database/tables/stock_transactions_table.dart)
  - **Purpose:** SQLite table definition for transactions: BUY, SELL, DIVIDEND, BONUS. Stores quantity, price per unit, brokerage/fees, execution date, and cash amount for dividends.
  - **Key Symbols:** `StockTransactions`, `StockTransaction`, `TransactionType`
  - **Dependents / Links:** [app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

* [lib/database/tables/tags_table.dart](file:///c:/my_new_app/lib/database/tables/tags_table.dart)
  - **Purpose:** SQLite table definitions for portfolio categorization tags (`Tags`) and the many-to-many relationship join table (`CardTags`).
  - **Key Symbols:** `Tags`, `CardTags`, `Tag`, `CardTag`
  - **Dependents / Links:** [app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

* [lib/database/daos/stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart) *(and `.g.dart`)*
  - **Purpose:** Data Access Object for all stock operations: querying cards, transactions, tag associations, cascading deletions, and transactional writes.
  - **Key Symbols:** `StocksDao`, `watchAllCards()`, `getTransactionsForCard()`, `insertCardWithTags()`, `deleteCardWithAllData()`
  - **Dependents / Links:** [app_database.dart](file:///c:/my_new_app/lib/database/app_database.dart), UI screens and sheets.

---

## 4. Providers & State

* [lib/providers/database_provider.dart](file:///c:/my_new_app/lib/providers/database_provider.dart)
  - **Purpose:** `InheritedWidget` provider making the singleton `AppDatabase` and `StocksDao` available anywhere in the Flutter widget tree.
  - **Key Symbols:** `AppDbProvider`, `AppDbProvider.of(context)`
  - **Dependents / Links:** [main.dart](file:///c:/my_new_app/lib/main.dart), all UI screens and modal sheets.

---

## 5. Domain Logic & Calculations

* [lib/logic/stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart)
  - **Purpose:** Pure business logic and mathematical models (no Flutter UI dependencies). Computes Weighted Average Cost (WAC), current holdings, realized P&L, unrealized P&L, total return %, bonus share adjustments, and dividend yield summaries.
  - **Key Symbols:** `StockLogic`, `StockSummary`, `calculateSummary(transactions, currentPrice)`
  - **Dependents / Links:** [stock_card_tile.dart](file:///c:/my_new_app/lib/stocks/stock_card_tile.dart), [stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart), [stocks_section.dart](file:///c:/my_new_app/lib/stocks/stocks_section.dart), [analysis_screen.dart](file:///c:/my_new_app/lib/screens/analysis_screen.dart)

---

## 6. Services & Data Feeds

* [lib/services/price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)
  - **Purpose:** Central facade and price dispatcher. Routes requests for live quotes (to Yahoo Finance) or historical close prices (to NSE/BSE Bhavcopy sources) with in-memory caching.
  - **Key Symbols:** `PriceService`, `getQuote(ticker, exchange)`, `getHistoricalClose(ticker, exchange, date)`
  - **Dependents / Links:** [yahoo_quote_source.dart](file:///c:/my_new_app/lib/services/yahoo_quote_source.dart), [nse_bhavcopy_source.dart](file:///c:/my_new_app/lib/services/nse_bhavcopy_source.dart), [bse_bhavcopy_source.dart](file:///c:/my_new_app/lib/services/bse_bhavcopy_source.dart), UI components.

* [lib/services/yahoo_quote_source.dart](file:///c:/my_new_app/lib/services/yahoo_quote_source.dart)
  - **Purpose:** Fetches near-realtime stock quotes via Yahoo Finance API (`.NS` suffix for NSE, `.BO` for BSE) with rate limiting and retry handling.
  - **Key Symbols:** `YahooQuoteSource`, `QuoteData`, `fetchQuote(symbol, exchange)`
  - **Dependents / Links:** [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

* [lib/services/nse_bhavcopy_source.dart](file:///c:/my_new_app/lib/services/nse_bhavcopy_source.dart)
  - **Purpose:** Downloads official daily Bhavcopy archives directly from NSE India archives, uncompresses them, caches files locally, and queries historical prices.
  - **Key Symbols:** `NseBhavcopySource`, `getClosePrice(symbol, date)`
  - **Dependents / Links:** [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

* [lib/services/bse_bhavcopy_source.dart](file:///c:/my_new_app/lib/services/bse_bhavcopy_source.dart)
  - **Purpose:** Downloads official BSE Bhavcopy / UDiFF daily zip archives, parses equity settlements, caches files to local storage, and retrieves closing prices.
  - **Key Symbols:** `BseBhavcopySource`, `getClosePrice(scripCodeOrSymbol, date)`
  - **Dependents / Links:** [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

* [lib/services/dividend_source.dart](file:///c:/my_new_app/lib/services/dividend_source.dart)
  - **Purpose:** Corporate actions and dividend discovery service. Scans exchange announcements/historical actions to alert the user of eligible dividends or bonuses.
  - **Key Symbols:** `DividendSource`, `CorporateActionItem`, `getActionsForSymbol(symbol, exchange)`
  - **Dependents / Links:** [stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart), [add_transaction_sheet.dart](file:///c:/my_new_app/lib/stocks/add_transaction_sheet.dart)

* [lib/services/trading_day_service.dart](file:///c:/my_new_app/lib/services/trading_day_service.dart)
  - **Purpose:** Determines valid trading sessions by probing live benchmark tickers and handling national market holidays dynamically.
  - **Key Symbols:** `TradingDayService`, `isMarketOpenNow()`, `getPreviousTradingDate(date)`
  - **Dependents / Links:** [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

---

## 7. Screens & Navigation

* [lib/screens/investments_screen.dart](file:///c:/my_new_app/lib/screens/investments_screen.dart)
  - **Purpose:** Root screen for portfolio management. Wraps `StocksSection` and provides the primary view for stock holdings, search, and action triggers.
  - **Key Symbols:** `InvestmentsScreen`
  - **Dependents / Links:** [stocks_section.dart](file:///c:/my_new_app/lib/stocks/stocks_section.dart)

* [lib/screens/analysis_screen.dart](file:///c:/my_new_app/lib/screens/analysis_screen.dart)
  - **Purpose:** Portfolio analysis and reporting view. Displays aggregate performance metrics, realized/unrealized profit breakdowns, sector/tag allocation charts, and dividend income stats.
  - **Key Symbols:** `AnalysisScreen`
  - **Dependents / Links:** [stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

---

## 8. Stock Feature Modules (`lib/stocks/`)

* [lib/stocks/stocks_section.dart](file:///c:/my_new_app/lib/stocks/stocks_section.dart)
  - **Purpose:** Portfolio overview tab contents. Contains the portfolio total summary card, search/filter bar, tag filtering chips, and the grid/list of stock holding tiles.
  - **Key Symbols:** `StocksSection`, `_StocksSectionState`
  - **Dependents / Links:** [stock_card_tile.dart](file:///c:/my_new_app/lib/stocks/stock_card_tile.dart), [create_stock_card_flow.dart](file:///c:/my_new_app/lib/stocks/create_stock_card_flow.dart), [stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart)

* [lib/stocks/stock_card_tile.dart](file:///c:/my_new_app/lib/stocks/stock_card_tile.dart)
  - **Purpose:** Individual card tile rendered in the portfolio list. Displays current stock price, quantity held, invested vs. current value, today's P&L, and overall P&L.
  - **Key Symbols:** `StockCardTile`
  - **Dependents / Links:** [stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart), [stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart)

* [lib/stocks/stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart)
  - **Purpose:** Full-screen detail page for a single stock holding. Displays price chart/trends, detailed statistics (WAC, realized P&L, dividend summary), complete transaction history ledger, and actions (add transaction, edit, delete).
  - **Key Symbols:** `StockCardDetailScreen`
  - **Dependents / Links:** [add_transaction_sheet.dart](file:///c:/my_new_app/lib/stocks/add_transaction_sheet.dart), [delete_stock_card_dialog.dart](file:///c:/my_new_app/lib/stocks/widgets/delete_stock_card_dialog.dart), [tag_chip.dart](file:///c:/my_new_app/lib/widgets/tag_chip.dart)

* [lib/stocks/create_stock_card_flow.dart](file:///c:/my_new_app/lib/stocks/create_stock_card_flow.dart)
  - **Purpose:** Step-by-step modal wizard to add a new stock to tracking. Handles exchange selection (NSE vs. BSE), ticker autocomplete using `LocalTickers`, initial transaction entry, and custom tags.
  - **Key Symbols:** `CreateStockCardFlow`
  - **Dependents / Links:** [local_tickers.dart](file:///c:/my_new_app/lib/data/local_tickers.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

* [lib/stocks/add_transaction_sheet.dart](file:///c:/my_new_app/lib/stocks/add_transaction_sheet.dart)
  - **Purpose:** Modal bottom sheet / dialog to log transactions against an existing card (BUY, SELL, DIVIDEND, BONUS). Automatically checks historical Bhavcopy price or live quote for execution validation.
  - **Key Symbols:** `AddTransactionSheet`
  - **Dependents / Links:** [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart), [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

* [lib/stocks/corporate_actions_wizard.dart](file:///c:/my_new_app/lib/stocks/corporate_actions_wizard.dart)
  - **Purpose:** Special Corporate Actions Wizard dialog supporting Indian tax-compliant Demergers (spin-offs with cost apportionment under Sec 49(2C)) and Mergers (amalgamations with share swap ratios and fractional cash settlement).
  - **Key Symbols:** `CorporateActionsWizardDialog`, `CorporateActionType`
  - **Dependents / Links:** [stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart), [local_tickers.dart](file:///c:/my_new_app/lib/data/local_tickers.dart)

* [lib/stocks/widgets/delete_stock_card_dialog.dart](file:///c:/my_new_app/lib/stocks/widgets/delete_stock_card_dialog.dart)
  - **Purpose:** Confirmation dialog with permanent warning and transaction count before cascading deletion of a stock card and all associated records.
  - **Key Symbols:** `confirmAndDeleteStockCard(context, card, [transactionCount])`
  - **Dependents / Links:** [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

---

## 9. Utilities & Shared Widgets

* [lib/utils/app_constants.dart](file:///c:/my_new_app/lib/utils/app_constants.dart)
  - **Purpose:** Project-wide constant values: Indian Standard Time (IST) offsets, market opening/closing hours (9:15 AM - 3:30 PM IST), benchmark probe tickers (`RELIANCE.NS`, etc.).
  - **Key Symbols:** `AppConstants`
  - **Dependents / Links:** [trading_day_service.dart](file:///c:/my_new_app/lib/services/trading_day_service.dart), [price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart)

* [lib/utils/market_calendar.dart](file:///c:/my_new_app/lib/utils/market_calendar.dart)
  - **Purpose:** Calendar math helpers for market operations, detecting weekends and standard trading day offsets.
  - **Key Symbols:** `MarketCalendar`, `isWeekend(date)`
  - **Dependents / Links:** [trading_day_service.dart](file:///c:/my_new_app/lib/services/trading_day_service.dart)

* [lib/widgets/tag_chip.dart](file:///c:/my_new_app/lib/widgets/tag_chip.dart)
  - **Purpose:** Reusable UI chip widget for rendering portfolio category tags (e.g. "Long Term", "High Growth", "Dividend") with consistent styling and deletion callbacks.
  - **Key Symbols:** `TagChip`
  - **Dependents / Links:** [stocks_section.dart](file:///c:/my_new_app/lib/stocks/stocks_section.dart), [stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart)

---

## 10. Test Suites (`test/`)

* [test/stock_split_test.dart](file:///c:/my_new_app/test/stock_split_test.dart)
  - **Purpose:** Comprehensive test suite for Stock Splits: announcement regex parsing (`parseSplitRatio`), weighted-average-cost conservation math, chronologically sequenced replaying, validation against negative balances, and `StocksDao` transaction queries.
  - **Dependents / Links:** [dividend_source.dart](file:///c:/my_new_app/lib/services/dividend_source.dart), [stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart), [stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)

* [test/delete_stock_card_test.dart](file:///c:/my_new_app/test/delete_stock_card_test.dart)
  - **Purpose:** Cascading deletion validation tests ensuring transactions, tags, and cards are purged cleanly.

* [test/duplicate_stock_card_test.dart](file:///c:/my_new_app/test/duplicate_stock_card_test.dart)
  - **Purpose:** Tests preventing duplicate stock card creation and validating unique constraints.

