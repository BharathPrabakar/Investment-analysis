// lib/stocks/stock_card_detail.dart
//
// Enlarged card detail screen.
// Shows: stock info header, tags (editable), properties grid,
// + Add Transaction button, and scrollable transaction history.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_tickers.dart';
import '../database/app_database.dart';
import '../logic/stock_logic.dart';
import '../providers/database_provider.dart';
import '../services/dividend_source.dart';
import '../services/price_service.dart';
import '../utils/app_constants.dart';
import '../widgets/tag_chip.dart';
import 'add_transaction_sheet.dart';
import 'widgets/delete_stock_card_dialog.dart';

class StockCardDetail extends StatefulWidget {
  final StockCard card;

  const StockCardDetail({super.key, required this.card});

  @override
  State<StockCardDetail> createState() => StockCardDetailState();
}

class StockCardDetailState extends State<StockCardDetail> {
  final _fmt = NumberFormat('#,##,##0.##', 'en_IN');
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _timeFmt = DateFormat('hh:mm a, dd MMM');
  bool _refreshingPrice = false;
  Future<void>? _dividendCheckFuture;

  bool _hasStartedDividendCheck = false;

  StockCard get card => widget.card;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStartedDividendCheck) {
      _hasStartedDividendCheck = true;
      _dividendCheckFuture = _doCheckDividends(widget.card);
    }
  }

  /// Automatically fetch and record any eligible dividends in the background.
  Future<void> checkDividends(StockCard currentCard, {bool force = false}) {
    if (force) {
      _hasStartedDividendCheck = true;
      _dividendCheckFuture = _doCheckDividends(currentCard);
    } else {
      _dividendCheckFuture ??= _doCheckDividends(currentCard);
      _hasStartedDividendCheck = true;
    }
    return _dividendCheckFuture!;
  }

  Future<void> _doCheckDividends(StockCard currentCard) async {
    final dao = AppDbProvider.of(context).stocksDao;
    try {
      final allDbTxs = await dao.getTransactionsForCard(currentCard.id);
      
      // Separate user manual transactions (holding transactions) and existing AUTO corporate actions
      final manualHoldingTxs = allDbTxs
          .where((t) => t.type.toUpperCase() != 'DIVIDEND' && t.entryMode.toUpperCase() != 'AUTO')
          .toList();

      // If user has NO manual buy/holding transactions (e.g. they deleted their transactions),
      // all auto-generated dividends and bonuses must be completely purged immediately.
      if (manualHoldingTxs.isEmpty) {
        await dao.deleteAutoTransactionsForCard(currentCard.id);
        return;
      }

      final earliestDate = manualHoldingTxs
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final DateTime earliestDay = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);

      final events = await DividendSource.fetchDividends(
        currentCard.ticker,
        exchange: currentCard.exchange,
      );

      final bonusEvents = await DividendSource.fetchBonusIssues(
        currentCard.ticker,
        exchange: currentCard.exchange,
      );

      // Start with user-entered transactions sorted chronologically
      final txRecords = manualHoldingTxs
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

      // Merge and sort all corporate action event dates ASC
      final allEventDates = <DateTime>{};
      for (final ev in events) {
        allEventDates.add(DateTime(ev.recordDate.year, ev.recordDate.month, ev.recordDate.day));
      }
      for (final b in bonusEvents) {
        allEventDates.add(DateTime(b.recordDate.year, b.recordDate.month, b.recordDate.day));
      }
      final sortedDates = allEventDates.toList()..sort();

      // Track IDs of all auto transactions that remain valid during this full recalculation
      final validAutoTxIds = <int>{};

      for (final curDate in sortedDates) {
        // If event occurred before the earliest manual holding date, any existing auto record is invalid
        if (curDate.isBefore(earliestDay)) {
          continue;
        }

        // 1. Process any Bonus Issues on curDate first
        final bonusesOnDate = bonusEvents.where((b) {
          final bDate = DateTime(b.recordDate.year, b.recordDate.month, b.recordDate.day);
          return bDate.isAtSameMomentAs(curDate);
        }).toList();

        for (final bonus in bonusesOnDate) {
          final txsUpToDate = txRecords.where((t) {
            final tDate = DateTime(t.date.year, t.date.month, t.date.day);
            return !tDate.isAfter(curDate);
          }).toList();

          final holdingAsOf = computeHoldingState(txsUpToDate);
          final existingBonus = await dao.findBonusTransaction(
            cardId: currentCard.id,
            date: bonus.recordDate,
          );

          if (holdingAsOf.quantityHeld > 0 && bonus.existingShares > 0) {
            final newBonusQty = (holdingAsOf.quantityHeld * bonus.bonusShares) ~/ bonus.existingShares;
            if (newBonusQty > 0) {
              int bonusTxId;
              if (existingBonus != null) {
                bonusTxId = existingBonus.id;
                if (existingBonus.quantity != newBonusQty) {
                  await dao.updateTransaction(
                    StockTransactionsCompanion(
                      id: Value(existingBonus.id),
                      cardId: Value(currentCard.id),
                      type: const Value('BONUS'),
                      entryMode: const Value('AUTO'),
                      date: Value(bonus.recordDate),
                      price: const Value(0.0),
                      quantity: Value(newBonusQty),
                      totalAmount: const Value(0.0),
                    ),
                  );
                }
              } else {
                bonusTxId = await dao.insertTransaction(
                  StockTransactionsCompanion.insert(
                    cardId: currentCard.id,
                    type: 'BONUS',
                    entryMode: 'AUTO',
                    date: bonus.recordDate,
                    price: 0.0,
                    quantity: newBonusQty,
                    totalAmount: 0.0,
                  ),
                );
              }
              validAutoTxIds.add(bonusTxId);
              txRecords.add(TxRecord(
                id: bonusTxId,
                type: 'BONUS',
                date: bonus.recordDate,
                price: 0.0,
                quantity: newBonusQty,
                totalAmount: 0.0,
              ));
              txRecords.sort(compareTransactions);
            }
          }
        }

        // 2. Process Dividends on curDate
        final dividendsOnDate = events.where((ev) {
          final evDate = DateTime(ev.recordDate.year, ev.recordDate.month, ev.recordDate.day);
          return evDate.isAtSameMomentAs(curDate);
        }).toList();

        for (final ev in dividendsOnDate) {
          final txsUpToDate = txRecords.where((t) {
            final tDate = DateTime(t.date.year, t.date.month, t.date.day);
            return !tDate.isAfter(curDate);
          }).toList();

          final holdingAsOf = computeHoldingState(txsUpToDate);
          final existingDiv = await dao.findDividendTransaction(
            cardId: currentCard.id,
            date: ev.recordDate,
            price: ev.amountPerShare,
          );

          if (holdingAsOf.quantityHeld > 0) {
            final newPayout = double.parse((holdingAsOf.quantityHeld * ev.amountPerShare).toStringAsFixed(2));
            int divTxId;
            if (existingDiv != null) {
              divTxId = existingDiv.id;
              if (existingDiv.quantity != holdingAsOf.quantityHeld ||
                  (existingDiv.totalAmount - newPayout).abs() > 0.001) {
                await dao.updateTransaction(
                  StockTransactionsCompanion(
                    id: Value(existingDiv.id),
                    cardId: Value(currentCard.id),
                    type: const Value('DIVIDEND'),
                    entryMode: const Value('AUTO'),
                    date: Value(ev.recordDate),
                    price: Value(ev.amountPerShare),
                    quantity: Value(holdingAsOf.quantityHeld),
                    totalAmount: Value(newPayout),
                  ),
                );
              }
            } else {
              divTxId = await dao.insertTransaction(
                StockTransactionsCompanion.insert(
                  cardId: currentCard.id,
                  type: 'DIVIDEND',
                  entryMode: 'AUTO',
                  date: ev.recordDate,
                  price: ev.amountPerShare,
                  quantity: holdingAsOf.quantityHeld,
                  totalAmount: newPayout,
                ),
              );
            }
            validAutoTxIds.add(divTxId);
          }
        }
      }

      // Purge any AUTO transactions currently in the database that are no longer valid
      // (e.g., from deleted transactions, shifted earliest dates, zero holding, etc.)
      final existingAutoTxs = allDbTxs.where((t) => t.entryMode.toUpperCase() == 'AUTO').toList();
      for (final autoTx in existingAutoTxs) {
        if (!validAutoTxIds.contains(autoTx.id)) {
          await dao.deleteTransaction(autoTx.id);
        }
      }

      await dao.updateDividendsFetchedUpto(
        cardId: currentCard.id,
        fetchedUpto: DateTime.now(),
      );
    } catch (_) {
      // Fail silently for background auto-check
    }
  }

  Future<void> _refreshPrice(StockCard currentCard) async {
    setState(() => _refreshingPrice = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dao = AppDbProvider.of(context).stocksDao;
    try {
      final currentPrice = await fetchCurrentPrice(currentCard.ticker, exchange: currentCard.exchange);
      final prevClose = await fetchPreviousClose(currentCard.ticker, exchange: currentCard.exchange);
      final now = DateTime.now();

      await dao.updateCardPrice(
        cardId: currentCard.id,
        lastPrice: currentPrice,
        prevClose: prevClose,
        fetchedAt: now,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Price updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Price refresh failed: $e. Kept cached price.')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingPrice = false);
    }
  }

  Future<void> _openAddTransaction() async {
    final db = AppDbProvider.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AppDbProvider(
        db: db,
        child: AddTransactionSheet(
          cardId: card.id,
          ticker: card.ticker,
          exchange: card.exchange,
        ),
      ),
    );
    if (result == true && mounted) {
      await checkDividends(card, force: true);
    }
  }

  Future<void> _tryDeleteTransaction(
      StockTransaction tx, List<StockTransaction> all) async {
    final dao = AppDbProvider.of(context).stocksDao;

    // Convert to TxRecord list for validation
    final records = all
        .map((t) => TxRecord(
              id: t.id,
              type: t.type,
              date: t.date,
              price: t.price,
              quantity: t.quantity,
              totalAmount: t.totalAmount,
            ))
        .toList();

    final validation = validateQuantityNeverNegative(
      records,
      ProposedOp.delete(tx.id),
    );

    if (!validation.isValid) {
      final conflicting = validation.conflictingTransaction;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              conflicting != null
                  ? 'Cannot delete: a ${conflicting.type} of ${conflicting.quantity} shares'
                    ' on ${_dateFmt.format(conflicting.date)} depends on this transaction.'
                  : 'Cannot delete: would make quantity negative.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('This transaction will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dao.deleteTransaction(tx.id);
      if (mounted) {
        await checkDividends(card, force: true);
      }
    }
  }

  Future<void> _editTransaction(StockTransaction tx) async {
    final db = AppDbProvider.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AppDbProvider(
        db: db,
        child: AddTransactionSheet(
          cardId: card.id,
          ticker: card.ticker,
          exchange: card.exchange,
          existingTx: tx,
        ),
      ),
    );
    if (result == true && mounted) {
      await checkDividends(card, force: true);
    }
  }

  Future<void> _showAddTagDialog(BuildContext context, List<Tag> currentTags) async {
    final dao = AppDbProvider.of(context).stocksDao;
    final allTags = await dao.getAllTags();
    final currentTagIds = currentTags.map((t) => t.id).toSet();
    final availableExistingTags =
        allTags.where((t) => !currentTagIds.contains(t.id)).toList();

    if (!context.mounted) return;

    final controller = TextEditingController();
    String? inlineError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;

          Future<void> submitTag(String name) async {
            final trimmed = name.trim();
            if (trimmed.isEmpty) {
              setDialogState(() => inlineError = 'Tag name cannot be empty');
              return;
            }
            if (trimmed.length > kMaxTagLength) {
              setDialogState(
                  () => inlineError = 'Tag name cannot exceed $kMaxTagLength characters');
              return;
            }
            if (currentTags.any(
                (t) => t.name.trim().toLowerCase() == trimmed.toLowerCase())) {
              setDialogState(
                  () => inlineError = 'Tag is already added to this card');
              return;
            }

            try {
              await dao.addTagToCard(card.id, 'stock', trimmed);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            } catch (e) {
              setDialogState(() => inlineError = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').replaceAll('ArgumentError: ', ''));
            }
          }

          return AlertDialog(
            title: const Text('Add Tag'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: kMaxTagLength,
                    decoration: InputDecoration(
                      labelText: 'New tag name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      errorText: inlineError,
                    ),
                    onSubmitted: (val) => submitTag(val),
                  ),
                  if (availableExistingTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Or pick existing tag:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableExistingTags.map((tag) {
                        return ActionChip(
                          label: Text(tag.name),
                          onPressed: () => submitTag(tag.name),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => submitTag(controller.text),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeTag(Tag tag) async {
    final dao = AppDbProvider.of(context).stocksDao;
    await dao.removeTagFromCard(card.id, 'stock', tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDbProvider.of(context);
    final dao = db.stocksDao;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${card.ticker} · ${card.exchange}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: _refreshingPrice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh live price',
            onPressed: _refreshingPrice ? null : () => _refreshPrice(card),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete') {
                final deleted = await confirmAndDeleteStockCard(
                  context: context,
                  card: card,
                );
                if (deleted && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Theme.of(ctx).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete card',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<StockCard?>(
        stream: dao.watchCardById(card.id),
        initialData: card,
        builder: (context, cardSnap) {
          final liveCard = cardSnap.data ?? card;

          return StreamBuilder<List<StockTransaction>>(
            stream: dao.watchTransactionsForCard(liveCard.id),
            builder: (context, txSnap) {
          final transactions = txSnap.data ?? [];

          final records = transactions
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

          final holding = computeHoldingState(records);
          final currentPrice = liveCard.lastPrice ?? 0;
          final prevClose = liveCard.prevClose ?? 0;
          final currentValue = currentPrice * holding.quantityHeld;
          final ogl = overallGainLoss(currentValue: currentValue, investedValue: holding.investedValue);
          final oglPct = overallGainLossPercent(currentValue: currentValue, investedValue: holding.investedValue);
          final dgl = dayGainLoss(quantityHeld: holding.quantityHeld, currentPrice: currentPrice, prevClose: prevClose);
          final dglPct = dayGainLossPercent(currentPrice: currentPrice, prevClose: prevClose);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ───────────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(liveCard.stockName,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          _ExchangeBadge(exchange: liveCard.exchange),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final info = getTickerInfoBySymbolSync(liveCard.ticker, exchange: liveCard.exchange);
                        final parts = <String>['Ticker: ${liveCard.ticker}'];
                        if (info?.scripCode != null && info!.scripCode!.isNotEmpty) {
                          parts.add('Code: ${info.scripCode}');
                        }
                        final isin = info?.isin ?? getIsinForSymbolSync(liveCard.ticker, exchange: liveCard.exchange);
                        if (isin != null && isin.isNotEmpty) {
                          parts.add('ISIN: $isin');
                        }
                        return Text(
                          parts.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // ── Tags Section ─────────────────────────────────────────
                      StreamBuilder<List<Tag>>(
                        stream: dao.watchTagsForCard(liveCard.id, 'stock'),
                        initialData: const [],
                        builder: (ctx, tagSnap) {
                          final tags = tagSnap.data ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...tags.map((t) => TagChip(
                                        label: t.name,
                                        onDeleted: () => _removeTag(t),
                                      )),
                                  ActionChip(
                                    avatar: const Icon(Icons.add, size: 16),
                                    label: const Text('+ Add tag'),
                                    onPressed: () =>
                                        _showAddTagDialog(context, tags),
                                  ),
                                ],
                              ),
                              if (tags.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'No tags yet - tap + to add one',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.55),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Properties grid ─────────────────────────────────────
                      _PropertiesGrid(
                        holding: holding,
                        currentPrice: currentPrice,
                        currentValue: currentValue,
                        ogl: ogl,
                        oglPct: oglPct,
                        dgl: dgl,
                        dglPct: dglPct,
                        totalDividend: totalDividendEarned(records),
                        lastFetchedAt: liveCard.lastPriceFetchedAt,
                        fmt: _fmt,
                        timeFmt: _timeFmt,
                      ),
                      const SizedBox(height: 20),

                      // ── Add transaction button ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openAddTransaction,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Transaction'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Transaction History',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Transaction list (desc order, already from stream) ─────────
              transactions.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('No transactions yet.',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final tx = transactions[i];
                          return _TransactionRow(
                            tx: tx,
                            fmt: _fmt,
                            dateFmt: _dateFmt,
                            onDelete: () => _tryDeleteTransaction(tx, transactions),
                            onEdit: () => _editTransaction(tx),
                          );
                        },
                        childCount: transactions.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Properties grid ─────────────────────────────────────────────────────────

class _PropertiesGrid extends StatelessWidget {
  final HoldingState holding;
  final double currentPrice;
  final double currentValue;
  final double ogl;
  final double oglPct;
  final double dgl;
  final double dglPct;
  final double totalDividend;
  final DateTime? lastFetchedAt;
  final NumberFormat fmt;
  final DateFormat timeFmt;

  const _PropertiesGrid({
    required this.holding,
    required this.currentPrice,
    required this.currentValue,
    required this.ogl,
    required this.oglPct,
    required this.dgl,
    required this.dglPct,
    required this.totalDividend,
    required this.lastFetchedAt,
    required this.fmt,
    required this.timeFmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmtPct = NumberFormat('+0.00;-0.00', 'en_IN');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PropRow(label: 'Quantity Held', value: holding.quantityHeld.toString()),
          _PropRow(label: 'Avg Buy Price', value: currentPrice == 0 ? '—' : '₹ ${fmt.format(holding.avgBuyPrice)}'),
          _PropRow(label: 'Invested Value', value: '₹ ${fmt.format(holding.investedValue)}'),
          _PropRow(label: 'Current Price', value: currentPrice == 0 ? '—' : '₹ ${fmt.format(currentPrice)}'),
          _PropRow(label: 'Current Value', value: currentPrice == 0 ? '—' : '₹ ${fmt.format(currentValue)}'),
          _PropRow(
            label: 'Overall Gain/Loss',
            value: currentPrice == 0
                ? '—'
                : '₹ ${fmt.format(ogl)}  (${fmtPct.format(oglPct)}%)',
            valueColor: ogl >= 0 ? const Color(0xFF1B8A4C) : cs.error,
          ),
          _PropRow(
            label: "Day's Gain/Loss",
            value: currentPrice == 0
                ? '—'
                : '₹ ${fmt.format(dgl)}  (${fmtPct.format(dglPct)}%)',
            valueColor: dgl >= 0 ? const Color(0xFF1B8A4C) : cs.error,
          ),
          _PropRow(
            label: 'Dividend Earned (till date)',
            value: '₹ ${fmt.format(totalDividend)}',
            valueColor: totalDividend > 0 ? const Color(0xFF1B8A4C) : null,
            isLast: lastFetchedAt == null,
          ),
          if (lastFetchedAt != null)
            _PropRow(
              label: 'Price Fetched At',
              value: timeFmt.format(lastFetchedAt!.toLocal()),
              isLast: true,
            ),
        ],
      ),
    );
  }
}

class _PropRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _PropRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ),
              Text(value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor)),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
      ],
    );
  }
}

// ─── Transaction row ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final StockTransaction tx;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionRow({
    required this.tx,
    required this.fmt,
    required this.dateFmt,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDividend = tx.type.toUpperCase() == 'DIVIDEND';
    final isBuy = tx.type.toUpperCase() == 'BUY';
    final isAvg = tx.entryMode.toUpperCase() == 'AVG';

    if (isDividend) {
      // Read-only DIVIDEND row: no Dismissible, no edit or delete controls
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.withValues(alpha: 0.2),
          child: const Icon(
            Icons.payments_outlined,
            color: Color(0xFFB78103),
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'DIVIDEND',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Color(0xFF946200),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateFmt.format(tx.date),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '₹${fmt.format(tx.price)}/share · ${tx.quantity} shares held',
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Text(
          '+ ₹${fmt.format(tx.totalAmount)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B8A4C),
          ),
        ),
      );
    }

    final isBonus = tx.type.toUpperCase() == 'BONUS';
    if (isBonus) {
      return Dismissible(
        key: Key('tx_${tx.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: cs.errorContainer,
          child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
        ),
        confirmDismiss: (_) async {
          onDelete();
          return false;
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.withValues(alpha: 0.15),
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.purple,
              size: 18,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BONUS ISSUE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.purple,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateFmt.format(tx.date),
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '+${tx.quantity} bonus shares credited · ₹0 cost basis',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
            tooltip: 'Remove bonus entry',
            onPressed: onDelete,
          ),
        ),
      );
    }

    return Dismissible(
      key: Key('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: cs.errorContainer,
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle delete ourselves
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isBuy ? const Color(0xFF1B8A4C).withValues(alpha: 0.15) : cs.errorContainer,
          child: Icon(
            isBuy ? Icons.trending_up : Icons.trending_down,
            color: isBuy ? const Color(0xFF1B8A4C) : cs.error,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Text(
              tx.type,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isBuy ? const Color(0xFF1B8A4C) : cs.error,
              ),
            ),
            const SizedBox(width: 8),
            if (isAvg)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('avg entry',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(
          isAvg ? '(avg entry) · ${tx.quantity} shares @ ₹${fmt.format(tx.price)}'
              : '${dateFmt.format(tx.date)} · ${tx.quantity} shares @ ₹${fmt.format(tx.price)}',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exchange badge ───────────────────────────────────────────────────────────

class _ExchangeBadge extends StatelessWidget {
  final String exchange;
  const _ExchangeBadge({required this.exchange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exchange,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
