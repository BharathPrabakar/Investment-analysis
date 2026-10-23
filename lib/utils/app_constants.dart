/// Application-wide constants to eliminate magic numbers and values.
library;

/// Maximum number of characters allowed in a tag name.
const int kMaxTagLength = 30;

/// Standard market opening hour in Indian Standard Time (IST) (9:15 AM).
const int kMarketOpenHourIst = 9;

/// Standard market opening minute in Indian Standard Time (IST) (9:15 AM).
const int kMarketOpenMinuteIst = 15;

/// Cutoff date when BSE transitioned to the UDiFF bhavcopy format; prior dates use legacy format.
final DateTime kBseUdiffCutoff = DateTime(2024, 1, 1);

/// Highly liquid anchor stock used after market open to probe live market quote timestamp and determine if Indian exchanges are open today or closed for a trading holiday.
const String kTradingDayProbeTicker = 'RELIANCE';
