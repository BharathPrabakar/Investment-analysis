// lib/stocks/create_stock_card_flow.dart
//
// Multi-step flow for creating a new stock card.
// Step 1: Ticker search (autocomplete from local dataset)
// Step 2: Tags (optional)
// Step 3: First transaction entry
// Step 4: Confirmation + create

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../data/local_tickers.dart';
import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../services/price_service.dart';
import '../services/trading_day_service.dart';
import 'widgets/tag_chip.dart';

class CreateStockCardFlow extends StatefulWidget {
  const CreateStockCardFlow({super.key});

  @override
  State<CreateStockCardFlow> createState() => _CreateStockCardFlowState();
}

class _CreateStockCardFlowState extends State<CreateStockCardFlow> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1 data
  TickerInfo? _selectedTicker;

  // Step 2 data
  final List<String> _selectedTagNames = [];
  final _newTagCtrl = TextEditingController();

  // Step 3 data — captured after the inline transaction form
  _PendingTx? _pendingTx;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _createCard() async {
    assert(_selectedTicker != null && _pendingTx != null);
    final db = AppDbProvider.of(context);
    final dao = db.stocksDao;

    // Atomically create card, tags, and first transaction in ONE DB transaction
    final tx = _pendingTx!;
    try {
      await dao.createCardWithInitialData(
        card: StockCardsCompanion(
          ticker: drift.Value(_selectedTicker!.symbol),
          exchange: drift.Value(_selectedTicker!.exchange),
          stockName: drift.Value(_selectedTicker!.companyName),
        ),
        tagNames: _selectedTagNames,
        firstTransaction: StockTransactionsCompanion(
          type: drift.Value(tx.type),
          entryMode: drift.Value(tx.entryMode),
          date: drift.Value(tx.date),
          price: drift.Value(tx.price),
          quantity: drift.Value(tx.quantity),
          totalAmount: drift.Value(tx.totalAmount),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('unique') || msg.contains('sqlite_constraint')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This stock was already added'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle()),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goTo(_step - 1),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Step1TickerSearch(
            onSelected: (ticker) {
              setState(() => _selectedTicker = ticker);
              _goTo(1);
            },
          ),
          _Step2Tags(
            selectedTags: _selectedTagNames,
            newTagCtrl: _newTagCtrl,
            onTagAdded: (name) => setState(() => _selectedTagNames.add(name)),
            onTagRemoved: (name) => setState(() => _selectedTagNames.remove(name)),
            onNext: () => _goTo(2),
          ),
          _Step3Transaction(
            key: ValueKey('${_selectedTicker?.exchange}:${_selectedTicker?.symbol}'),
            ticker: _selectedTicker?.symbol ?? '',
            exchange: _selectedTicker?.exchange ?? 'NSE',
            isin: _selectedTicker?.isin,
            onTransactionCaptured: (tx) {
              setState(() => _pendingTx = tx);
              _goTo(3);
            },
          ),
          _Step4Confirm(
            ticker: _selectedTicker,
            tags: _selectedTagNames,
            tx: _pendingTx,
            onConfirm: _createCard,
          ),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Select Stock';
      case 1:
        return 'Add Tags';
      case 2:
        return 'First Transaction';
      case 3:
        return 'Confirm';
      default:
        return 'New Stock Card';
    }
  }
}

// ─── Step 1: Ticker Search ────────────────────────────────────────────────────

class _Step1TickerSearch extends StatefulWidget {
  final ValueChanged<TickerInfo> onSelected;
  const _Step1TickerSearch({required this.onSelected});

  @override
  State<_Step1TickerSearch> createState() => _Step1TickerSearchState();
}

class _Step1TickerSearchState extends State<_Step1TickerSearch> {
  final _ctrl = TextEditingController();
  List<TickerInfo> _results = [];
  String _selectedExchange = 'ALL';

  @override
  void initState() {
    super.initState();
    ensureTickersLoaded().then((_) {
      if (mounted && _ctrl.text.isNotEmpty) {
        _runSearch();
      }
    });
    _ctrl.addListener(_runSearch);
  }

  void _runSearch() {
    setState(() {
      _results = searchTickers(
        _ctrl.text,
        exchange: _selectedExchange == 'ALL' ? null : _selectedExchange,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dao = AppDbProvider.of(context).stocksDao;

    return StreamBuilder<List<StockCard>>(
      stream: dao.watchAllCards(),
      initialData: const [],
      builder: (context, snapshot) {
        final existingCardKeys = (snapshot.data ?? [])
            .map((c) => '${c.exchange.toUpperCase()}:${c.ticker.toUpperCase()}')
            .toSet();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by symbol, scrip code or company…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
              // Exchange filter segment
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Exchanges'),
                    const SizedBox(width: 8),
                    _buildFilterChip('NSE', 'NSE'),
                    const SizedBox(width: 8),
                    _buildFilterChip('BSE', 'BSE'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _ctrl.text.isEmpty
                              ? 'Start typing to search stocks'
                              : 'No results found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final t = _results[i];
                          final cardKey = '${t.exchange.toUpperCase()}:${t.symbol.toUpperCase()}';
                          final isAlreadyAdded = existingCardKeys.contains(cardKey);

                          final subtitleText = t.exchange == 'BSE' && t.scripCode != null && t.scripCode!.isNotEmpty
                              ? '${t.companyName} · Scrip: ${t.scripCode}'
                              : t.companyName;

                          if (isAlreadyAdded) {
                            return ListTile(
                              key: ValueKey('stock_tile_${t.exchange}_${t.symbol}'),
                              leading: CircleAvatar(
                                backgroundColor: cs.onSurface.withValues(alpha: 0.12),
                                child: Text(
                                  t.exchange[0],
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.38),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    t.symbol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface.withValues(alpha: 0.38),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _ExchangeTag(exchange: t.exchange, isDimmed: true),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Already added',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                subtitleText,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${t.symbol} is already in your stocks.'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            );
                          }

                          return ListTile(
                            key: ValueKey('stock_tile_${t.exchange}_${t.symbol}'),
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                t.exchange[0],
                                style: TextStyle(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  t.symbol,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 6),
                                _ExchangeTag(exchange: t.exchange),
                              ],
                            ),
                            subtitle: Text(subtitleText),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            onTap: () => widget.onSelected(t),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _selectedExchange == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedExchange = value;
          });
          _runSearch();
        }
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? cs.onPrimary : cs.onSurface,
      ),
      selectedColor: cs.primary,
      backgroundColor: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ExchangeTag extends StatelessWidget {
  final String exchange;
  final bool isDimmed;

  const _ExchangeTag({required this.exchange, this.isDimmed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBse = exchange.toUpperCase() == 'BSE';

    final bg = isDimmed
        ? cs.onSurface.withValues(alpha: 0.08)
        : (isBse
            ? cs.tertiaryContainer
            : cs.secondaryContainer);
    final fg = isDimmed
        ? cs.onSurface.withValues(alpha: 0.45)
        : (isBse
            ? cs.onTertiaryContainer
            : cs.onSecondaryContainer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        exchange.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Step 2: Tags ─────────────────────────────────────────────────────────────

class _Step2Tags extends StatelessWidget {
  final List<String> selectedTags;
  final TextEditingController newTagCtrl;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;
  final VoidCallback onNext;

  const _Step2Tags({
    required this.selectedTags,
    required this.newTagCtrl,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const suggestedTags = ['Long-term', 'Short-term', 'Dividend', 'Growth', 'Index', 'Speculative'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags are optional — skip if not needed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          Text('Suggested', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: suggestedTags.map((tag) {
              final selected = selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: selected,
                onSelected: (_) =>
                    selected ? onTagRemoved(tag) : onTagAdded(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Custom tag', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newTagCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tag name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty && !selectedTags.contains(v.trim())) {
                      onTagAdded(v.trim());
                      newTagCtrl.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final v = newTagCtrl.text.trim();
                  if (v.isNotEmpty && !selectedTags.contains(v)) {
                    onTagAdded(v);
                    newTagCtrl.clear();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
          if (selectedTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Selected', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: selectedTags
                  .map((t) => TagChip(label: t, onDeleted: () => onTagRemoved(t)))
                  .toList(),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                selectedTags.isEmpty ? 'Skip & Continue' : 'Continue',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: First Transaction ────────────────────────────────────────────────

class _PendingTx {
  final String type;
  final String entryMode;
  final DateTime date;
  final double price;
  final int quantity;
  final double totalAmount;

  const _PendingTx({
    required this.type,
    required this.entryMode,
    required this.date,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });
}

class _Step3Transaction extends StatefulWidget {
  final String ticker;
  final String exchange;
  final String? isin;
  final ValueChanged<_PendingTx> onTransactionCaptured;

  const _Step3Transaction({
    super.key,
    required this.ticker,
    this.exchange = 'NSE',
    this.isin,
    required this.onTransactionCaptured,
  });

  @override
  State<_Step3Transaction> createState() => _Step3TransactionState();
}

class _Step3TransactionState extends State<_Step3Transaction> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  final String _type = 'BUY';
  String _entryMode = 'NORMAL';
  DateTime _date = DateTime.now();
  double _totalAmount = 0;

  // Calendar validation state
  bool _checkingCalendar = false;
  TradingDayStatus? _calendarStatus;
  String? _calendarError;
  int _calendarRequestId = 0;

  PriceRange? _priceRange;
  bool _fetchingRange = false;
  String? _fetchError;
  bool _isMarketNotOpen = false;
  int _rangeRequestId = 0;

  final _fmt = NumberFormat('#,##,##0.##', 'en_IN');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_recalc);
    _qtyCtrl.addListener(_recalc);

    _validateDateAndLoadRange(_date);
  }

  @override
  void didUpdateWidget(covariant _Step3Transaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticker != widget.ticker && widget.ticker.isNotEmpty) {
      _validateDateAndLoadRange(_date);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _recalc() {
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    final q = int.tryParse(_qtyCtrl.text) ?? 0;
    setState(() => _totalAmount = p * q);
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
      final r = await fetchDayPriceRange(
        widget.ticker,
        curDate,
        exchange: widget.exchange,
        isin: widget.isin,
      );
      if (!mounted || requestId != _rangeRequestId || _entryMode != 'NORMAL' || _date != curDate) {
        return;
      }
      setState(() {
        _priceRange = r;
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

    // 1. Re-check market calendar status
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

    if (!_formKey.currentState!.validate()) {
      debugPrint('_submit blocked: form validation failed');
      return;
    }
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

      if (_fetchingRange || _fetchError != null || _priceRange == null) {
        return;
      }

      final enteredPrice = double.tryParse(_priceCtrl.text);
      if (enteredPrice == null || enteredPrice < _priceRange!.low || enteredPrice > _priceRange!.high) {
        _formKey.currentState!.validate();
        return;
      }
    }
    widget.onTransactionCaptured(_PendingTx(
      type: _type,
      entryMode: _entryMode,
      date: _date,
      price: double.parse(_priceCtrl.text),
      quantity: int.parse(_qtyCtrl.text),
      totalAmount: double.parse(_priceCtrl.text) * int.parse(_qtyCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A card requires at least one transaction to be created.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 16),

            // Type is locked to BUY for the first transaction.
            // A brand-new card has zero quantity, so Sell is always invalid here.
            _Label('Type'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BUY', label: Text('Buy'), icon: Icon(Icons.trending_up)),
                ButtonSegment(value: 'SELL', label: Text('Sell'), icon: Icon(Icons.trending_down)),
              ],
              selected: const {'BUY'},
              // onSelectionChanged intentionally omitted — no-op disables interaction.
              onSelectionChanged: null,
              style: SegmentedButton.styleFrom(
                // Dim the Sell segment visually to signal it is not available.
                disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                disabledBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),

            _Label('Entry Mode'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'NORMAL', label: Text('Normal')),
                ButtonSegment(value: 'AVG', label: Text('Avg Price')),
              ],
              selected: {_entryMode},
              onSelectionChanged: (s) {
                final newMode = s.first;
                setState(() {
                  _entryMode = newMode;
                  if (_entryMode == 'AVG') {
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

            _Label('Date'),
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
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.event_busy, size: 18, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calendarError!,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            if (_calendarStatus == TradingDayStatus.unknown && _calendarError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calendarError!,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _validateDateAndLoadRange(_date),
                    child: const Text('Retry'),
                  ),
                ]),
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

            _Label('Price (₹)'),
            const SizedBox(height: 6),
            if (_entryMode == 'NORMAL' && _fetchingRange)
              const Padding(padding: EdgeInsets.only(bottom: 6), child: LinearProgressIndicator()),
            if (_entryMode == 'NORMAL' && _fetchError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_fetchError!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
                  ),
                  if (!_isMarketNotOpen)
                    TextButton(onPressed: _fetchPriceRange, child: const Text('Retry')),
                ]),
              ),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixText: '₹ ',
                hintText: _entryMode == 'NORMAL'
                    ? (_fetchingRange
                        ? 'Fetching day price range…'
                        : (_priceRange != null
                            ? 'Range: ₹${_fmt.format(_priceRange!.low)} – ₹${_fmt.format(_priceRange!.high)}'
                            : 'Enter price'))
                    : 'Enter price',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final p = double.tryParse(v);
                if (p == null) return 'Enter a valid price';
                if (_entryMode == 'AVG') {
                  if (p < 0) return 'Price cannot be negative';
                } else {
                  if (p <= 0) return 'Enter a valid price';
                  if (_priceRange == null) {
                    return 'Day price range not loaded yet';
                  }
                  if (p < _priceRange!.low || p > _priceRange!.high) {
                    return 'Price outside range ₹${_fmt.format(_priceRange!.low)} – ₹${_fmt.format(_priceRange!.high)}';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _Label('Quantity'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Number of shares',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final q = int.tryParse(v);
                if (q == null || q <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

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
                  Text('₹ ${_fmt.format(_totalAmount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _type == 'BUY' ? const Color(0xFF1B8A4C) : cs.error)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// ─── Step 4: Confirmation ─────────────────────────────────────────────────────

class _Step4Confirm extends StatelessWidget {
  final TickerInfo? ticker;
  final List<String> tags;
  final _PendingTx? tx;
  final VoidCallback onConfirm;

  const _Step4Confirm({
    required this.ticker,
    required this.tags,
    required this.tx,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fmt = NumberFormat('#,##,##0.##', 'en_IN');
    final dateFmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Create', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Stock info card
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Ticker', value: ticker?.symbol ?? '—'),
                  _InfoRow(label: 'Name', value: ticker?.companyName ?? '—'),
                  _InfoRow(label: 'Exchange', value: ticker?.exchange ?? '—'),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: tags.map((t) => TagChip(label: t)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transaction card
          if (tx != null)
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('First Transaction',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Type', value: tx!.type),
                    _InfoRow(label: 'Date', value: dateFmt.format(tx!.date)),
                    _InfoRow(label: 'Price', value: '₹ ${fmt.format(tx!.price)}'),
                    _InfoRow(label: 'Quantity', value: tx!.quantity.toString()),
                    _InfoRow(label: 'Total', value: '₹ ${fmt.format(tx!.totalAmount)}'),
                  ],
                ),
              ),
            ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
