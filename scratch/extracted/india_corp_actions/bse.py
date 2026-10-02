import logging
from typing import List, Optional
from datetime import datetime, timedelta

from .utils import create_bse_session, safe_get
from .models import CorporateAction, classify_action

# Fix #1: Removed unused `from bs4 import BeautifulSoup` import.

logger = logging.getLogger(__name__)

BSE_BASE = "https://api.bseindia.com/BseIndiaAPI/api"

# BSE action-type codes accepted by the API.
BSE_ACTION_TYPES = {
    "All": "All",
    "D": "Dividend",
    "B": "Bonus",
    "S": "Split",
    "R": "Rights",
}


def _strip_dashes(date_str: Optional[str]) -> Optional[str]:
    """Convert 'YYYY-MM-DD' → 'YYYYMMDD' as required by the BSE API."""
    return date_str.replace("-", "") if date_str else None


class BSEFetcher:
    """Fetches corporate actions data from BSE India."""

    def __init__(self):
        self.session = create_bse_session()

    def get_corporate_actions(
        self,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None,
        action_type: str = "All",
    ) -> List[CorporateAction]:
        """
        Fetch corporate actions from BSE.

        Args:
            from_date:   'YYYY-MM-DD'. Defaults to today.
            to_date:     'YYYY-MM-DD'. Defaults to 3 months ahead.
            action_type: BSE category code — 'All', 'D' (Dividend), 'B' (Bonus),
                         'S' (Split), 'R' (Rights). Defaults to 'All'.

        Returns:
            List of CorporateAction objects.
        """
        # Fix #new: Validate action_type early to surface typos immediately.
        if action_type not in BSE_ACTION_TYPES:
            raise ValueError(
                f"Invalid action_type {action_type!r}. "
                f"Must be one of: {list(BSE_ACTION_TYPES)}"
            )

        today = datetime.today()
        if from_date is None:
            from_date_fmt = today.strftime("%Y%m%d")
        else:
            from_date_fmt = _strip_dashes(from_date)

        if to_date is None:
            to_date_fmt = (today + timedelta(days=90)).strftime("%Y%m%d")
        else:
            to_date_fmt = _strip_dashes(to_date)

        url = f"{BSE_BASE}/CorporateAction/w"
        params = {
            "strCat": action_type,
            "strPrevDate": from_date_fmt,
            "strScrip": "",
            "strSearch": "S",
            "strToDate": to_date_fmt,
            "strType": "C",
            "scripcode": "",
        }

        data = safe_get(self.session, url, params=params)
        if data is None:
            logger.warning("BSE returned no data.")
            return []

        return self._parse(data)

    def get_dividends(self, from_date=None, to_date=None) -> List[CorporateAction]:
        return self.get_corporate_actions(from_date, to_date, action_type="D")

    def get_bonus(self, from_date=None, to_date=None) -> List[CorporateAction]:
        return self.get_corporate_actions(from_date, to_date, action_type="B")

    def get_splits(self, from_date=None, to_date=None) -> List[CorporateAction]:
        return self.get_corporate_actions(from_date, to_date, action_type="S")

    def get_rights(self, from_date=None, to_date=None) -> List[CorporateAction]:
        return self.get_corporate_actions(from_date, to_date, action_type="R")

    def _parse(self, data) -> List[CorporateAction]:
        """Parse BSE JSON into CorporateAction objects."""
        results = []
        records = data if isinstance(data, list) else data.get("Table", [])

        for item in (records or []):
            # Fix #new: Skip non-dict items (e.g. None) without swallowing
            # real exceptions from the constructor below.
            if not isinstance(item, dict):
                logger.debug("Skipping non-dict BSE record: %r", item)
                continue

            try:
                details = item.get("Purpose", item.get("SUBJECTLINE", ""))

                # Fix #5: `record_date` and `bc_end_date` previously both used
                # `ND_END_DT`, masking the real record-date field.
                # BSE uses `RD_DATE` / `RecordDate` for the record date and
                # `ND_END_DT` only for the book-closure end date.
                record_date = item.get("RD_DATE", item.get("RecordDate", ""))
                bc_end_date = item.get("ND_END_DT", "")

                action = CorporateAction(
                    symbol=item.get("SCRIP_CD", item.get("scripcode", "")),
                    company_name=item.get("SCRIP_NAME", item.get("LONG_NAME", "")),
                    action_type=classify_action(details),
                    ex_date=item.get("EX_DATE", item.get("ExDate", "")),
                    record_date=record_date,
                    bc_start_date=item.get("ND_START_DT", ""),
                    bc_end_date=bc_end_date,
                    details=details,
                    face_value=item.get("Face_Value", ""),
                    source="BSE",
                )
                results.append(action)
            except Exception as e:
                logger.debug("Skipping malformed BSE record: %s", e)

        return results