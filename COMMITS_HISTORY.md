# Git Commit History & Changelog

> **PURPOSE:**
> This file tracks every commit made to the repository (`BharathPrabakar/Investment-analysis`), including its short commit ID, date, author, description, and an itemized breakdown of what was changed and why.

---

### `058424b` — 2026-10-23
**Message:** `feat: implement edgecase fixes for reverse splits, fractional cash, circuit tolerance, and order precedence`

- **Reverse Stock Splits / Consolidations:**
  - Updated `parseSplitRatio` in [lib/services/dividend_source.dart](file:///c:/my_new_app/lib/services/dividend_source.dart) to detect consolidation ratios and reverse splits where face value increases (`oldFaceValue < newFaceValue` or `consolidation X:1`).
  - Added `CONSOLIDATION` transaction handling in [lib/logic/stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart): reduces held shares without reducing invested capital, proportionally raising weighted average cost ($WAC = Invested / Qty$).
  - Added DAO lookup methods `hasConsolidationTransaction` and `findConsolidationTransaction` in [lib/database/daos/stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart).
  - Auto-reconciliation in [lib/stocks/stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart) auto-inserts `CONSOLIDATION` transactions with custom amber UI badge (`"-X shares merged · Reverse split (capital preserved)"`).
- **Fractional Bonus Entitlements in Cash (`FRACTIONAL_CASH`):**
  - When bonus share ratios produce fractional Demat shares, integer shares are credited via `BONUS` and fractional entitlements are computed and auto-recorded as `FRACTIONAL_CASH` transactions with payout amounts based on holding cost basis.
  - Added `hasFractionalCashTransaction` and `findFractionalCashTransaction` in [lib/database/daos/stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart).
  - Included `FRACTIONAL_CASH` in cash return / dividend totals without modifying share counts.
  - Rendered with green UI badge (`"Fractional bonus entitlement settled in cash"` and `+ ₹Amount`).
- **Circuit Freeze Days Tolerance:**
  - Added `containsPrice(double price)` to `PriceRange` in [lib/services/price_service.dart](file:///c:/my_new_app/lib/services/price_service.dart): provides $\pm 0.2\%$ tolerance (clamped between 5 paise and ₹5.00) on lower/upper circuit freeze days where high equals low in Bhavcopy.
  - Applied to [lib/stocks/add_transaction_sheet.dart](file:///c:/my_new_app/lib/stocks/add_transaction_sheet.dart) and [lib/stocks/create_stock_card_flow.dart](file:///c:/my_new_app/lib/stocks/create_stock_card_flow.dart).
- **Same-Day Order Precedence & Replay Safety:**
  - Ranked order in `compareTransactions`: Rank 1 (`SPLIT`, `BONUS`, `CONSOLIDATION`), Rank 2 (`BUY`), Rank 3 (`SELL`), Rank 4 (`DIVIDEND`, `FRACTIONAL_CASH`).
- **Automated Unit Tests & Documentation:**
  - Added 5 new unit tests in [test/stock_split_test.dart](file:///c:/my_new_app/test/stock_split_test.dart) covering consolidation parsing, ledger math, fractional cash handling, and DAO operations (17/17 passing).
  - Updated [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md) Section 6.

---

### `c1c52bb` — 2026-10-23
**Message:** `fix: prevent false dividends and duplicate bonuses from stock sub-division corporate actions`

- **Corporate Action Disambiguation & Hardened Filtering:**
  - Resolved keyword false positive where `"sub-division"` was detected as `"div"` and its face value numbers (e.g. `Rs 10 to Rs 2`) were summed into an erroneous ₹12 cash dividend.
  - Hardened `parseDividendAmount` in [lib/services/dividend_source.dart](file:///c:/my_new_app/lib/services/dividend_source.dart) to reject strings containing split/sub-division keywords unless explicit per-share dividend keywords are present.
  - Tightened NSE and BSE corporate action subject matching to require whole words (`dividend`, `interim`, `final`, `special`, or whole word `div`).
  - Guarded `fetchBonusIssues` and `StockCardDetailScreen` ([lib/stocks/stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart)) so Yahoo Finance `events=split` events matching an existing stock split on the same date are never duplicated as bonus issues.
  - Added test case in [test/stock_split_test.dart](file:///c:/my_new_app/test/stock_split_test.dart) verifying sub-division announcements are rejected by `parseDividendAmount`.
  - Updated [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md) Section 6 with disambiguation safeguards.

---

### `f90fbd2` — 2026-10-23
**Message:** `feat: implement stock splits auto-detection, ledger calculation, and UI badge`

- **Category D Corporate Action — Stock Splits:**
  - Added `SplitEvent` model with face value multiplier calculation and JSON serialization in [lib/services/dividend_source.dart](file:///c:/my_new_app/lib/services/dividend_source.dart).
  - Implemented `parseSplitRatio` regex supporting Indian exchange announcement formats (`from Rs. X to Rs. Y`, `split 1:X`, `sub-division 1:X`).
  - Added `fetchStockSplits` integrating NSE/BSE corporate action endpoints and Yahoo Finance fallback with persistent disk caching.
  - Updated `StockLogic` ([lib/logic/stock_logic.dart](file:///c:/my_new_app/lib/logic/stock_logic.dart)):
    - Set `SPLIT` transaction precedence equal to `BONUS` (1) ahead of `SELL` (2) and `DIVIDEND` (3).
    - Updated `computeHoldingState` so `SPLIT` increases `quantityHeld` without adding invested capital, automatically adjusting weighted-average cost downwards ($Invested / TotalQty$).
    - Replay validation recognizes `SPLIT` as non-negative quantity addition.
  - Updated `StocksDao` ([lib/database/daos/stocks_dao.dart](file:///c:/my_new_app/lib/database/daos/stocks_dao.dart)) with `hasSplitTransaction` and `findSplitTransaction`.
  - Integrated auto-detection replay in `StockCardDetailScreen` ([lib/stocks/stock_card_detail.dart](file:///c:/my_new_app/lib/stocks/stock_card_detail.dart)), applying splits chronologically before bonuses and dividends. Added custom UI row styling with blue split icon and `"+X split shares credited · Face value sub-division"` badge.
  - Added automated unit test suite ([test/stock_split_test.dart](file:///c:/my_new_app/test/stock_split_test.dart)) with 12 tests covering regex extraction, ledger math, WAC scaling, replay ordering, and DAO queries.
  - Updated [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md) Section 6 and [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md) Section 10.

---

### `828e110` — 2026-10-23
**Message:** `docs: formalize commit logging and push requirements in agent instructions`

- Updated [AGENTS.md](file:///c:/my_new_app/AGENTS.md) Rule #7 mandating that every completed task/feature be pushed to `origin main` and logged in [COMMITS_HISTORY.md](file:///c:/my_new_app/COMMITS_HISTORY.md).
- Added Section 0 in [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md) detailing documentation and directive files.

---

### `2b18ad0` — 2026-10-23
**Message:** `docs: add COMMITS_HISTORY.md tracking all commit hashes and changes`

- Created [COMMITS_HISTORY.md](file:///c:/my_new_app/COMMITS_HISTORY.md) to log every commit ID, timestamp, and human-readable explanation of features, refactors, and bugfixes.

---

### `ac921c8` — 2026-10-23
**Message:** `refactor: purge discarded mutual funds experiment, add BSE support, and establish project documentation and file map`

- **BSE Bhavcopy & Equity Integration:**
  - Added complete BSE market support across quote fetchers, local tickers search index, and transaction validation.
  - Added unit and integration tests for BSE (`test/bse_support_test.dart`).
- **Clean Baseline & Architecture Documentation:**
  - Removed discarded experimental mutual fund code to keep the repository lean and focused on verified stock tracking.
  - Added [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md) containing the architectural map, database schemas, and service layer contracts.
  - Added [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md) detailing every file, its purpose, key symbols, and dependents to minimize token usage for AI agents.
  - Updated [AGENTS.md](file:///c:/my_new_app/AGENTS.md) with strict zero dead-code rules and index consultation requirements.
- **Repository Cleanup:**
  - Purged temporary scratch probe scripts and unneeded testing artifacts.

---

### `419634d` — 2026-10-02
**Message:** `stocks complete`

- Baseline stock tracking features established:
  - SQLite database schema for stock cards, transactions, and tags.
  - NSE Bhavcopy ZIP parser and local disk caching.
  - Yahoo Finance live quote integration.
  - Portfolio mathematics: Weighted Average Cost, realized & unrealized P&L.
  - Flutter UI for stock holdings, card creation wizard, and transaction logging.
