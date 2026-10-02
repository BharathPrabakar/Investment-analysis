"""
india_corp_actions - Main Client
Unified interface for fetching Indian stock market corporate actions
from NSE and BSE India. 100% free, no API keys required.
"""

import logging
import pandas as pd
from datetime import datetime
from typing import List, Optional, Literal

from .nse import NSEFetcher
from .bse import BSEFetcher
from .models import CorporateAction

logger = logging.getLogger(__name__)

# Columns to include in the output DataFrame, in display order.
_DF_COL_ORDER = [
    "symbol", "company_name", "action_type", "ex_date",
    "record_date", "details", "series", "face_value",
    "bc_start_date", "bc_end_date", "source",
]


def _reformat_date(date_str: Optional[str], to_fmt: str) -> Optional[str]:
    """
    Re-format a date string into the target format.

    Tries several common input formats so the caller can pass either
    'DD-MM-YYYY' or 'YYYY-MM-DD' without worrying which one NSE/BSE needs.

    Args:
        date_str: Input date string, or None.
        to_fmt:   strftime format string for the desired output.

    Returns:
        Re-formatted date string, or None if input is None / unparseable.
    """
    if date_str is None:
        return None

    for fmt in ("%d-%m-%Y", "%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(date_str, fmt).strftime(to_fmt)
        except ValueError:
            continue

    logger.warning(
        "Could not parse date %r — expected DD-MM-YYYY or YYYY-MM-DD. "
        "Passing it through unchanged.",
        date_str,
    )
    return date_str


class IndiaCorpActions:
    """
    Unified client to fetch corporate actions from NSE and BSE.

    Usage:
        client = IndiaCorpActions()

        # Get all upcoming corporate actions (NSE, next 3 months)
        df = client.get_actions_df()

        # Filter by stock
        df = client.get_actions_df(symbol="RELIANCE")

        # Filter by type: 'dividend', 'bonus', 'split', 'rights', 'agm', etc.
        df = client.get_actions_df(action_type="dividend")

        # Use BSE as source
        df = client.get_actions_df(source="BSE")

        # Get both NSE + BSE combined
        df = client.get_actions_df(source="both")

    Date format:
        Pass dates as either 'DD-MM-YYYY' or 'YYYY-MM-DD' — the client
        normalises them automatically for each exchange.
    """

    def __init__(self, log_level: str = "WARNING"):
        logging.basicConfig(level=getattr(logging, log_level.upper(), logging.WARNING))
        self._nse: Optional[NSEFetcher] = None
        self._bse: Optional[BSEFetcher] = None

    @property
    def nse(self) -> NSEFetcher:
        if self._nse is None:
            self._nse = NSEFetcher()
        return self._nse

    @property
    def bse(self) -> BSEFetcher:
        if self._bse is None:
            self._bse = BSEFetcher()
        return self._bse

    # ─────────────────────────────────────────
    # Core method
    # ─────────────────────────────────────────

    def get_actions(
        self,
        symbol: Optional[str] = None,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None,
        action_type: Optional[str] = None,
        source: Literal["NSE", "BSE", "both"] = "NSE",
    ) -> List[CorporateAction]:
        """
        Fetch corporate actions.

        Args:
            symbol:      Stock symbol e.g. 'RELIANCE'. Filters NSE results directly;
                         BSE results are filtered post-fetch (BSE API has no symbol filter).
                         None = all stocks.
            from_date:   Date as 'DD-MM-YYYY' or 'YYYY-MM-DD'. None = today.
            to_date:     Date as 'DD-MM-YYYY' or 'YYYY-MM-DD'. None = 3 months ahead.
            action_type: Filter by type: 'dividend','bonus','split','rights','agm',
                         'merger','buyback','demerger','other'. None = all.
            source:      'NSE' (default), 'BSE', or 'both'.

        Returns:
            List of CorporateAction objects.
        """
        # Fix #2: Normalise dates into the format each exchange expects,
        # regardless of what format the caller provided.
        nse_from = _reformat_date(from_date, "%d-%m-%Y")
        nse_to   = _reformat_date(to_date,   "%d-%m-%Y")
        bse_from = _reformat_date(from_date, "%Y-%m-%d")
        bse_to   = _reformat_date(to_date,   "%Y-%m-%d")

        results: List[CorporateAction] = []

        if source in ("NSE", "both"):
            try:
                nse_results = self.nse.get_corporate_actions(
                    symbol=symbol, from_date=nse_from, to_date=nse_to
                )
                results.extend(nse_results)
                logger.info("NSE: fetched %d actions", len(nse_results))
            except Exception as e:
                logger.error("NSE fetch failed: %s", e)

        if source in ("BSE", "both"):
            try:
                bse_results = self.bse.get_corporate_actions(
                    from_date=bse_from, to_date=bse_to
                )

                # Fix #6: BSE API has no symbol filter — apply it ourselves
                # so callers get consistent behaviour across both sources.
                if symbol:
                    sym_upper = symbol.upper()
                    before = len(bse_results)
                    bse_results = [
                        r for r in bse_results
                        if r.symbol and r.symbol.upper() == sym_upper
                    ]
                    logger.debug(
                        "BSE: symbol filter '%s' reduced %d → %d results",
                        sym_upper, before, len(bse_results),
                    )

                results.extend(bse_results)
                logger.info("BSE: fetched %d actions", len(bse_results))
            except Exception as e:
                logger.error("BSE fetch failed: %s", e)

        # Filter by action_type if given
        if action_type:
            at = action_type.lower()
            results = [r for r in results if r.action_type == at]

        return results

    def get_actions_df(
        self,
        symbol: Optional[str] = None,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None,
        action_type: Optional[str] = None,
        source: Literal["NSE", "BSE", "both"] = "NSE",
    ) -> pd.DataFrame:
        """Same as get_actions() but returns a clean pandas DataFrame."""
        actions = self.get_actions(
            symbol=symbol,
            from_date=from_date,
            to_date=to_date,
            action_type=action_type,
            source=source,
        )
        if not actions:
            return pd.DataFrame()

        df = pd.DataFrame([vars(a) for a in actions])

        # Fix #9: Warn about any CorporateAction fields not in the display list
        # so they are not silently dropped after a model change.
        known_cols = set(_DF_COL_ORDER)
        extra_cols = [c for c in df.columns if c not in known_cols]
        if extra_cols:
            logger.debug(
                "get_actions_df: dropping unrecognised column(s) %s. "
                "Add them to _DF_COL_ORDER to include in output.",
                extra_cols,
            )

        df = df[[c for c in _DF_COL_ORDER if c in df.columns]]
        return df.reset_index(drop=True)

    # ─────────────────────────────────────────
    # Convenience shortcuts
    # ─────────────────────────────────────────

    def get_dividends(self, **kwargs) -> pd.DataFrame:
        """Get upcoming dividend announcements."""
        return self.get_actions_df(action_type="dividend", **kwargs)

    def get_bonus(self, **kwargs) -> pd.DataFrame:
        """Get upcoming bonus issue announcements."""
        return self.get_actions_df(action_type="bonus", **kwargs)

    def get_splits(self, **kwargs) -> pd.DataFrame:
        """Get upcoming stock split announcements."""
        return self.get_actions_df(action_type="split", **kwargs)

    def get_rights(self, **kwargs) -> pd.DataFrame:
        """Get upcoming rights issue announcements."""
        return self.get_actions_df(action_type="rights", **kwargs)

    def get_buybacks(self, **kwargs) -> pd.DataFrame:
        """Get upcoming buyback announcements."""
        return self.get_actions_df(action_type="buyback", **kwargs)

    # ─────────────────────────────────────────
    # NSE-only extras
    # ─────────────────────────────────────────

    def get_upcoming_results(self) -> pd.DataFrame:
        """Get upcoming quarterly result dates from NSE."""
        data = self.nse.get_upcoming_results()
        return pd.DataFrame(data) if data else pd.DataFrame()

    def get_board_meetings(
        self, from_date: Optional[str] = None, to_date: Optional[str] = None
    ) -> pd.DataFrame:
        """Get upcoming board meeting dates from NSE."""
        # Normalise dates for NSE format
        data = self.nse.get_board_meetings(
            from_date=_reformat_date(from_date, "%d-%m-%Y"),
            to_date=_reformat_date(to_date, "%d-%m-%Y"),
        )
        return pd.DataFrame(data) if data else pd.DataFrame()

    def get_announcements(self, symbol: Optional[str] = None) -> pd.DataFrame:
        """Get latest corporate announcements from NSE."""
        data = self.nse.get_announcements(symbol=symbol)
        return pd.DataFrame(data) if data else pd.DataFrame()