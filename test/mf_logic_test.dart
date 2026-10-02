// test/mf_logic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/logic/mf_logic.dart';

void main() {
  group('MfLogic Tests', () {
    test('Weighted average cost with partial redemption', () {
      final txs = [
        MfTransactionItem(
          id: 1,
          type: 'Purchase',
          date: DateTime(2026, 1, 1),
          units: 100.0,
          nav: 10.0,
          isAvgEntry: false,
        ),
        MfTransactionItem(
          id: 2,
          type: 'Purchase',
          date: DateTime(2026, 1, 10),
          units: 100.0,
          nav: 20.0,
          isAvgEntry: false,
        ),
        MfTransactionItem(
          id: 3,
          type: 'Redemption',
          date: DateTime(2026, 1, 15),
          units: 50.0,
          nav: 25.0,
          isAvgEntry: false,
        ),
      ];

      final summary = MfLogic.computeHoldings(txs);
      expect(summary.totalUnits, 150.0);
      // Invested: 100*10 + 100*20 = 3000. Avg NAV = 15. Redemptions reduce invested proportionally (50 * 15 = 750).
      // Remaining invested = 2250. Remaining units = 150. Avg NAV = 2250 / 150 = 15.0.
      expect(summary.investedAmount, 2250.0);
      expect(summary.averageNav, 15.0);
    });

    test('Timeline validation blocks negative units', () {
      final txs = [
        MfTransactionItem(
          id: 1,
          type: 'Purchase',
          date: DateTime(2026, 1, 1),
          units: 50.0,
          nav: 10.0,
          isAvgEntry: false,
        ),
        MfTransactionItem(
          id: 2,
          type: 'Redemption',
          date: DateTime(2026, 1, 5),
          units: 100.0,
          nav: 12.0,
          isAvgEntry: false,
        ),
      ];

      final result = MfLogic.validateTimeline(txs);
      expect(result.isValid, false);
      expect(result.dependentTransactionId, 2);
    });

    test('Timeline validation requires first transaction to be Purchase', () {
      final txs = [
        MfTransactionItem(
          id: 1,
          type: 'Redemption',
          date: DateTime(2026, 1, 1),
          units: 10.0,
          nav: 10.0,
          isAvgEntry: false,
        ),
      ];

      final result = MfLogic.validateTimeline(txs);
      expect(result.isValid, false);
      expect(result.dependentTransactionId, 1);
    });

    test('Same-date purchase and redemption allowed', () {
      final txs = [
        MfTransactionItem(
          id: 1,
          type: 'Purchase',
          date: DateTime(2026, 1, 1),
          units: 100.0,
          nav: 10.0,
          isAvgEntry: false,
        ),
        MfTransactionItem(
          id: 2,
          type: 'Redemption',
          date: DateTime(2026, 1, 1),
          units: 40.0,
          nav: 10.0,
          isAvgEntry: false,
        ),
      ];

      final result = MfLogic.validateTimeline(txs);
      expect(result.isValid, true);
      final summary = MfLogic.computeHoldings(txs);
      expect(summary.totalUnits, 60.0);
    });

    test('Duplicate detection identifies matching transaction', () {
      final existing = [
        MfTransactionItem(
          id: 1,
          type: 'Purchase',
          date: DateTime(2026, 1, 1),
          units: 100.0,
          nav: 15.5,
          isAvgEntry: false,
        ),
      ];

      final match = MfLogic.detectDuplicate(
        date: DateTime(2026, 1, 1, 10, 30),
        nav: 15.5,
        type: 'Purchase',
        existingTransactions: existing,
      );

      expect(match, isNotNull);
      expect(match?.existingTransactionId, 1);
    });
  });
}
