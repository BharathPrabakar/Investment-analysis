from dataclasses import dataclass, field
from typing import Optional


@dataclass
class CorporateAction:
    """Represents a single corporate action event."""
    symbol: str
    company_name: str
    action_type: str           # dividend, bonus, split, rights, agm, etc.
    ex_date: Optional[str]     # Ex-date (most important for trading)
    record_date: Optional[str]
    bc_start_date: Optional[str]   # Book closure start
    bc_end_date: Optional[str]     # Book closure end
    details: str               # Raw description e.g. "Dividend - Rs 5 Per Share"
    source: str                # "NSE" or "BSE"
    series: Optional[str] = None
    face_value: Optional[str] = None

    def __repr__(self):
        return (
            f"CorporateAction(symbol={self.symbol!r}, type={self.action_type!r}, "
            f"ex_date={self.ex_date!r}, details={self.details!r})"
        )


# Fix #4: ACTION_TYPE_MAP is now keyed in an explicit priority order via
# PRIORITY_ORDER below, so "demerger" is always checked before "merger"
# regardless of dict insertion order. Previously this relied on a comment
# to remind maintainers of the ordering requirement — a fragile convention.
ACTION_TYPE_MAP: dict[str, list[str]] = {
    "demerger": ["demerger", "de-merger", "spin-off", "spinoff"],
    "dividend": ["dividend", "interim dividend", "final dividend", "special dividend"],
    "bonus":    ["bonus"],
    "split":    ["split", "sub-division", "subdivision"],
    "rights":   ["rights"],
    "agm":      ["agm", "annual general meeting"],
    "egm":      ["egm", "extraordinary general meeting"],
    "buyback":  ["buyback", "buy back"],
    "merger":   ["merger", "amalgamation", "scheme"],
}

# Explicit iteration order — "demerger" must come before "merger" so that
# descriptions like "de-merger of telecom division" are never misclassified
# as a plain merger. Extend this list when adding new action types.
PRIORITY_ORDER = [
    "demerger",
    "dividend",
    "bonus",
    "split",
    "rights",
    "agm",
    "egm",
    "buyback",
    "merger",
]

# Sanity-check at import time: every key in ACTION_TYPE_MAP must appear in
# PRIORITY_ORDER and vice-versa, so the two structures never drift apart.
_map_keys = set(ACTION_TYPE_MAP)
_priority_keys = set(PRIORITY_ORDER)
if _map_keys != _priority_keys:
    _missing_in_priority = _map_keys - _priority_keys
    _missing_in_map = _priority_keys - _map_keys
    raise RuntimeError(
        "ACTION_TYPE_MAP and PRIORITY_ORDER are out of sync.\n"
        f"  In ACTION_TYPE_MAP but not PRIORITY_ORDER: {_missing_in_priority}\n"
        f"  In PRIORITY_ORDER but not ACTION_TYPE_MAP: {_missing_in_map}"
    )


def classify_action(description: str) -> str:
    """
    Classify a raw action description into a clean, normalised type string.

    Iterates in PRIORITY_ORDER so that higher-priority types (e.g. 'demerger')
    are matched before overlapping lower-priority ones (e.g. 'merger').

    Args:
        description: Raw subject/purpose string from NSE or BSE.

    Returns:
        One of the keys in ACTION_TYPE_MAP, or 'other' if nothing matches.
    """
    if not description:
        return "other"

    desc_lower = description.lower()
    for action_type in PRIORITY_ORDER:
        if any(kw in desc_lower for kw in ACTION_TYPE_MAP[action_type]):
            return action_type
    return "other"