// lib/stocks/add_transaction_sheet.dart
//
// Bottom sheet for adding a new stock transaction.
// Handles: buy/sell toggle, normal/avg mode, date picker, price fetch (stubbed),
// quantity, duplicate check, quantity-never-negative validation.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../logic/stock_logic.dart';
import '../providers/database_provider.dart';
import '../services/price_service.dart';
import '../services/trading_day_service.dart';

class AddTransactionSheet extends StatefulWidget {
  final int cardId;
  final String ticker;
  final String exchange;
  final String? isin;

  /// If non-null, the sheet is pre-filled for editing (delete+re-add flow).
  final StockTransaction? existingTx;

  const AddTransactionSheet({
    super.key,
    required this.cardId,
    required this.ticker,
    this.exchange = 'NSE',
    this.isin,
    this.existingTx,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  String _type = 'BUY';
  String _entryMode = 'NORMAL';
  DateTime _date = DateTime.now();

  // Calendar validation state
  bool _checkingCalendar = false;
  TradingDayStatus? _calendarStatus;
  String? _calendarError;
  int _calendarRequestId = 0;

  // Price range fetch state
  PriceRange? _priceRange;
  bool _fetchingRange = false;
  String? _fetchError;
  bool _isMarketNotOpen = false;
  int _rangeRequestId = 0;

  // Total amount display
  double _totalAmount = 0;

  // Inline sell-validation error shown below the Quantity field.
  String? _sellValidationError;

  final _fmt = NumberFormat('#,##,##0.##', 'en_IN');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTx;
    if (tx != null) {
      _type = tx.type;
      _entryMode = tx.entryMode;
      _date = tx.date;
      _priceCtrl.text = tx.price.toStringAsFixed(2);
      _qtyCtrl.text = tx.quantity.toString();
      _totalAmount = tx.totalAmount;
    }
    _priceCtrl.addListener(_recalcTotal);
    _qtyCtrl.addListener(_recalcTotal);

    _validateDateAndLoadRange(_date);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    final q = int.tryParse(_qtyCtrl.text) ?? 0;
    // Clear sell validation error as soon as the user edits the quantity.
    setState(() {
      _totalAmount = p * q;
      _sellValidationError = null;
    });
  }

  Future<void> _validateDateAndLoadRange(DateTime targetDate) async {
    final curRequestId = ++_calendarRequestId;
    setState(() {
      _checkingCalendar = true;
      _calendarStatus = null;
      _calendarError = null;
      _priceRange = null;
      _fetchError = null;
      _isMarketNotOpen = false;
    });

    final res = await TradingDayService.instance.checkTradingDayDetailed(targetDate);
    if (!mounted || curRequestId != _calendarRequestId || _date != targetDate) {
      return;
    }

    setState(() {
      _checkingCalendar = false;
      _calendarStatus = res.status;
      if (res.status == TradingDayStatus.closed) {
        _calendarError =
            'Markets were closed on ${_dateFmt.format(targetDate)} (weekend/holiday) — please pick a trading day.';
      } else if (res.status == TradingDayStatus.unknown) {
        _calendarError = res.message ?? "Couldn't verify the market calendar — please retry";
      } else {
        _calendarError = null;
      }
    });

    if (res.status == TradingDayStatus.open && _entryMode == 'NORMAL') {
      _fetchPriceRange();
    }
  }

  Future<void> _fetchPriceRange() async {
    final curDate = _date;
    // NORMAL mode requires traded market high/low price range.
    // AVG, RIGHTS (corporate discounted entitlement), and BUYBACK (fixed tender offer) bypass secondary market day range.
    if (_entryMode != 'NORMAL' || _calendarStatus != TradingDayStatus.open) {
      setState(() {
        _priceRange = null;
        _fetchingRange = false;
        _fetchError = null;
        _isMarketNotOpen = false;
      });
      return;
    }

    final requestId = ++_rangeRequestId;
    setState(() {
      _fetchingRange = true;
      _fetchError = null;
      _isMarketNotOpen = false;
      _priceRange = null;
    });

    try {
      final range = await fetchDayPriceRange(
        widget.ticker,
        curDate,
        exchange: widget.exchange,
        isin: widget.isin,
      );
      if (!mounted || requestId != _rangeRequestId || _entryMode != 'NORMAL' || _date != curDate) {
        return;
      }
      setState(() {
        _priceRange = range;
        _fetchError = null;
        _isMarketNotOpen = false;
      });
    } on MarketNotOpenException catch (e) {
      if (!mounted || requestId != _rangeRequestId || _entryMode != 'NORMAL' || _date != curDate) {
        return;
      }
      setState(() {
        _isMarketNotOpen = true;
        _fetchError = e.message;
        _priceRange = null;
      });
    } catch (e) {
      if (!mounted || requestId != _rangeRequestId || _entryMode != 'NORMAL' || _date != curDate) {
        return;
      }
      setState(() {
        _isMarketNotOpen = false;
        _fetchError = e.toString();
        _priceRange = null;
      });
    } finally {
      if (mounted && requestId == _rangeRequestId) {
        setState(() => _fetchingRange = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
    _validateDateAndLoadRange(picked);
  }

  Future<void> _submit() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final db = AppDbProvider.of(context);
    final dao = db.stocksDao;

    // 1. Check/re-verify calendar status
    if (_checkingCalendar) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Checking market calendar, please wait...')),
      );
      return;
    }

    final status = await TradingDayService.instance.checkTradingDay(_date);
    if (!mounted) return;
    if (status != TradingDayStatus.open) {
      setState(() {
        _calendarStatus = status;
        if (status == TradingDayStatus.closed) {
          _calendarError =
              'Markets were closed on ${_dateFmt.format(_date)} (weekend/holiday) — please pick a trading day.';
        } else {
          _calendarError = "Couldn't verify the market calendar — please retry";
        }
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // In NORMAL mode, block unless a range was successfully fetched for the currently selected date.
    // If date is today, re-fetch live at submit time to ensure fresh high/low.
    if (_entryMode == 'NORMAL') {
      if (isTodayIst(_date)) {
        setState(() => _fetchingRange = true);
        try {
          final freshRange = await fetchDayPriceRange(
            widget.ticker,
            _date,
            exchange: widget.exchange,
            isin: widget.isin,
          );
          if (mounted) {
            setState(() {
              _priceRange = freshRange;
              _fetchError = null;
              _isMarketNotOpen = false;
              _fetchingRange = false;
            });
          }
        } on MarketNotOpenException catch (e) {
          if (mounted) {
            setState(() {
              _isMarketNotOpen = true;
              _fetchError = e.message;
              _priceRange = null;
              _fetchingRange = false;
            });
          }
          return;
        } catch (e) {
          if (mounted) {
            setState(() {
              _isMarketNotOpen = false;
              _fetchError = e.toString();
              _priceRange = null;
              _fetchingRange = false;
            });
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text("Couldn't fetch fresh price data — please retry.")),
            );
          }
          return;
        }
      }

      if (_fetchingRange) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please wait while price data is being fetched.')),
        );
        return;
      }
      if (_fetchError != null || _priceRange == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please fetch the price range before submitting.')),
        );
        return;
      }

      final enteredPrice = double.tryParse(_priceCtrl.text);
      if (enteredPrice == null || !_priceRange!.containsPrice(enteredPrice)) {
        _formKey.currentState!.validate();
        return;
      }
    }

    final price = double.parse(_priceCtrl.text);
    final qty = int.parse(_qtyCtrl.text);
    final total = price * qty;

    // Load existing transactions for validation and duplicate checking
    final existingTxs = await dao.getTransactionsForCard(widget.cardId);
    final allRecords = existingTxs
        .map((t) => TxRecord(
              id: t.id,
              type: t.type,
              date: t.date,
              price: t.price,
              quantity: t.quantity,
              totalAmount: t.totalAmount,
            ))
        .toList();

    final isEdit = widget.existingTx != null;
    final proposed = TxRecord(
      id: isEdit ? widget.existingTx!.id : 0,
      type: _type,
      date: _date,
      price: price,
      quantity: qty,
      totalAmount: total,
    );

    // Full-sequence replay validation:
    // When editing, replay with the edited transaction replaced in place (ProposedOp.edit).
    // When adding a SELL, validate that quantity never goes negative (ProposedOp.add).
    // (For adding a BUY, quantity cannot go negative).
    final op = isEdit
        ? ProposedOp.edit(targetId: widget.existingTx!.id, record: proposed)
        : ProposedOp.add(proposed);

    final validation = validateQuantityNeverNegative(allRecords, op);
    if (!validation.isValid) {
      if (mounted) {
        final conflicting = validation.conflictingTransaction;
        if (conflicting != null && conflicting.id != proposed.id) {
          setState(() {
            _sellValidationError =
                'Cannot save: a ${conflicting.type} of ${conflicting.quantity} share${conflicting.quantity == 1 ? '' : 's'} '
                'on ${_dateFmt.format(conflicting.date)} depends on this holding.';
          });
        } else {
          final sellDateOnly = DateTime(_date.year, _date.month, _date.day);
          final recordsUpToDate = (isEdit
                  ? allRecords.where((r) => r.id != widget.existingTx!.id)
                  : allRecords)
              .where((r) {
            final d = DateTime(r.date.year, r.date.month, r.date.day);
            return !d.isAfter(sellDateOnly);
          }).toList();
          final heldQty = computeHoldingState(recordsUpToDate).quantityHeld;
          setState(() {
            _sellValidationError =
                'You held $heldQty share${heldQty == 1 ? '' : 's'} '
                'as of ${_dateFmt.format(_date)} \u2014 can\'t sell $qty.';
          });
        }
      }
      return;
    }

    // Duplicate check:
    // Exclude the transaction being edited from duplicate check.
    // Changing only the quantity must NOT trigger a merge prompt against itself.
    final candidateRecordsForDup = isEdit
        ? allRecords.where((t) => t.id != widget.existingTx!.id).toList()
        : allRecords;

    final dupCheck = findDuplicateTransaction(
      candidateRecordsForDup,
      proposed,
    );

    if (dupCheck.isDuplicate && mounted) {
      final existing = dupCheck.existing!;
      final newQty = existing.quantity + qty;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Transaction'),
          content: Text(
            'A $_type transaction on ${_dateFmt.format(_date)} at '
            '₹${_fmt.format(price)} already exists.\n\n'
            'This entry will be added to it (new quantity: $newQty). '
            'Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      if (isEdit) {
        // Atomic merge into other transaction and remove the edited one
        await dao.editTransaction(
          updatedTx: StockTransactionsCompanion(
            id: Value(widget.existingTx!.id),
            cardId: Value(widget.cardId),
            type: Value(_type),
            entryMode: Value(_entryMode),
            date: Value(_date),
            price: Value(price),
            quantity: Value(qty),
            totalAmount: Value(total),
          ),
          mergeIntoTxId: existing.id,
          deleteTxIdOnMerge: widget.existingTx!.id,
          additionalQuantityOnMerge: qty,
          additionalAmountOnMerge: total,
        );
      } else {
        // Merge into existing
        await dao.mergeIntoExistingTransaction(
          txId: existing.id,
          additionalQuantity: qty,
          additionalAmount: total,
        );
      }
      if (mounted) Navigator.pop(context, true);
      return;
    }

    if (isEdit) {
      // Update in place preserving original id in a single DB transaction
      await dao.editTransaction(
        updatedTx: StockTransactionsCompanion(
          id: Value(widget.existingTx!.id),
          cardId: Value(widget.cardId),
          type: Value(_type),
          entryMode: Value(_entryMode),
          date: Value(_date),
          price: Value(price),
          quantity: Value(qty),
          totalAmount: Value(total),
        ),
      );
    } else {
      // Insert new transaction
      await dao.insertTransaction(
        StockTransactionsCompanion(
          cardId: Value(widget.cardId),
          type: Value(_type),
          entryMode: Value(_entryMode),
          date: Value(_date),
          price: Value(price),
          quantity: Value(qty),
          totalAmount: Value(total),
        ),
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    widget.existingTx != null ? 'Edit Transaction' : 'Add Transaction',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Type toggle ────────────────────────────────────────────────
              _SectionLabel(label: 'Type'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'BUY', label: Text('Buy'), icon: Icon(Icons.trending_up)),
                  ButtonSegment(value: 'SELL', label: Text('Sell'), icon: Icon(Icons.trending_down)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  // If switching to SELL while in RIGHTS, reset to NORMAL
                  if (_type == 'SELL' && _entryMode == 'RIGHTS') {
                    _entryMode = 'NORMAL';
                  }
                  // If switching to BUY while in BUYBACK, reset to NORMAL
                  if (_type == 'BUY' && _entryMode == 'BUYBACK') {
                    _entryMode = 'NORMAL';
                  }
                  // Clear sell error when switching.
                  _sellValidationError = null;
                }),
              ),
              const SizedBox(height: 16),

              // ── Entry mode toggle ──────────────────────────────────────────
              _SectionLabel(label: 'Transaction Mode / Category'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'NORMAL', label: Text('Market Trade')),
                  const ButtonSegment(value: 'AVG', label: Text('Avg Price')),
                  if (_type == 'BUY')
                    const ButtonSegment(value: 'RIGHTS', label: Text('Rights Issue')),
                  if (_type == 'SELL')
                    const ButtonSegment(value: 'BUYBACK', label: Text('Tender Buyback')),
                ],
                selected: {_entryMode},
                onSelectionChanged: (s) {
                  final newMode = s.first;
                  setState(() {
                    _entryMode = newMode;
                    if (_entryMode == 'AVG') {
                      _date = DateTime.now();
                      _priceRange = null;
                      _fetchError = null;
                    } else if (_entryMode == 'RIGHTS' || _entryMode == 'BUYBACK') {
                      _priceRange = null;
                      _fetchError = null;
                    }
                  });
                  if (newMode == 'NORMAL') {
                    _fetchPriceRange();
                  }
                },
              ),
              const SizedBox(height: 16),

              // ── Date ───────────────────────────────────────────────────────
              _SectionLabel(label: 'Date'),
              const SizedBox(height: 6),
              if (_checkingCalendar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking market calendar...',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_calendarStatus == TradingDayStatus.closed && _calendarError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, size: 18, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _calendarError!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_calendarStatus == TradingDayStatus.unknown && _calendarError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _calendarError!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _validateDateAndLoadRange(_date),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_dateFmt.format(_date)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Price ──────────────────────────────────────────────────────
              _SectionLabel(label: 'Price (₹)'),
              const SizedBox(height: 6),
              if (_entryMode == 'NORMAL') ...[
                if (_fetchingRange)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: LinearProgressIndicator(),
                  ),
                if (_fetchError != null)
                  _FetchErrorBanner(
                    onRetry: _fetchPriceRange,
                    message: _fetchError!,
                    showRetry: !_isMarketNotOpen,
                  ),
              ],
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: '₹ ',
                  hintText: _entryMode == 'NORMAL'
                      ? (_fetchingRange
                          ? 'Fetching day price range…'
                          : (_priceRange != null
                              ? 'Range: ₹${_fmt.format(_priceRange!.low)} – ₹${_fmt.format(_priceRange!.high)}'
                              : 'Enter price'))
                      : (_entryMode == 'RIGHTS'
                          ? 'Enter rights issue allotment price'
                          : (_entryMode == 'BUYBACK'
                              ? 'Enter tender offer price'
                              : 'Enter average price')),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final price = double.tryParse(v);
                  if (price == null) return 'Enter a valid price';
                  if (_entryMode == 'AVG') {
                    if (price < 0) return 'Price cannot be negative';
                  } else if (_entryMode == 'RIGHTS' || _entryMode == 'BUYBACK') {
                    if (price <= 0) return 'Price must be greater than zero';
                  } else {
                    if (price <= 0) return 'Enter a valid price';
                    if (_priceRange == null) {
                      return 'Day price range not loaded yet';
                    }
                    if (!_priceRange!.containsPrice(price)) {
                      return 'Price must be within range '
                          '₹${_fmt.format(_priceRange!.low)} – ₹${_fmt.format(_priceRange!.high)}';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Quantity ───────────────────────────────────────────────────
              _SectionLabel(label: 'Quantity'),
              const SizedBox(height: 6),
              // Inline sell-validation error. Shown instead of a SnackBar because
              // this sheet is in a modal with no ancestor Scaffold.
              if (_sellValidationError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sellValidationError!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _sellValidationError != null
                        ? BorderSide(color: cs.error, width: 1.5)
                        : const BorderSide(),
                  ),
                  enabledBorder: _sellValidationError != null
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.error, width: 1.5),
                        )
                      : null,
                  hintText: 'Number of shares',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final qty = int.tryParse(v);
                  if (qty == null || qty <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Total amount (read-only) ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: theme.textTheme.bodyMedium),
                    Text(
                      '₹ ${_fmt.format(_totalAmount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _type == 'BUY' ? const Color(0xFF1B8A4C) : cs.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.existingTx != null ? 'Save Changes' : 'Add Transaction',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      );
}

class _FetchErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool showRetry;

  const _FetchErrorBanner({
    required this.message,
    required this.onRetry,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          if (showRetry)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
