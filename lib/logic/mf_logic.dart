// lib/logic/mf_logic.dart

class MfTransactionItem {
  final int id;
  final String type; // 'Purchase' or 'Redemption'
  final DateTime date;
  final double units;
  final double nav;
  final bool isAvgEntry;

  MfTransactionItem({
    required this.id,
    required this.type,
    required this.date,
    required this.units,
    required this.nav,
    required this.isAvgEntry,
  });
}

class MfHoldingSummary {
  final double totalUnits;
  final double investedAmount;
  final double averageNav;

  MfHoldingSummary({
    required this.totalUnits,
    required this.investedAmount,
    required this.averageNav,
  });
}

class MfValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? dependentTransactionId;

  MfValidationResult({
    required this.isValid,
    this.errorMessage,
    this.dependentTransactionId,
  });
}

class MfDuplicateMatch {
  final int existingTransactionId;
  final DateTime date;
  final double nav;
  final String type;

  MfDuplicateMatch({
    required this.existingTransactionId,
    required this.date,
    required this.nav,
    required this.type,
  });
}

class MfLogic {
  /// Computes weighted average cost, total units, and invested amount.
  /// Transactions must be sorted in date-ascending order with id tiebreak.
  static MfHoldingSummary computeHoldings(List<MfTransactionItem> transactions) {
    double units = 0.0;
    double invested = 0.0;

    for (var tx in transactions) {
      if (tx.type == 'Purchase') {
        units += tx.units;
        invested += tx.units * tx.nav;
      } else if (tx.type == 'Redemption') {
        if (units > 0) {
          double avgNav = invested / units;
          units -= tx.units;
          if (units < 0.000001) {
            units = 0.0;
            invested = 0.0;
          } else {
            invested -= tx.units * avgNav;
          }
        } else {
          units -= tx.units;
        }
      }
    }

    if (units < 0) units = 0;
    if (invested < 0) invested = 0;
    double avgNav = units > 0 ? invested / units : 0.0;

    return MfHoldingSummary(
      totalUnits: units,
      investedAmount: invested,
      averageNav: avgNav,
    );
  }

  /// Validates the timeline of transactions in date-ascending order (id tiebreak).
  /// Checks:
  /// 1. First transaction must be a Purchase.
  /// 2. No redemption can make units negative.
  static MfValidationResult validateTimeline(List<MfTransactionItem> transactions) {
    if (transactions.isEmpty) {
      return MfValidationResult(isValid: true);
    }

    // Ensure sorted chronologically by date, then id
    final sorted = List<MfTransactionItem>.from(transactions)
      ..sort((a, b) {
        int cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    if (sorted.first.type != 'Purchase') {
      return MfValidationResult(
        isValid: false,
        errorMessage: 'First transaction must be a Purchase.',
        dependentTransactionId: sorted.first.id,
      );
    }

    double currentUnits = 0.0;
    for (var tx in sorted) {
      if (tx.type == 'Purchase') {
        currentUnits += tx.units;
      } else if (tx.type == 'Redemption') {
        currentUnits -= tx.units;
        if (currentUnits < -0.000001) {
          return MfValidationResult(
            isValid: false,
            errorMessage: 'Redemption of ${tx.units} units exceeds available holdings (${currentUnits + tx.units}).',
            dependentTransactionId: tx.id,
          );
        }
      }
    }

    return MfValidationResult(isValid: true);
  }

  /// Detects if a new transaction matches an existing one (same date, same NAV, same type).
  static MfDuplicateMatch? detectDuplicate({
    required DateTime date,
    required double nav,
    required String type,
        required List<MfTransactionItem> existingTransactions,
    int? excludeId,
  }) {
    for (var tx in existingTransactions) {
      if (excludeId != null && tx.id == excludeId) continue;
      
      // Compare dates (year, month, day)
      bool sameDate = tx.date.year == date.year &&
          tx.date.month == date.month &&
          tx.date.day == date.day;
      
      // Compare NAV within a small epsilon
      bool sameNav = (tx.nav - nav).abs() < 0.0001;
      bool sameType = tx.type == type;

      if (sameDate && sameNav && sameType) {
        return MfDuplicateMatch(
          existingTransactionId: tx.id,
          date: tx.date,
          nav: tx.nav,
          type: tx.type,
        );
      }
    }
    return null;
  }
}
