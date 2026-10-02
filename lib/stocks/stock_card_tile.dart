// lib/stocks/stock_card_tile.dart
//
// Minimized / list-view tile for a stock card.
// Shows: ticker + exchange, tags, quantity, current value,
// overall gain/loss (₹ and %), day's gain/loss (secondary).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../logic/stock_logic.dart';

class StockCardTile extends StatelessWidget {
  final StockCard card;
  final List<TxRecord> transactions;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const StockCardTile({
    super.key,
    required this.card,
    required this.transactions,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fmt = NumberFormat('#,##,##0.##', 'en_IN');
    final fmtPct = NumberFormat('+0.00;-0.00', 'en_IN');

    final holding = computeHoldingState(transactions);
    final currentPrice = card.lastPrice ?? 0;
    final prevClose = card.prevClose ?? 0;
    final currentValue = currentPrice * holding.quantityHeld;
    final ogl = overallGainLoss(currentValue: currentValue, investedValue: holding.investedValue);
    final oglPct = overallGainLossPercent(currentValue: currentValue, investedValue: holding.investedValue);
    final dgl = dayGainLoss(
        quantityHeld: holding.quantityHeld, currentPrice: currentPrice, prevClose: prevClose);
    final dglPct = dayGainLossPercent(currentPrice: currentPrice, prevClose: prevClose);
    final gainColor = ogl >= 0 ? const Color(0xFF1B8A4C) : cs.error;
    final dayGainColor = dgl >= 0 ? const Color(0xFF1B8A4C) : cs.error;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: ticker, exchange, value ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              card.ticker,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                            const SizedBox(width: 6),
                            _ExBadge(exchange: card.exchange),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.stockName,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentPrice == 0 ? '—' : '₹ ${fmt.format(currentValue)}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${holding.quantityHeld} shares',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Gain / Loss row ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Overall G/L
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                          const SizedBox(height: 2),
                          Text(
                            currentPrice == 0
                                ? '—'
                                : '${ogl >= 0 ? '+' : ''}₹${fmt.format(ogl)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: gainColor,
                                fontSize: 13),
                          ),
                          Text(
                            currentPrice == 0
                                ? ''
                                : '${fmtPct.format(oglPct)}%',
                            style: TextStyle(
                                fontSize: 11,
                                color: gainColor.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    // Separator
                    Container(
                        width: 1, height: 36, color: cs.outlineVariant.withValues(alpha: 0.4)),
                    const SizedBox(width: 12),
                    // Day G/L
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today",
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                          const SizedBox(height: 2),
                          Text(
                            currentPrice == 0 || prevClose == 0
                                ? '—'
                                : '${dgl >= 0 ? '+' : ''}₹${fmt.format(dgl)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: dayGainColor,
                                fontSize: 12),
                          ),
                          Text(
                            currentPrice == 0 || prevClose == 0
                                ? ''
                                : '${fmtPct.format(dglPct)}%',
                            style: TextStyle(
                                fontSize: 11,
                                color: dayGainColor.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExBadge extends StatelessWidget {
  final String exchange;
  const _ExBadge({required this.exchange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        exchange,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
