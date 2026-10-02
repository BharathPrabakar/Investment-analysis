import time
import logging
import requests
from typing import Optional

logger = logging.getLogger(__name__)

NSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate",
    "Referer": "https://www.nseindia.com/",
    "Connection": "keep-alive",
}

BSE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": "https://www.bseindia.com/",
}


def create_nse_session(retries: int = 3, delay: float = 1.0) -> Optional[requests.Session]:
    """
    Create an authenticated NSE session by warming up cookies via homepage visit.
    NSE blocks direct API calls without a valid session cookie.
    """
    session = requests.Session()
    session.headers.update(NSE_HEADERS)

    urls_to_warm = [
        "https://www.nseindia.com",
        "https://www.nseindia.com/market-data/live-equity-market",
    ]

    for attempt in range(retries):
        try:
            for url in urls_to_warm:
                resp = session.get(url, timeout=10)
                resp.raise_for_status()
                time.sleep(delay)
            logger.debug("NSE session established successfully.")
            return session
        except requests.RequestException as e:
            logger.warning("NSE session attempt %d failed: %s", attempt + 1, e)
            time.sleep(delay * (attempt + 1))

    logger.error("Failed to establish NSE session after %d retries.", retries)
    return None


def create_bse_session() -> requests.Session:
    """Create a simple BSE session."""
    session = requests.Session()
    session.headers.update(BSE_HEADERS)
    return session


def safe_get(
    session: requests.Session,
    url: str,
    params: dict = None,
    retries: int = 3,
    delay: float = 1.5,
) -> Optional[dict]:
    """
    GET request with retry logic. Returns parsed JSON or None.

    Handles HTTP errors, network errors, and non-JSON responses
    without letting any of them propagate to the caller.
    """
    # Fix #3 (guard): Catch a None session explicitly before any network call
    # so the error message is actionable rather than a bare AttributeError.
    if session is None:
        logger.error("safe_get called with session=None. Re-initialise the client.")
        return None

    for attempt in range(retries):
        try:
            resp = session.get(url, params=params, timeout=15)
            resp.raise_for_status()

            # Fix #7: Catch JSON decode errors so a stray HTML error page
            # from NSE/BSE doesn't propagate past the retry loop.
            try:
                return resp.json()
            except requests.exceptions.JSONDecodeError:
                logger.warning(
                    "Non-JSON response from %s (attempt %d). "
                    "First 200 chars: %r",
                    url, attempt + 1, resp.text[:200],
                )
                # A bad response body won't improve on retry — bail out.
                return None

        except requests.exceptions.HTTPError as e:
            status = e.response.status_code
            logger.warning("HTTP %d on attempt %d for %s", status, attempt + 1, url)
            if status == 401:
                logger.error("Session expired or unauthorised. Re-initialise the client.")
                return None
            # 4xx errors (except 429) won't improve on retry.
            if 400 <= status < 500 and status != 429:
                logger.error("Non-retryable HTTP %d for %s. Aborting.", status, url)
                return None

        except requests.RequestException as e:
            logger.warning("Request error on attempt %d for %s: %s", attempt + 1, url, e)

        time.sleep(delay * (attempt + 1))

    logger.error("All %d attempts failed for %s.", retries, url)
    return None