# Git Commit History & Changelog

> **PURPOSE:**
> This file tracks every commit made to the repository (`BharathPrabakar/Investment-analysis`), including its short commit ID, date, author, description, and an itemized breakdown of what was changed and why.

---

### `a6bb34b` — 2026-10-23
**Message:** `docs: add COMMITS_HISTORY.md tracking all commit hashes and changes`

- Created [COMMITS_HISTORY.md](file:///c:/my_new_app/COMMITS_HISTORY.md) to log every commit ID, timestamp, and human-readable explanation of features, refactors, and bugfixes.

---

### `ac921c8` — 2026-10-23
**Message:** `refactor: purge mutual funds, add BSE support, and establish project documentation and file map`

- **Purged Mutual Funds Code:**
  - Removed all MF database tables (`lib/database/tables/mf_cards_table.dart`, `mf_transactions_table.dart`).
  - Removed MF DAOs (`lib/database/daos/mf_dao.dart`, `mf_dao.g.dart`).
  - Removed MF business logic and unit tests (`lib/logic/mf_logic.dart`, `test/mf_dao_test.dart`, `test/mf_logic_test.dart`).
- **BSE Bhavcopy & Equity Integration:**
  - Added BSE market support across quote fetchers, local tickers lookup, and transaction validation.
  - Added tests for BSE support (`test/bse_support_test.dart`).
- **Architecture Documentation & Fast Agent Navigation:**
  - Added [PROJECT_OVERVIEW.md](file:///c:/my_new_app/PROJECT_OVERVIEW.md) containing the architectural map, database schemas, and service layer contracts.
  - Added [FILE_MAP.md](file:///c:/my_new_app/FILE_MAP.md) detailing every file, its purpose, key symbols, and dependents to minimize token usage for AI agents.
  - Updated [AGENTS.md](file:///c:/my_new_app/AGENTS.md) with strict zero dead-code rules and index consultation requirements.
- **Repository Cleanup:**
  - Cleaned up one-off scratch probe scripts and unneeded temporary files.

---

### `7980f31` — 2026-10-03
**Message:** `MF stage 1B: fix analyzer issues in mf_dao and mf_dao_test`

- Resolved static analysis errors and warnings for mutual fund DAOs and database tests.

---

### `82b7692` — 2026-10-02
**Message:** `MF stage 1`

- Initial introduction of mutual fund schema and logic (subsequently purged in `ac921c8`).

---

### `419634d` — 2026-10-02
**Message:** `stocks complete, before MF`

- Baseline stock tracking features completed:
  - SQLite database schema for stock cards, transactions, and tags.
  - NSE Bhavcopy ZIP parser and disk cache.
  - Yahoo Finance live quote integration.
  - P&L and Weighted Average Cost calculations.
  - Flutter UI for stock holdings, card creation wizard, and transaction logging.
