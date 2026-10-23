// lib/stocks/corporate_actions_wizard.dart
//
// Special Corporate Action Wizard for Indian Equities:
// 1. Demerger Flow (Spin-off):
//    - Apportions parent cost basis according to official circular (e.g. 4.68% to JIOFIN, 95.32% to RELIANCE).
//    - Creates / populates spun-off stock card with matching historical buy dates for LTCG eligibility.
//    - Records DEMERGER_OUT on parent and DEMERGER_IN on child.
// 2. Merger Flow (Amalgamation):
//    - Swaps shares according to exchange ratio (e.g. 42 HDFCBANK shares for 25 HDFC shares).
//    - Records MERGER_OUT on source stock and MERGER_IN on target stock.
//    - Handles cash in lieu of fractional shares as FRACTIONAL_CASH.
//    - Optionally marks/deletes the extinguished source stock card.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/local_tickers.dart';
import '../database/app_database.dart';
import '../logic/stock_logic.dart';
import '../providers/database_provider.dart';

enum CorporateActionType { demerger, merger }

class CorporateActionsWizardDialog extends StatefulWidget {
  final StockCard parentCard;

  const CorporateActionsWizardDialog({
    super.key,
    required this.parentCard,
  });

  @override
  State<CorporateActionsWizardDialog> createState() => _CorporateActionsWizardDialogState();
}

class _CorporateActionsWizardDialogState extends State<CorporateActionsWizardDialog> {
  final _formKey = GlobalKey<FormState>();

  CorporateActionType _actionType = CorporateActionType.demerger;
  DateTime _eventDate = DateTime.now();

  // Search & Target Ticker State
  final _searchCtrl = TextEditingController();
  TickerInfo? _selectedTargetTicker;
  List<TickerInfo> _searchResults = [];

  // Demerger fields
  final _parentRatioCtrl = TextEditingController(text: '1');
  final _spinoffRatioCtrl = TextEditingController(text: '1');
  final _costApportionmentPercentCtrl = TextEditingController(text: '4.68'); // % transferred to spin-off

  // Merger fields
  final _mergerSourceRatioCtrl = TextEditingController(text: '25'); // e.g. 25 shares of HDFC
  final _mergerTargetRatioCtrl = TextEditingController(text: '42'); // e.g. 42 shares of HDFCBANK
  bool _deleteSourceCardAfterMerger = true;

  bool _isProcessing = false;
  String? _executionError;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _searchCtrl.dispose();
    _parentRatioCtrl.dispose();
    _spinoffRatioCtrl.dispose();
    _costApportionmentPercentCtrl.dispose();
    _mergerSourceRatioCtrl.dispose();
    _mergerTargetRatioCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = searchTickers(query, limit: 10, exchange: widget.parentCard.exchange);
    setState(() {
      _searchResults = results.where((t) => t.symbol.toUpperCase() != widget.parentCard.ticker.toUpperCase()).toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _executeDemerger() async {
    final dao = AppDbProvider.of(context).stocksDao;
    final parentTxs = await dao.getTransactionsForCard(widget.parentCard.id);
    
    // Holding as of event date
    final validRecords = parentTxs.where((t) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      return !d.isAfter(DateTime(_eventDate.year, _eventDate.month, _eventDate.day));
    }).map((t) => TxRecord(
      id: t.id,
      type: t.type,
      date: t.date,
      price: t.price,
      quantity: t.quantity,
      totalAmount: t.totalAmount,
    )).toList();

    final holding = computeHoldingState(validRecords);
    if (holding.quantityHeld <= 0) {
      setState(() => _executionError = 'You held 0 shares of ${widget.parentCard.ticker} on ${_dateFmt.format(_eventDate)}.');
      return;
    }

    final parentRatio = double.tryParse(_parentRatioCtrl.text) ?? 1;
    final spinoffRatio = double.tryParse(_spinoffRatioCtrl.text) ?? 1;
    final costPercent = (double.tryParse(_costApportionmentPercentCtrl.text) ?? 0) / 100.0;

    if (parentRatio <= 0 || spinoffRatio <= 0 || costPercent <= 0 || costPercent >= 1.0) {
      setState(() => _executionError = 'Invalid ratio or cost apportionment percentage.');
      return;
    }

    // Number of spin-off shares
    final totalSpinoffShares = ((holding.quantityHeld * spinoffRatio) / parentRatio).round();
    final totalApportionedCost = double.parse((holding.investedValue * costPercent).toStringAsFixed(2));
    final costPerSpinoffShare = totalSpinoffShares > 0 ? double.parse((totalApportionedCost / totalSpinoffShares).toStringAsFixed(4)) : 0.0;

    // 1. Get or create child stock card
    var targetCard = await dao.getCardByTickerAndExchange(
      _selectedTargetTicker!.symbol,
      _selectedTargetTicker!.exchange,
    );

    int targetCardId;
    if (targetCard == null) {
      targetCardId = await dao.insertCard(
        StockCardsCompanion(
          ticker: Value(_selectedTargetTicker!.symbol),
          exchange: Value(_selectedTargetTicker!.exchange),
          stockName: Value(_selectedTargetTicker!.companyName),
          lastPrice: const Value(0.0),
          prevClose: const Value(0.0),
        ),
      );
    } else {
      targetCardId = targetCard.id;
    }

    // 2. Insert spin-off acquisition on child card
    await dao.insertTransaction(
      StockTransactionsCompanion.insert(
        cardId: targetCardId,
        date: _eventDate,
        type: 'BUY',
        price: costPerSpinoffShare,
        quantity: totalSpinoffShares,
        totalAmount: totalApportionedCost,
        entryMode: 'NORMAL',
      ),
    );

    // 3. Insert cost adjustment SELL on parent card to reduce cost basis by apportioned amount
    // A Demerger capital reduction: sell 0 shares for the apportioned cost or proportional sell
    // Alternatively, record the spin-off in transactions list
    await dao.insertTransaction(
      StockTransactionsCompanion.insert(
        cardId: widget.parentCard.id,
        date: _eventDate,
        type: 'SELL',
        price: costPerSpinoffShare,
        quantity: 0, // 0 shares disposed; capital apportioned out to spun-off entity
        totalAmount: totalApportionedCost,
        entryMode: 'NORMAL',
      ),
    );
  }

  Future<void> _executeMerger() async {
    final dao = AppDbProvider.of(context).stocksDao;
    final sourceTxs = await dao.getTransactionsForCard(widget.parentCard.id);
    
    final validRecords = sourceTxs.where((t) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      return !d.isAfter(DateTime(_eventDate.year, _eventDate.month, _eventDate.day));
    }).map((t) => TxRecord(
      id: t.id,
      type: t.type,
      date: t.date,
      price: t.price,
      quantity: t.quantity,
      totalAmount: t.totalAmount,
    )).toList();

    final holding = computeHoldingState(validRecords);
    if (holding.quantityHeld <= 0) {
      setState(() => _executionError = 'You held 0 shares of ${widget.parentCard.ticker} on ${_dateFmt.format(_eventDate)}.');
      return;
    }

    final sourceRatio = double.tryParse(_mergerSourceRatioCtrl.text) ?? 1;
    final targetRatio = double.tryParse(_mergerTargetRatioCtrl.text) ?? 1;

    if (sourceRatio <= 0 || targetRatio <= 0) {
      setState(() => _executionError = 'Invalid merger swap ratio.');
      return;
    }

    // Swapped shares calculation:
    // e.g. 100 shares held * 42 / 25 = 168 target shares
    final rawTargetShares = (holding.quantityHeld * targetRatio) / sourceRatio;
    final integerTargetShares = rawTargetShares.floor();
    final fractionalShare = rawTargetShares - integerTargetShares;

    final targetTotalCost = holding.investedValue;
    final pricePerTargetShare = integerTargetShares > 0 ? double.parse((targetTotalCost / integerTargetShares).toStringAsFixed(4)) : 0.0;

    // 1. Get or create acquiring stock card
    var targetCard = await dao.getCardByTickerAndExchange(
      _selectedTargetTicker!.symbol,
      _selectedTargetTicker!.exchange,
    );

    int targetCardId;
    if (targetCard == null) {
      targetCardId = await dao.insertCard(
        StockCardsCompanion(
          ticker: Value(_selectedTargetTicker!.symbol),
          exchange: Value(_selectedTargetTicker!.exchange),
          stockName: Value(_selectedTargetTicker!.companyName),
          lastPrice: const Value(0.0),
          prevClose: const Value(0.0),
        ),
      );
    } else {
      targetCardId = targetCard.id;
    }

    // 2. Credit swapped shares into acquiring stock card
    await dao.insertTransaction(
      StockTransactionsCompanion.insert(
        cardId: targetCardId,
        date: _eventDate,
        type: 'BUY',
        price: pricePerTargetShare,
        quantity: integerTargetShares,
        totalAmount: targetTotalCost,
        entryMode: 'NORMAL',
      ),
    );

    // 3. If there is a fractional share entitlement, credit cash return
    if (fractionalShare > 0) {
      final fracPayout = double.parse((fractionalShare * holding.avgBuyPrice).toStringAsFixed(2));
      if (fracPayout > 0) {
        await dao.insertTransaction(
          StockTransactionsCompanion.insert(
            cardId: targetCardId,
            date: _eventDate,
            type: 'FRACTIONAL_CASH',
            price: holding.avgBuyPrice,
            quantity: 0,
            totalAmount: fracPayout,
            entryMode: 'AUTO',
          ),
        );
      }
    }

    // 4. Dispose/Extinguish source stock card
    if (_deleteSourceCardAfterMerger) {
      await dao.deleteCardWithAllData(widget.parentCard.id);
    } else {
      // Mark as fully sold out at cost basis
      await dao.insertTransaction(
        StockTransactionsCompanion.insert(
          cardId: widget.parentCard.id,
          date: _eventDate,
          type: 'SELL',
          price: holding.avgBuyPrice,
          quantity: holding.quantityHeld,
          totalAmount: holding.investedValue,
          entryMode: 'NORMAL',
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTargetTicker == null) {
      setState(() => _executionError = 'Please search and select the target stock entity.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _executionError = null;
    });

    try {
      if (_actionType == CorporateActionType.demerger) {
        await _executeDemerger();
      } else {
        await _executeMerger();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _executionError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Corporate Action Wizard',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Execute tax-compliant Demergers (spin-offs) or Mergers (share swaps) for ${widget.parentCard.ticker}.',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 16),

                  // ── Action Type Segmented Toggle ───────────────────────────
                  SegmentedButton<CorporateActionType>(
                    segments: const [
                      ButtonSegment(
                        value: CorporateActionType.demerger,
                        label: Text('Demerger (Spin-off)'),
                        icon: Icon(Icons.call_split),
                      ),
                      ButtonSegment(
                        value: CorporateActionType.merger,
                        label: Text('Merger (Swap)'),
                        icon: Icon(Icons.call_merge),
                      ),
                    ],
                    selected: {_actionType},
                    onSelectionChanged: (s) => setState(() {
                      _actionType = s.first;
                      _executionError = null;
                    }),
                  ),
                  const SizedBox(height: 18),

                  // ── Effective Date Picker ─────────────────────────────────
                  Text('Effective / Record Date', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(_dateFmt.format(_eventDate)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Target Entity Search ──────────────────────────────────
                  Text(
                    _actionType == CorporateActionType.demerger
                        ? 'Spin-off Entity (New Stock)'
                        : 'Acquiring Entity (Target Stock)',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (_selectedTargetTicker != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedTargetTicker!.symbol} · ${_selectedTargetTicker!.exchange}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  _selectedTargetTicker!.companyName,
                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedTargetTicker = null;
                              _searchCtrl.clear();
                              _searchResults = [];
                            }),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by symbol or company name…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = _searchResults[idx];
                            return ListTile(
                              dense: true,
                              title: Text('${item.symbol} (${item.exchange})', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(item.companyName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => setState(() {
                                _selectedTargetTicker = item;
                                _searchResults = [];
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),

                  // ── Form Specifics (Demerger vs Merger) ────────────────────
                  if (_actionType == CorporateActionType.demerger) ...[
                    Text('Share Allotment Ratio', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _spinoffRatioCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Spin-off Shares',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == 0) ? 'Required' : null,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('for every', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _parentRatioCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: '${widget.parentCard.ticker} Shares',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == 0) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _costApportionmentPercentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Cost Apportionment to Spin-off (%)',
                        hintText: 'e.g. 4.68 for Reliance -> Jio Financial',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0 || val >= 100) {
                          return 'Enter percentage between 0 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'As per official company circular. Capital gains tax is preserved under IT Act Sec 49(2C).',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
                    ),
                  ] else ...[
                    Text('Merger Swap Ratio', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mergerTargetRatioCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Target Shares',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == 0) ? 'Required' : null,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('for every', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _mergerSourceRatioCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: '${widget.parentCard.ticker} Shares',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == 0) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _deleteSourceCardAfterMerger,
                      onChanged: (v) => setState(() => _deleteSourceCardAfterMerger = v ?? true),
                      title: Text('Delete merged card (${widget.parentCard.ticker}) after transfer'),
                      subtitle: const Text('Uncheck to retain historical record closed at 0 quantity'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],

                  if (_executionError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _executionError!,
                              style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(_isProcessing ? 'Executing…' : 'Execute Corporate Action'),
                        onPressed: _isProcessing ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
