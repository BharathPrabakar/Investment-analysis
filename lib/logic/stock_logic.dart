// lib/logic/stock_logic.dart
//
// Pure business-logic functions for stocks.
// No Flutter or database imports — fully unit-testable in isolation.

/// A single transaction record as consumed by business-logic functions.
/// Mirrors the database row but is decoupled from Drift generated types.
class TxRecord {
  final int id;
  final String type; // "BUY" or "SELL"
  final DateTime date;
  final double price;
  final int quantity;
  final double totalAmount;

  const TxRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3a  Weighted-average-cost calculation
// ═══════════════════════════════════════════════════════════════════════════════

/// Current holding state derived from a card's full transaction history.
class HoldingState {
  /// Quantity currently held (after all buys and sells).
  final int quantityHeld;

  /// Weighted-average cost per share for the current holding.
  final double avgBuyPrice;

  /// Total capital deployed (avgBuyPrice * quantityHeld).
  final double investedValue;

  const HoldingState({
    required this.quantityHeld,
    required this.avgBuyPrice,
    required this.investedValue,
  });

  static const zero = HoldingState(
    quantityHeld: 0,
    avgBuyPrice: 0,
    investedValue: 0,
  );
}

/// Shared sort comparator for transaction records:
/// 1. date ASC
/// 2. Order on same calendar date: BUY before SELL before DIVIDEND
/// 3. id ASC
int compareTransactions(TxRecord a, TxRecord b) {
  final aDate = DateTime(a.date.year, a.date.month, a.date.day);
  final bDate = DateTime(b.date.year, b.date.month, b.date.day);
  final dateCmp = aDate.compareTo(bDate);
  if (dateCmp != 0) return dateCmp;
  if (a.type != b.type) {
    int rank(String type) {
      switch (type.toUpperCase()) {
        case 'BUY':
          return 0;
        case 'SPLIT':
        case 'BONUS':
        case 'CONSOLIDATION':
          return 1;
        case 'SELL':
          return 2;
        case 'DIVIDEND':
        case 'FRACTIONAL_CASH':
          return 3;
        default:
          return 4;
      }
    }
    return rank(a.type).compareTo(rank(b.type));
  }
  return a.id.compareTo(b.id);
}

/// Compute the current [HoldingState] from [transactions].
///
/// NOTE: Excludes all rows where [type] == "DIVIDEND" or "FRACTIONAL_CASH" — cash payouts never
/// participate in quantity, avg price, or invested value.
///
/// Sort order: uses [compareTransactions] (date ASC, BUY/SPLIT/BONUS/CONSOLIDATION before SELL on same date, id ASC).
///
/// Algorithm:
///   BUY           → add to pool: new_avg = (pool_cost + buy_cost) / (pool_qty + buy_qty)
///   SPLIT         → adds additional split quantity with 0 cost: new_avg = pool_cost / (pool_qty + split_qty)
///   BONUS         → adds quantity with 0 cost: new_avg = pool_cost / (pool_qty + bonus_qty)
///   CONSOLIDATION → reduces quantity (shares merged) while preserving totalCost: new_avg = pool_cost / (pool_qty - consolidated_qty)
///   SELL          → reduce quantity proportionally; cost basis per share is unchanged
HoldingState computeHoldingState(List<TxRecord> transactions) {
  final buySellTx = transactions.where((t) {
    final type = t.type.toUpperCase();
    return type != 'DIVIDEND' && type != 'FRACTIONAL_CASH';
  });
  final sorted = List.of(buySellTx)..sort(compareTransactions);
  int qty = 0;
  double totalCost = 0;

  for (final tx in sorted) {
    final type = tx.type.toUpperCase();
    if (type == 'BUY') {
      totalCost += tx.totalAmount;
      qty += tx.quantity;
    } else if (type == 'BONUS' || type == 'SPLIT') {
      qty += tx.quantity;
      // Bonus / Split shares cost 0 additional invested capital, totalCost is unchanged
    } else if (type == 'CONSOLIDATION') {
      // Reverse Split / Consolidation reduces shares held while conserving invested capital
      qty -= tx.quantity;
      if (qty < 0) qty = 0;
      if (qty == 0) totalCost = 0;
    } else {
      // SELL: reduce quantity; cost basis per remaining share is unchanged
      qty -= tx.quantity;
      if (qty <= 0) {
        qty = 0;
        totalCost = 0;
      } else {
        // Remove proportional cost
        final avgCost = totalCost / (qty + tx.quantity);
        totalCost -= avgCost * tx.quantity;
      }
    }
  }

  if (qty == 0) return HoldingState.zero;

  final avg = totalCost / qty;
  return HoldingState(
    quantityHeld: qty,
    avgBuyPrice: double.parse(avg.toStringAsFixed(4)),
    investedValue: double.parse(totalCost.toStringAsFixed(2)),
  );
}

/// Computes the total dividend and fractional corporate action cash payout earned.
double totalDividendEarned(List<TxRecord> transactions) {
  double total = 0;
  for (final tx in transactions) {
    final type = tx.type.toUpperCase();
    if (type == 'DIVIDEND' || type == 'FRACTIONAL_CASH') {
      total += tx.totalAmount;
    }
  }
  return double.parse(total.toStringAsFixed(2));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3b  Quantity-never-negative validation
// ═══════════════════════════════════════════════════════════════════════════════

/// The result of a quantity-negativity validation.
class ValidationResult {
  final bool isValid;

  /// The first transaction (post-proposed-change) that would drive quantity < 0.
  /// Null when [isValid] is true.
  final TxRecord? conflictingTransaction;

  const ValidationResult.valid() : isValid = true, conflictingTransaction = null;
  const ValidationResult.invalid(this.conflictingTransaction) : isValid = false;
}

enum ProposedOpKind { add, edit, delete }

/// A proposed mutation to a card's transaction list.
class ProposedOp {
  final ProposedOpKind kind;

  /// For [ProposedOpKind.delete]: the id of the transaction to remove.
  final int? deleteId;

  /// For [ProposedOpKind.add] / [ProposedOpKind.edit]: the new/updated record.
  final TxRecord? record;

  /// For [ProposedOpKind.edit]: the id of the existing transaction being replaced.
  final int? editTargetId;

  const ProposedOp.add(TxRecord this.record)
      : kind = ProposedOpKind.add,
        deleteId = null,
        editTargetId = null;

  const ProposedOp.delete(int this.deleteId)
      : kind = ProposedOpKind.delete,
        record = null,
        editTargetId = null;

  const ProposedOp.edit({required int targetId, required TxRecord this.record})
      : kind = ProposedOpKind.edit,
        deleteId = null,
        editTargetId = targetId;
}

/// Replays the full transaction history after applying [op] and returns whether
/// quantity ever goes negative.
///
/// NOTE: Excludes all DIVIDEND rows from validation replay.
///
/// [existing] must be sorted date ASC, id ASC.
ValidationResult validateQuantityNeverNegative(
  List<TxRecord> existing,
  ProposedOp op,
) {
  // Build the proposed list excluding cash payout rows (DIVIDEND, FRACTIONAL_CASH)
  List<TxRecord> proposed = existing.where((t) {
    final type = t.type.toUpperCase();
    return type != 'DIVIDEND' && type != 'FRACTIONAL_CASH';
  }).toList();

  switch (op.kind) {
    case ProposedOpKind.delete:
      proposed.removeWhere((t) => t.id == op.deleteId);
    case ProposedOpKind.add:
      if (op.record != null) {
        final type = op.record!.type.toUpperCase();
        if (type != 'DIVIDEND' && type != 'FRACTIONAL_CASH') {
          proposed.add(op.record!);
        }
      }
    case ProposedOpKind.edit:
      proposed.removeWhere((t) => t.id == op.editTargetId);
      if (op.record != null) {
        final type = op.record!.type.toUpperCase();
        if (type != 'DIVIDEND' && type != 'FRACTIONAL_CASH') {
          proposed.add(op.record!);
        }
      }
  }

  // Sort: shared ordering (date ASC, BUY/SPLIT/BONUS/CONSOLIDATION before SELL on same date, id ASC)
  proposed.sort(compareTransactions);

  // Replay
  int runningQty = 0;
  for (final tx in proposed) {
    final type = tx.type.toUpperCase();
    if (type == 'BUY' || type == 'BONUS' || type == 'SPLIT') {
      runningQty += tx.quantity;
    } else {
      // SELL and CONSOLIDATION reduce quantity
      runningQty -= tx.quantity;
      if (runningQty < 0) {
        return ValidationResult.invalid(tx);
      }
    }
  }
  return const ValidationResult.valid();
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3c  Duplicate-transaction check
// ═══════════════════════════════════════════════════════════════════════════════

/// Result returned from [findDuplicateTransaction].
class DuplicateCheckResult {
  /// True when a matching existing transaction was found.
  final bool isDuplicate;

  /// The existing transaction, if [isDuplicate] is true.
  final TxRecord? existing;

  const DuplicateCheckResult.noDuplicate()
      : isDuplicate = false,
        existing = null;
  const DuplicateCheckResult.duplicate(TxRecord this.existing)
      : isDuplicate = true;
}

/// Returns whether [proposed] matches any transaction in [existing] by
/// (date, price, type) — same calendar day, same price, same type.
///
/// NOTE: Excludes DIVIDEND transactions from duplicate check.
DuplicateCheckResult findDuplicateTransaction(
  List<TxRecord> existing,
  TxRecord proposed,
) {
  if (proposed.type.toUpperCase() == 'DIVIDEND') {
    return const DuplicateCheckResult.noDuplicate();
  }

  final proposedDay = _dateOnly(proposed.date);
  for (final tx in existing) {
    if (tx.type.toUpperCase() == 'DIVIDEND') continue;
    if (tx.type == proposed.type &&
        tx.price == proposed.price &&
        _dateOnly(tx.date) == proposedDay) {
      return DuplicateCheckResult.duplicate(tx);
    }
  }
  return const DuplicateCheckResult.noDuplicate();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Gain / Loss helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Overall gain/loss in absolute ₹.
double overallGainLoss({
  required double currentValue,
  required double investedValue,
}) =>
    currentValue - investedValue;

/// Overall gain/loss as a percentage of invested value.
double overallGainLossPercent({
  required double currentValue,
  required double investedValue,
}) {
  if (investedValue == 0) return 0;
  return ((currentValue - investedValue) / investedValue) * 100;
}

/// Day's gain/loss in absolute ₹ given current price and previous close.
double dayGainLoss({
  required int quantityHeld,
  required double currentPrice,
  required double prevClose,
}) =>
    (currentPrice - prevClose) * quantityHeld;

/// Day's gain/loss as a percentage.
double dayGainLossPercent({
  required double currentPrice,
  required double prevClose,
}) {
  if (prevClose == 0) return 0;
  return ((currentPrice - prevClose) / prevClose) * 100;
}

// ─── Private helpers ─────────────────────────────────────────────────────────

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
