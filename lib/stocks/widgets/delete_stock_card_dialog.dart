// lib/stocks/widgets/delete_stock_card_dialog.dart
//
// Confirmation dialog and execution helper for deleting a stock card.

import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../providers/database_provider.dart';

/// Shows the confirmation dialog and deletes the card if confirmed.
///
/// Dialog message:
/// "Delete [TICKER]? This permanently deletes the card and all its [N] transactions. This can't be undone."
///
/// Returns `true` if the card was successfully deleted, `false` otherwise.
Future<bool> confirmAndDeleteStockCard({
  required BuildContext context,
  required StockCard card,
  int? transactionCount,
}) async {
  final dao = AppDbProvider.of(context).stocksDao;
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  int txCount;
  if (transactionCount != null) {
    txCount = transactionCount;
  } else {
    final txs = await dao.getTransactionsForCard(card.id);
    txCount = txs.length;
  }

  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return AlertDialog(
        title: Text('Delete ${card.ticker}?'),
        content: Text(
          'This permanently deletes the card and all its $txCount transactions. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return false;

  try {
    await dao.deleteCardWithAllData(card.id);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('${card.ticker} deleted'),
        duration: const Duration(seconds: 3),
      ),
    );
    return true;
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Failed to delete ${card.ticker}: $e'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
}
