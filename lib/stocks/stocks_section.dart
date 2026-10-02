// lib/stocks/stocks_section.dart
//
// The Stocks section widget that lives inside InvestmentsScreen.
// Manages: loading all cards, showing empty state, list of StockCardTile,
// and the "+ Add Stock" FAB that launches CreateStockCardFlow.

import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../logic/stock_logic.dart';
import '../providers/database_provider.dart';
import 'create_stock_card_flow.dart';
import 'stock_card_detail.dart';
import 'stock_card_tile.dart';
import 'widgets/delete_stock_card_dialog.dart';

class StocksSection extends StatelessWidget {
  const StocksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dao = AppDbProvider.of(context).stocksDao;


    return Scaffold(
      body: StreamBuilder<List<StockCard>>(
        stream: dao.watchAllCards(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cards = snap.data ?? [];

          if (cards.isEmpty) {
            return _EmptyState(
              onAddStock: () => _openCreateFlow(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 100),
            itemCount: cards.length,
            itemBuilder: (_, i) {
              final card = cards[i];
              return FutureBuilder<List<StockTransaction>>(
                future: dao.getTransactionsForCard(card.id),
                builder: (ctx, txSnap) {
                  final txs = (txSnap.data ?? [])
                      .map((t) => TxRecord(
                            id: t.id,
                            type: t.type,
                            date: t.date,
                            price: t.price,
                            quantity: t.quantity,
                            totalAmount: t.totalAmount,
                          ))
                      .toList()
                    ..sort(compareTransactions);

                  return StockCardTile(
                    card: card,
                    transactions: txs,
                    onTap: () => _openDetail(context, card),
                    onLongPress: () => confirmAndDeleteStockCard(
                      context: context,
                      card: card,
                      transactionCount: txs.length,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateFlow(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _openCreateFlow(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AppDbProvider(
          db: AppDbProvider.of(context),
          child: const CreateStockCardFlow(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, StockCard card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppDbProvider(
          db: AppDbProvider.of(context),
          child: StockCardDetail(card: card),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddStock;
  const _EmptyState({required this.onAddStock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.show_chart_rounded, size: 40, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text('No stocks yet',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Add your first stock card to start tracking your portfolio.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAddStock,
              icon: const Icon(Icons.add),
              label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
