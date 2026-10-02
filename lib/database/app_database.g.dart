// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StockCardsTable extends StockCards
    with TableInfo<$StockCardsTable, StockCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exchangeMeta = const VerificationMeta(
    'exchange',
  );
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
    'exchange',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockNameMeta = const VerificationMeta(
    'stockName',
  );
  @override
  late final GeneratedColumn<String> stockName = GeneratedColumn<String>(
    'stock_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPriceMeta = const VerificationMeta(
    'lastPrice',
  );
  @override
  late final GeneratedColumn<double> lastPrice = GeneratedColumn<double>(
    'last_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPriceFetchedAtMeta =
      const VerificationMeta('lastPriceFetchedAt');
  @override
  late final GeneratedColumn<DateTime> lastPriceFetchedAt =
      GeneratedColumn<DateTime>(
        'last_price_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _prevCloseMeta = const VerificationMeta(
    'prevClose',
  );
  @override
  late final GeneratedColumn<double> prevClose = GeneratedColumn<double>(
    'prev_close',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dividendsFetchedUptoMeta =
      const VerificationMeta('dividendsFetchedUpto');
  @override
  late final GeneratedColumn<DateTime> dividendsFetchedUpto =
      GeneratedColumn<DateTime>(
        'dividends_fetched_upto',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ticker,
    exchange,
    stockName,
    lastPrice,
    lastPriceFetchedAt,
    prevClose,
    dividendsFetchedUpto,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    } else if (isInserting) {
      context.missing(_tickerMeta);
    }
    if (data.containsKey('exchange')) {
      context.handle(
        _exchangeMeta,
        exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta),
      );
    } else if (isInserting) {
      context.missing(_exchangeMeta);
    }
    if (data.containsKey('stock_name')) {
      context.handle(
        _stockNameMeta,
        stockName.isAcceptableOrUnknown(data['stock_name']!, _stockNameMeta),
      );
    } else if (isInserting) {
      context.missing(_stockNameMeta);
    }
    if (data.containsKey('last_price')) {
      context.handle(
        _lastPriceMeta,
        lastPrice.isAcceptableOrUnknown(data['last_price']!, _lastPriceMeta),
      );
    }
    if (data.containsKey('last_price_fetched_at')) {
      context.handle(
        _lastPriceFetchedAtMeta,
        lastPriceFetchedAt.isAcceptableOrUnknown(
          data['last_price_fetched_at']!,
          _lastPriceFetchedAtMeta,
        ),
      );
    }
    if (data.containsKey('prev_close')) {
      context.handle(
        _prevCloseMeta,
        prevClose.isAcceptableOrUnknown(data['prev_close']!, _prevCloseMeta),
      );
    }
    if (data.containsKey('dividends_fetched_upto')) {
      context.handle(
        _dividendsFetchedUptoMeta,
        dividendsFetchedUpto.isAcceptableOrUnknown(
          data['dividends_fetched_upto']!,
          _dividendsFetchedUptoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ticker, exchange},
  ];
  @override
  StockCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      )!,
      exchange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange'],
      )!,
      stockName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_name'],
      )!,
      lastPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_price'],
      ),
      lastPriceFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_price_fetched_at'],
      ),
      prevClose: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}prev_close'],
      ),
      dividendsFetchedUpto: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dividends_fetched_upto'],
      ),
    );
  }

  @override
  $StockCardsTable createAlias(String alias) {
    return $StockCardsTable(attachedDatabase, alias);
  }
}

class StockCard extends DataClass implements Insertable<StockCard> {
  final int id;
  final String ticker;
  final String exchange;
  final String stockName;
  final double? lastPrice;
  final DateTime? lastPriceFetchedAt;
  final double? prevClose;
  final DateTime? dividendsFetchedUpto;
  const StockCard({
    required this.id,
    required this.ticker,
    required this.exchange,
    required this.stockName,
    this.lastPrice,
    this.lastPriceFetchedAt,
    this.prevClose,
    this.dividendsFetchedUpto,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ticker'] = Variable<String>(ticker);
    map['exchange'] = Variable<String>(exchange);
    map['stock_name'] = Variable<String>(stockName);
    if (!nullToAbsent || lastPrice != null) {
      map['last_price'] = Variable<double>(lastPrice);
    }
    if (!nullToAbsent || lastPriceFetchedAt != null) {
      map['last_price_fetched_at'] = Variable<DateTime>(lastPriceFetchedAt);
    }
    if (!nullToAbsent || prevClose != null) {
      map['prev_close'] = Variable<double>(prevClose);
    }
    if (!nullToAbsent || dividendsFetchedUpto != null) {
      map['dividends_fetched_upto'] = Variable<DateTime>(dividendsFetchedUpto);
    }
    return map;
  }

  StockCardsCompanion toCompanion(bool nullToAbsent) {
    return StockCardsCompanion(
      id: Value(id),
      ticker: Value(ticker),
      exchange: Value(exchange),
      stockName: Value(stockName),
      lastPrice: lastPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPrice),
      lastPriceFetchedAt: lastPriceFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPriceFetchedAt),
      prevClose: prevClose == null && nullToAbsent
          ? const Value.absent()
          : Value(prevClose),
      dividendsFetchedUpto: dividendsFetchedUpto == null && nullToAbsent
          ? const Value.absent()
          : Value(dividendsFetchedUpto),
    );
  }

  factory StockCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockCard(
      id: serializer.fromJson<int>(json['id']),
      ticker: serializer.fromJson<String>(json['ticker']),
      exchange: serializer.fromJson<String>(json['exchange']),
      stockName: serializer.fromJson<String>(json['stockName']),
      lastPrice: serializer.fromJson<double?>(json['lastPrice']),
      lastPriceFetchedAt: serializer.fromJson<DateTime?>(
        json['lastPriceFetchedAt'],
      ),
      prevClose: serializer.fromJson<double?>(json['prevClose']),
      dividendsFetchedUpto: serializer.fromJson<DateTime?>(
        json['dividendsFetchedUpto'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ticker': serializer.toJson<String>(ticker),
      'exchange': serializer.toJson<String>(exchange),
      'stockName': serializer.toJson<String>(stockName),
      'lastPrice': serializer.toJson<double?>(lastPrice),
      'lastPriceFetchedAt': serializer.toJson<DateTime?>(lastPriceFetchedAt),
      'prevClose': serializer.toJson<double?>(prevClose),
      'dividendsFetchedUpto': serializer.toJson<DateTime?>(
        dividendsFetchedUpto,
      ),
    };
  }

  StockCard copyWith({
    int? id,
    String? ticker,
    String? exchange,
    String? stockName,
    Value<double?> lastPrice = const Value.absent(),
    Value<DateTime?> lastPriceFetchedAt = const Value.absent(),
    Value<double?> prevClose = const Value.absent(),
    Value<DateTime?> dividendsFetchedUpto = const Value.absent(),
  }) => StockCard(
    id: id ?? this.id,
    ticker: ticker ?? this.ticker,
    exchange: exchange ?? this.exchange,
    stockName: stockName ?? this.stockName,
    lastPrice: lastPrice.present ? lastPrice.value : this.lastPrice,
    lastPriceFetchedAt: lastPriceFetchedAt.present
        ? lastPriceFetchedAt.value
        : this.lastPriceFetchedAt,
    prevClose: prevClose.present ? prevClose.value : this.prevClose,
    dividendsFetchedUpto: dividendsFetchedUpto.present
        ? dividendsFetchedUpto.value
        : this.dividendsFetchedUpto,
  );
  StockCard copyWithCompanion(StockCardsCompanion data) {
    return StockCard(
      id: data.id.present ? data.id.value : this.id,
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      stockName: data.stockName.present ? data.stockName.value : this.stockName,
      lastPrice: data.lastPrice.present ? data.lastPrice.value : this.lastPrice,
      lastPriceFetchedAt: data.lastPriceFetchedAt.present
          ? data.lastPriceFetchedAt.value
          : this.lastPriceFetchedAt,
      prevClose: data.prevClose.present ? data.prevClose.value : this.prevClose,
      dividendsFetchedUpto: data.dividendsFetchedUpto.present
          ? data.dividendsFetchedUpto.value
          : this.dividendsFetchedUpto,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockCard(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('exchange: $exchange, ')
          ..write('stockName: $stockName, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('lastPriceFetchedAt: $lastPriceFetchedAt, ')
          ..write('prevClose: $prevClose, ')
          ..write('dividendsFetchedUpto: $dividendsFetchedUpto')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ticker,
    exchange,
    stockName,
    lastPrice,
    lastPriceFetchedAt,
    prevClose,
    dividendsFetchedUpto,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockCard &&
          other.id == this.id &&
          other.ticker == this.ticker &&
          other.exchange == this.exchange &&
          other.stockName == this.stockName &&
          other.lastPrice == this.lastPrice &&
          other.lastPriceFetchedAt == this.lastPriceFetchedAt &&
          other.prevClose == this.prevClose &&
          other.dividendsFetchedUpto == this.dividendsFetchedUpto);
}

class StockCardsCompanion extends UpdateCompanion<StockCard> {
  final Value<int> id;
  final Value<String> ticker;
  final Value<String> exchange;
  final Value<String> stockName;
  final Value<double?> lastPrice;
  final Value<DateTime?> lastPriceFetchedAt;
  final Value<double?> prevClose;
  final Value<DateTime?> dividendsFetchedUpto;
  const StockCardsCompanion({
    this.id = const Value.absent(),
    this.ticker = const Value.absent(),
    this.exchange = const Value.absent(),
    this.stockName = const Value.absent(),
    this.lastPrice = const Value.absent(),
    this.lastPriceFetchedAt = const Value.absent(),
    this.prevClose = const Value.absent(),
    this.dividendsFetchedUpto = const Value.absent(),
  });
  StockCardsCompanion.insert({
    this.id = const Value.absent(),
    required String ticker,
    required String exchange,
    required String stockName,
    this.lastPrice = const Value.absent(),
    this.lastPriceFetchedAt = const Value.absent(),
    this.prevClose = const Value.absent(),
    this.dividendsFetchedUpto = const Value.absent(),
  }) : ticker = Value(ticker),
       exchange = Value(exchange),
       stockName = Value(stockName);
  static Insertable<StockCard> custom({
    Expression<int>? id,
    Expression<String>? ticker,
    Expression<String>? exchange,
    Expression<String>? stockName,
    Expression<double>? lastPrice,
    Expression<DateTime>? lastPriceFetchedAt,
    Expression<double>? prevClose,
    Expression<DateTime>? dividendsFetchedUpto,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ticker != null) 'ticker': ticker,
      if (exchange != null) 'exchange': exchange,
      if (stockName != null) 'stock_name': stockName,
      if (lastPrice != null) 'last_price': lastPrice,
      if (lastPriceFetchedAt != null)
        'last_price_fetched_at': lastPriceFetchedAt,
      if (prevClose != null) 'prev_close': prevClose,
      if (dividendsFetchedUpto != null)
        'dividends_fetched_upto': dividendsFetchedUpto,
    });
  }

  StockCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? ticker,
    Value<String>? exchange,
    Value<String>? stockName,
    Value<double?>? lastPrice,
    Value<DateTime?>? lastPriceFetchedAt,
    Value<double?>? prevClose,
    Value<DateTime?>? dividendsFetchedUpto,
  }) {
    return StockCardsCompanion(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      exchange: exchange ?? this.exchange,
      stockName: stockName ?? this.stockName,
      lastPrice: lastPrice ?? this.lastPrice,
      lastPriceFetchedAt: lastPriceFetchedAt ?? this.lastPriceFetchedAt,
      prevClose: prevClose ?? this.prevClose,
      dividendsFetchedUpto: dividendsFetchedUpto ?? this.dividendsFetchedUpto,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (stockName.present) {
      map['stock_name'] = Variable<String>(stockName.value);
    }
    if (lastPrice.present) {
      map['last_price'] = Variable<double>(lastPrice.value);
    }
    if (lastPriceFetchedAt.present) {
      map['last_price_fetched_at'] = Variable<DateTime>(
        lastPriceFetchedAt.value,
      );
    }
    if (prevClose.present) {
      map['prev_close'] = Variable<double>(prevClose.value);
    }
    if (dividendsFetchedUpto.present) {
      map['dividends_fetched_upto'] = Variable<DateTime>(
        dividendsFetchedUpto.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCardsCompanion(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('exchange: $exchange, ')
          ..write('stockName: $stockName, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('lastPriceFetchedAt: $lastPriceFetchedAt, ')
          ..write('prevClose: $prevClose, ')
          ..write('dividendsFetchedUpto: $dividendsFetchedUpto')
          ..write(')'))
        .toString();
  }
}

class $StockTransactionsTable extends StockTransactions
    with TableInfo<$StockTransactionsTable, StockTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_cards (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryModeMeta = const VerificationMeta(
    'entryMode',
  );
  @override
  late final GeneratedColumn<String> entryMode = GeneratedColumn<String>(
    'entry_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    type,
    entryMode,
    date,
    price,
    quantity,
    totalAmount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('entry_mode')) {
      context.handle(
        _entryModeMeta,
        entryMode.isAcceptableOrUnknown(data['entry_mode']!, _entryModeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryModeMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      entryMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_mode'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
    );
  }

  @override
  $StockTransactionsTable createAlias(String alias) {
    return $StockTransactionsTable(attachedDatabase, alias);
  }
}

class StockTransaction extends DataClass
    implements Insertable<StockTransaction> {
  final int id;

  /// Foreign key -> stock_cards.id
  /// The cascade delete is handled by the DB migration (SQLite pragma + FK clause).
  final int cardId;

  /// "BUY", "SELL", or "DIVIDEND"
  final String type;

  /// "NORMAL", "AVG", or "AUTO"
  final String entryMode;

  /// Date-only (time portion is ignored in business logic)
  final DateTime date;
  final double price;
  final int quantity;

  /// Stored as price * quantity at the time of entry. Never recomputed on read.
  final double totalAmount;
  const StockTransaction({
    required this.id,
    required this.cardId,
    required this.type,
    required this.entryMode,
    required this.date,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['type'] = Variable<String>(type);
    map['entry_mode'] = Variable<String>(entryMode);
    map['date'] = Variable<DateTime>(date);
    map['price'] = Variable<double>(price);
    map['quantity'] = Variable<int>(quantity);
    map['total_amount'] = Variable<double>(totalAmount);
    return map;
  }

  StockTransactionsCompanion toCompanion(bool nullToAbsent) {
    return StockTransactionsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      type: Value(type),
      entryMode: Value(entryMode),
      date: Value(date),
      price: Value(price),
      quantity: Value(quantity),
      totalAmount: Value(totalAmount),
    );
  }

  factory StockTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockTransaction(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      type: serializer.fromJson<String>(json['type']),
      entryMode: serializer.fromJson<String>(json['entryMode']),
      date: serializer.fromJson<DateTime>(json['date']),
      price: serializer.fromJson<double>(json['price']),
      quantity: serializer.fromJson<int>(json['quantity']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'type': serializer.toJson<String>(type),
      'entryMode': serializer.toJson<String>(entryMode),
      'date': serializer.toJson<DateTime>(date),
      'price': serializer.toJson<double>(price),
      'quantity': serializer.toJson<int>(quantity),
      'totalAmount': serializer.toJson<double>(totalAmount),
    };
  }

  StockTransaction copyWith({
    int? id,
    int? cardId,
    String? type,
    String? entryMode,
    DateTime? date,
    double? price,
    int? quantity,
    double? totalAmount,
  }) => StockTransaction(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    type: type ?? this.type,
    entryMode: entryMode ?? this.entryMode,
    date: date ?? this.date,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    totalAmount: totalAmount ?? this.totalAmount,
  );
  StockTransaction copyWithCompanion(StockTransactionsCompanion data) {
    return StockTransaction(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      type: data.type.present ? data.type.value : this.type,
      entryMode: data.entryMode.present ? data.entryMode.value : this.entryMode,
      date: data.date.present ? data.date.value : this.date,
      price: data.price.present ? data.price.value : this.price,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockTransaction(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('type: $type, ')
          ..write('entryMode: $entryMode, ')
          ..write('date: $date, ')
          ..write('price: $price, ')
          ..write('quantity: $quantity, ')
          ..write('totalAmount: $totalAmount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    type,
    entryMode,
    date,
    price,
    quantity,
    totalAmount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockTransaction &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.type == this.type &&
          other.entryMode == this.entryMode &&
          other.date == this.date &&
          other.price == this.price &&
          other.quantity == this.quantity &&
          other.totalAmount == this.totalAmount);
}

class StockTransactionsCompanion extends UpdateCompanion<StockTransaction> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> type;
  final Value<String> entryMode;
  final Value<DateTime> date;
  final Value<double> price;
  final Value<int> quantity;
  final Value<double> totalAmount;
  const StockTransactionsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.type = const Value.absent(),
    this.entryMode = const Value.absent(),
    this.date = const Value.absent(),
    this.price = const Value.absent(),
    this.quantity = const Value.absent(),
    this.totalAmount = const Value.absent(),
  });
  StockTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String type,
    required String entryMode,
    required DateTime date,
    required double price,
    required int quantity,
    required double totalAmount,
  }) : cardId = Value(cardId),
       type = Value(type),
       entryMode = Value(entryMode),
       date = Value(date),
       price = Value(price),
       quantity = Value(quantity),
       totalAmount = Value(totalAmount);
  static Insertable<StockTransaction> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? type,
    Expression<String>? entryMode,
    Expression<DateTime>? date,
    Expression<double>? price,
    Expression<int>? quantity,
    Expression<double>? totalAmount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (type != null) 'type': type,
      if (entryMode != null) 'entry_mode': entryMode,
      if (date != null) 'date': date,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
      if (totalAmount != null) 'total_amount': totalAmount,
    });
  }

  StockTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? type,
    Value<String>? entryMode,
    Value<DateTime>? date,
    Value<double>? price,
    Value<int>? quantity,
    Value<double>? totalAmount,
  }) {
    return StockTransactionsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      type: type ?? this.type,
      entryMode: entryMode ?? this.entryMode,
      date: date ?? this.date,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (entryMode.present) {
      map['entry_mode'] = Variable<String>(entryMode.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('type: $type, ')
          ..write('entryMode: $entryMode, ')
          ..write('date: $date, ')
          ..write('price: $price, ')
          ..write('quantity: $quantity, ')
          ..write('totalAmount: $totalAmount')
          ..write(')'))
        .toString();
  }
}

class $MfCardsTable extends MfCards with TableInfo<$MfCardsTable, MfCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MfCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _schemeCodeMeta = const VerificationMeta(
    'schemeCode',
  );
  @override
  late final GeneratedColumn<String> schemeCode = GeneratedColumn<String>(
    'scheme_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isinMeta = const VerificationMeta('isin');
  @override
  late final GeneratedColumn<String> isin = GeneratedColumn<String>(
    'isin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeNameMeta = const VerificationMeta(
    'schemeName',
  );
  @override
  late final GeneratedColumn<String> schemeName = GeneratedColumn<String>(
    'scheme_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amcNameMeta = const VerificationMeta(
    'amcName',
  );
  @override
  late final GeneratedColumn<String> amcName = GeneratedColumn<String>(
    'amc_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planMeta = const VerificationMeta('plan');
  @override
  late final GeneratedColumn<String> plan = GeneratedColumn<String>(
    'plan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionMeta = const VerificationMeta('option');
  @override
  late final GeneratedColumn<String> option = GeneratedColumn<String>(
    'option',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schemeCode,
    isin,
    schemeName,
    amcName,
    plan,
    option,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mf_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<MfCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scheme_code')) {
      context.handle(
        _schemeCodeMeta,
        schemeCode.isAcceptableOrUnknown(data['scheme_code']!, _schemeCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_schemeCodeMeta);
    }
    if (data.containsKey('isin')) {
      context.handle(
        _isinMeta,
        isin.isAcceptableOrUnknown(data['isin']!, _isinMeta),
      );
    } else if (isInserting) {
      context.missing(_isinMeta);
    }
    if (data.containsKey('scheme_name')) {
      context.handle(
        _schemeNameMeta,
        schemeName.isAcceptableOrUnknown(data['scheme_name']!, _schemeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_schemeNameMeta);
    }
    if (data.containsKey('amc_name')) {
      context.handle(
        _amcNameMeta,
        amcName.isAcceptableOrUnknown(data['amc_name']!, _amcNameMeta),
      );
    } else if (isInserting) {
      context.missing(_amcNameMeta);
    }
    if (data.containsKey('plan')) {
      context.handle(
        _planMeta,
        plan.isAcceptableOrUnknown(data['plan']!, _planMeta),
      );
    } else if (isInserting) {
      context.missing(_planMeta);
    }
    if (data.containsKey('option')) {
      context.handle(
        _optionMeta,
        option.isAcceptableOrUnknown(data['option']!, _optionMeta),
      );
    } else if (isInserting) {
      context.missing(_optionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MfCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MfCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      schemeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme_code'],
      )!,
      isin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isin'],
      )!,
      schemeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme_name'],
      )!,
      amcName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amc_name'],
      )!,
      plan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan'],
      )!,
      option: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
    );
  }

  @override
  $MfCardsTable createAlias(String alias) {
    return $MfCardsTable(attachedDatabase, alias);
  }
}

class MfCard extends DataClass implements Insertable<MfCard> {
  final int id;
  final String schemeCode;
  final String isin;
  final String schemeName;
  final String amcName;
  final String plan;
  final String option;
  final String category;
  const MfCard({
    required this.id,
    required this.schemeCode,
    required this.isin,
    required this.schemeName,
    required this.amcName,
    required this.plan,
    required this.option,
    required this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scheme_code'] = Variable<String>(schemeCode);
    map['isin'] = Variable<String>(isin);
    map['scheme_name'] = Variable<String>(schemeName);
    map['amc_name'] = Variable<String>(amcName);
    map['plan'] = Variable<String>(plan);
    map['option'] = Variable<String>(option);
    map['category'] = Variable<String>(category);
    return map;
  }

  MfCardsCompanion toCompanion(bool nullToAbsent) {
    return MfCardsCompanion(
      id: Value(id),
      schemeCode: Value(schemeCode),
      isin: Value(isin),
      schemeName: Value(schemeName),
      amcName: Value(amcName),
      plan: Value(plan),
      option: Value(option),
      category: Value(category),
    );
  }

  factory MfCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MfCard(
      id: serializer.fromJson<int>(json['id']),
      schemeCode: serializer.fromJson<String>(json['schemeCode']),
      isin: serializer.fromJson<String>(json['isin']),
      schemeName: serializer.fromJson<String>(json['schemeName']),
      amcName: serializer.fromJson<String>(json['amcName']),
      plan: serializer.fromJson<String>(json['plan']),
      option: serializer.fromJson<String>(json['option']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'schemeCode': serializer.toJson<String>(schemeCode),
      'isin': serializer.toJson<String>(isin),
      'schemeName': serializer.toJson<String>(schemeName),
      'amcName': serializer.toJson<String>(amcName),
      'plan': serializer.toJson<String>(plan),
      'option': serializer.toJson<String>(option),
      'category': serializer.toJson<String>(category),
    };
  }

  MfCard copyWith({
    int? id,
    String? schemeCode,
    String? isin,
    String? schemeName,
    String? amcName,
    String? plan,
    String? option,
    String? category,
  }) => MfCard(
    id: id ?? this.id,
    schemeCode: schemeCode ?? this.schemeCode,
    isin: isin ?? this.isin,
    schemeName: schemeName ?? this.schemeName,
    amcName: amcName ?? this.amcName,
    plan: plan ?? this.plan,
    option: option ?? this.option,
    category: category ?? this.category,
  );
  MfCard copyWithCompanion(MfCardsCompanion data) {
    return MfCard(
      id: data.id.present ? data.id.value : this.id,
      schemeCode: data.schemeCode.present
          ? data.schemeCode.value
          : this.schemeCode,
      isin: data.isin.present ? data.isin.value : this.isin,
      schemeName: data.schemeName.present
          ? data.schemeName.value
          : this.schemeName,
      amcName: data.amcName.present ? data.amcName.value : this.amcName,
      plan: data.plan.present ? data.plan.value : this.plan,
      option: data.option.present ? data.option.value : this.option,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MfCard(')
          ..write('id: $id, ')
          ..write('schemeCode: $schemeCode, ')
          ..write('isin: $isin, ')
          ..write('schemeName: $schemeName, ')
          ..write('amcName: $amcName, ')
          ..write('plan: $plan, ')
          ..write('option: $option, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schemeCode,
    isin,
    schemeName,
    amcName,
    plan,
    option,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MfCard &&
          other.id == this.id &&
          other.schemeCode == this.schemeCode &&
          other.isin == this.isin &&
          other.schemeName == this.schemeName &&
          other.amcName == this.amcName &&
          other.plan == this.plan &&
          other.option == this.option &&
          other.category == this.category);
}

class MfCardsCompanion extends UpdateCompanion<MfCard> {
  final Value<int> id;
  final Value<String> schemeCode;
  final Value<String> isin;
  final Value<String> schemeName;
  final Value<String> amcName;
  final Value<String> plan;
  final Value<String> option;
  final Value<String> category;
  const MfCardsCompanion({
    this.id = const Value.absent(),
    this.schemeCode = const Value.absent(),
    this.isin = const Value.absent(),
    this.schemeName = const Value.absent(),
    this.amcName = const Value.absent(),
    this.plan = const Value.absent(),
    this.option = const Value.absent(),
    this.category = const Value.absent(),
  });
  MfCardsCompanion.insert({
    this.id = const Value.absent(),
    required String schemeCode,
    required String isin,
    required String schemeName,
    required String amcName,
    required String plan,
    required String option,
    required String category,
  }) : schemeCode = Value(schemeCode),
       isin = Value(isin),
       schemeName = Value(schemeName),
       amcName = Value(amcName),
       plan = Value(plan),
       option = Value(option),
       category = Value(category);
  static Insertable<MfCard> custom({
    Expression<int>? id,
    Expression<String>? schemeCode,
    Expression<String>? isin,
    Expression<String>? schemeName,
    Expression<String>? amcName,
    Expression<String>? plan,
    Expression<String>? option,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schemeCode != null) 'scheme_code': schemeCode,
      if (isin != null) 'isin': isin,
      if (schemeName != null) 'scheme_name': schemeName,
      if (amcName != null) 'amc_name': amcName,
      if (plan != null) 'plan': plan,
      if (option != null) 'option': option,
      if (category != null) 'category': category,
    });
  }

  MfCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? schemeCode,
    Value<String>? isin,
    Value<String>? schemeName,
    Value<String>? amcName,
    Value<String>? plan,
    Value<String>? option,
    Value<String>? category,
  }) {
    return MfCardsCompanion(
      id: id ?? this.id,
      schemeCode: schemeCode ?? this.schemeCode,
      isin: isin ?? this.isin,
      schemeName: schemeName ?? this.schemeName,
      amcName: amcName ?? this.amcName,
      plan: plan ?? this.plan,
      option: option ?? this.option,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (schemeCode.present) {
      map['scheme_code'] = Variable<String>(schemeCode.value);
    }
    if (isin.present) {
      map['isin'] = Variable<String>(isin.value);
    }
    if (schemeName.present) {
      map['scheme_name'] = Variable<String>(schemeName.value);
    }
    if (amcName.present) {
      map['amc_name'] = Variable<String>(amcName.value);
    }
    if (plan.present) {
      map['plan'] = Variable<String>(plan.value);
    }
    if (option.present) {
      map['option'] = Variable<String>(option.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MfCardsCompanion(')
          ..write('id: $id, ')
          ..write('schemeCode: $schemeCode, ')
          ..write('isin: $isin, ')
          ..write('schemeName: $schemeName, ')
          ..write('amcName: $amcName, ')
          ..write('plan: $plan, ')
          ..write('option: $option, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $MfTransactionsTable extends MfTransactions
    with TableInfo<$MfTransactionsTable, MfTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MfTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mf_cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<double> units = GeneratedColumn<double>(
    'units',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _navMeta = const VerificationMeta('nav');
  @override
  late final GeneratedColumn<double> nav = GeneratedColumn<double>(
    'nav',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAvgEntryMeta = const VerificationMeta(
    'isAvgEntry',
  );
  @override
  late final GeneratedColumn<bool> isAvgEntry = GeneratedColumn<bool>(
    'is_avg_entry',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_avg_entry" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    type,
    date,
    units,
    nav,
    isAvgEntry,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mf_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MfTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('units')) {
      context.handle(
        _unitsMeta,
        units.isAcceptableOrUnknown(data['units']!, _unitsMeta),
      );
    } else if (isInserting) {
      context.missing(_unitsMeta);
    }
    if (data.containsKey('nav')) {
      context.handle(
        _navMeta,
        nav.isAcceptableOrUnknown(data['nav']!, _navMeta),
      );
    } else if (isInserting) {
      context.missing(_navMeta);
    }
    if (data.containsKey('is_avg_entry')) {
      context.handle(
        _isAvgEntryMeta,
        isAvgEntry.isAcceptableOrUnknown(
          data['is_avg_entry']!,
          _isAvgEntryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MfTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MfTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      units: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}units'],
      )!,
      nav: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nav'],
      )!,
      isAvgEntry: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_avg_entry'],
      )!,
    );
  }

  @override
  $MfTransactionsTable createAlias(String alias) {
    return $MfTransactionsTable(attachedDatabase, alias);
  }
}

class MfTransaction extends DataClass implements Insertable<MfTransaction> {
  final int id;
  final int cardId;
  final String type;
  final DateTime date;
  final double units;
  final double nav;
  final bool isAvgEntry;
  const MfTransaction({
    required this.id,
    required this.cardId,
    required this.type,
    required this.date,
    required this.units,
    required this.nav,
    required this.isAvgEntry,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['type'] = Variable<String>(type);
    map['date'] = Variable<DateTime>(date);
    map['units'] = Variable<double>(units);
    map['nav'] = Variable<double>(nav);
    map['is_avg_entry'] = Variable<bool>(isAvgEntry);
    return map;
  }

  MfTransactionsCompanion toCompanion(bool nullToAbsent) {
    return MfTransactionsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      type: Value(type),
      date: Value(date),
      units: Value(units),
      nav: Value(nav),
      isAvgEntry: Value(isAvgEntry),
    );
  }

  factory MfTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MfTransaction(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<DateTime>(json['date']),
      units: serializer.fromJson<double>(json['units']),
      nav: serializer.fromJson<double>(json['nav']),
      isAvgEntry: serializer.fromJson<bool>(json['isAvgEntry']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<DateTime>(date),
      'units': serializer.toJson<double>(units),
      'nav': serializer.toJson<double>(nav),
      'isAvgEntry': serializer.toJson<bool>(isAvgEntry),
    };
  }

  MfTransaction copyWith({
    int? id,
    int? cardId,
    String? type,
    DateTime? date,
    double? units,
    double? nav,
    bool? isAvgEntry,
  }) => MfTransaction(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    type: type ?? this.type,
    date: date ?? this.date,
    units: units ?? this.units,
    nav: nav ?? this.nav,
    isAvgEntry: isAvgEntry ?? this.isAvgEntry,
  );
  MfTransaction copyWithCompanion(MfTransactionsCompanion data) {
    return MfTransaction(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      units: data.units.present ? data.units.value : this.units,
      nav: data.nav.present ? data.nav.value : this.nav,
      isAvgEntry: data.isAvgEntry.present
          ? data.isAvgEntry.value
          : this.isAvgEntry,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MfTransaction(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('units: $units, ')
          ..write('nav: $nav, ')
          ..write('isAvgEntry: $isAvgEntry')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cardId, type, date, units, nav, isAvgEntry);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MfTransaction &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.type == this.type &&
          other.date == this.date &&
          other.units == this.units &&
          other.nav == this.nav &&
          other.isAvgEntry == this.isAvgEntry);
}

class MfTransactionsCompanion extends UpdateCompanion<MfTransaction> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> type;
  final Value<DateTime> date;
  final Value<double> units;
  final Value<double> nav;
  final Value<bool> isAvgEntry;
  const MfTransactionsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.units = const Value.absent(),
    this.nav = const Value.absent(),
    this.isAvgEntry = const Value.absent(),
  });
  MfTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String type,
    required DateTime date,
    required double units,
    required double nav,
    this.isAvgEntry = const Value.absent(),
  }) : cardId = Value(cardId),
       type = Value(type),
       date = Value(date),
       units = Value(units),
       nav = Value(nav);
  static Insertable<MfTransaction> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? type,
    Expression<DateTime>? date,
    Expression<double>? units,
    Expression<double>? nav,
    Expression<bool>? isAvgEntry,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (units != null) 'units': units,
      if (nav != null) 'nav': nav,
      if (isAvgEntry != null) 'is_avg_entry': isAvgEntry,
    });
  }

  MfTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? type,
    Value<DateTime>? date,
    Value<double>? units,
    Value<double>? nav,
    Value<bool>? isAvgEntry,
  }) {
    return MfTransactionsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      type: type ?? this.type,
      date: date ?? this.date,
      units: units ?? this.units,
      nav: nav ?? this.nav,
      isAvgEntry: isAvgEntry ?? this.isAvgEntry,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (units.present) {
      map['units'] = Variable<double>(units.value);
    }
    if (nav.present) {
      map['nav'] = Variable<double>(nav.value);
    }
    if (isAvgEntry.present) {
      map['is_avg_entry'] = Variable<bool>(isAvgEntry.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MfTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('units: $units, ')
          ..write('nav: $nav, ')
          ..write('isAvgEntry: $isAvgEntry')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;

  /// Tag names are globally unique across all investment types.
  final String name;
  const Tag({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name));
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Tag copyWith({int? id, String? name}) =>
      Tag(id: id ?? this.id, name: name ?? this.name);
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag && other.id == this.id && other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  TagsCompanion.insert({this.id = const Value.absent(), required String name})
    : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  TagsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return TagsCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $CardTagsTable extends CardTags with TableInfo<$CardTagsTable, CardTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _cardTypeMeta = const VerificationMeta(
    'cardType',
  );
  @override
  late final GeneratedColumn<String> cardType = GeneratedColumn<String>(
    'card_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, tagId, cardType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('card_type')) {
      context.handle(
        _cardTypeMeta,
        cardType.isAcceptableOrUnknown(data['card_type']!, _cardTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_cardTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId, tagId, cardType};
  @override
  CardTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardTag(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
      cardType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_type'],
      )!,
    );
  }

  @override
  $CardTagsTable createAlias(String alias) {
    return $CardTagsTable(attachedDatabase, alias);
  }
}

class CardTag extends DataClass implements Insertable<CardTag> {
  final int cardId;
  final int tagId;

  /// Discriminator: "stock", "fd", "mf", etc.
  final String cardType;
  const CardTag({
    required this.cardId,
    required this.tagId,
    required this.cardType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['tag_id'] = Variable<int>(tagId);
    map['card_type'] = Variable<String>(cardType);
    return map;
  }

  CardTagsCompanion toCompanion(bool nullToAbsent) {
    return CardTagsCompanion(
      cardId: Value(cardId),
      tagId: Value(tagId),
      cardType: Value(cardType),
    );
  }

  factory CardTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardTag(
      cardId: serializer.fromJson<int>(json['cardId']),
      tagId: serializer.fromJson<int>(json['tagId']),
      cardType: serializer.fromJson<String>(json['cardType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'tagId': serializer.toJson<int>(tagId),
      'cardType': serializer.toJson<String>(cardType),
    };
  }

  CardTag copyWith({int? cardId, int? tagId, String? cardType}) => CardTag(
    cardId: cardId ?? this.cardId,
    tagId: tagId ?? this.tagId,
    cardType: cardType ?? this.cardType,
  );
  CardTag copyWithCompanion(CardTagsCompanion data) {
    return CardTag(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardTag(')
          ..write('cardId: $cardId, ')
          ..write('tagId: $tagId, ')
          ..write('cardType: $cardType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, tagId, cardType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardTag &&
          other.cardId == this.cardId &&
          other.tagId == this.tagId &&
          other.cardType == this.cardType);
}

class CardTagsCompanion extends UpdateCompanion<CardTag> {
  final Value<int> cardId;
  final Value<int> tagId;
  final Value<String> cardType;
  final Value<int> rowid;
  const CardTagsCompanion({
    this.cardId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.cardType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardTagsCompanion.insert({
    required int cardId,
    required int tagId,
    required String cardType,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       tagId = Value(tagId),
       cardType = Value(cardType);
  static Insertable<CardTag> custom({
    Expression<int>? cardId,
    Expression<int>? tagId,
    Expression<String>? cardType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (tagId != null) 'tag_id': tagId,
      if (cardType != null) 'card_type': cardType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardTagsCompanion copyWith({
    Value<int>? cardId,
    Value<int>? tagId,
    Value<String>? cardType,
    Value<int>? rowid,
  }) {
    return CardTagsCompanion(
      cardId: cardId ?? this.cardId,
      tagId: tagId ?? this.tagId,
      cardType: cardType ?? this.cardType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(cardType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardTagsCompanion(')
          ..write('cardId: $cardId, ')
          ..write('tagId: $tagId, ')
          ..write('cardType: $cardType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StockCardsTable stockCards = $StockCardsTable(this);
  late final $StockTransactionsTable stockTransactions =
      $StockTransactionsTable(this);
  late final $MfCardsTable mfCards = $MfCardsTable(this);
  late final $MfTransactionsTable mfTransactions = $MfTransactionsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $CardTagsTable cardTags = $CardTagsTable(this);
  late final StocksDao stocksDao = StocksDao(this as AppDatabase);
  late final MfDao mfDao = MfDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stockCards,
    stockTransactions,
    mfCards,
    mfTransactions,
    tags,
    cardTags,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mf_cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mf_transactions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$StockCardsTableCreateCompanionBuilder = StockCardsCompanion Function({
  Value<int> id,
  required String ticker,
  required String exchange,
  required String stockName,
  Value<double?> lastPrice,
  Value<DateTime?> lastPriceFetchedAt,
  Value<double?> prevClose,
  Value<DateTime?> dividendsFetchedUpto,
});
typedef $$StockCardsTableUpdateCompanionBuilder = StockCardsCompanion Function({
  Value<int> id,
  Value<String> ticker,
  Value<String> exchange,
  Value<String> stockName,
  Value<double?> lastPrice,
  Value<DateTime?> lastPriceFetchedAt,
  Value<double?> prevClose,
  Value<DateTime?> dividendsFetchedUpto,
});

final class $$StockCardsTableReferences
    extends BaseReferences<_$AppDatabase, $StockCardsTable, StockCard> {
  $$StockCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StockTransactionsTable, List<StockTransaction>>
  _stockTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stockTransactions,
        aliasName: 'stock_cards__id__stock_transactions__card_id',
      );

  $$StockTransactionsTableProcessedTableManager get stockTransactionsRefs {
    final manager = $$StockTransactionsTableTableManager(
      $_db,
      $_db.stockTransactions,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stockTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StockCardsTableFilterComposer
    extends Composer<_$AppDatabase, $StockCardsTable> {
  $$StockCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stockName => $composableBuilder(
    column: $table.stockName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastPrice => $composableBuilder(
    column: $table.lastPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPriceFetchedAt => $composableBuilder(
    column: $table.lastPriceFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get prevClose => $composableBuilder(
    column: $table.prevClose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dividendsFetchedUpto => $composableBuilder(
    column: $table.dividendsFetchedUpto,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> stockTransactionsRefs(
    Expression<bool> Function($$StockTransactionsTableFilterComposer f) f,
  ) {
    final $$StockTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockTransactions,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.stockTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StockCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockCardsTable> {
  $$StockCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stockName => $composableBuilder(
    column: $table.stockName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastPrice => $composableBuilder(
    column: $table.lastPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPriceFetchedAt => $composableBuilder(
    column: $table.lastPriceFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get prevClose => $composableBuilder(
    column: $table.prevClose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dividendsFetchedUpto => $composableBuilder(
    column: $table.dividendsFetchedUpto,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockCardsTable> {
  $$StockCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<String> get stockName =>
      $composableBuilder(column: $table.stockName, builder: (column) => column);

  GeneratedColumn<double> get lastPrice =>
      $composableBuilder(column: $table.lastPrice, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPriceFetchedAt => $composableBuilder(
    column: $table.lastPriceFetchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get prevClose =>
      $composableBuilder(column: $table.prevClose, builder: (column) => column);

  GeneratedColumn<DateTime> get dividendsFetchedUpto => $composableBuilder(
    column: $table.dividendsFetchedUpto,
    builder: (column) => column,
  );

  Expression<T> stockTransactionsRefs<T extends Object>(
    Expression<T> Function($$StockTransactionsTableAnnotationComposer a) f,
  ) {
    final $$StockTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stockTransactions,
          getReferencedColumn: (t) => t.cardId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StockTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.stockTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StockCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockCardsTable,
          StockCard,
          $$StockCardsTableFilterComposer,
          $$StockCardsTableOrderingComposer,
          $$StockCardsTableAnnotationComposer,
          $$StockCardsTableCreateCompanionBuilder,
          $$StockCardsTableUpdateCompanionBuilder,
          (StockCard, $$StockCardsTableReferences),
          StockCard,
          PrefetchHooks Function({bool stockTransactionsRefs})
        > {
  $$StockCardsTableTableManager(_$AppDatabase db, $StockCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ticker = const Value.absent(),
                Value<String> exchange = const Value.absent(),
                Value<String> stockName = const Value.absent(),
                Value<double?> lastPrice = const Value.absent(),
                Value<DateTime?> lastPriceFetchedAt = const Value.absent(),
                Value<double?> prevClose = const Value.absent(),
                Value<DateTime?> dividendsFetchedUpto = const Value.absent(),
              }) => StockCardsCompanion(
                id: id,
                ticker: ticker,
                exchange: exchange,
                stockName: stockName,
                lastPrice: lastPrice,
                lastPriceFetchedAt: lastPriceFetchedAt,
                prevClose: prevClose,
                dividendsFetchedUpto: dividendsFetchedUpto,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ticker,
                required String exchange,
                required String stockName,
                Value<double?> lastPrice = const Value.absent(),
                Value<DateTime?> lastPriceFetchedAt = const Value.absent(),
                Value<double?> prevClose = const Value.absent(),
                Value<DateTime?> dividendsFetchedUpto = const Value.absent(),
              }) => StockCardsCompanion.insert(
                id: id,
                ticker: ticker,
                exchange: exchange,
                stockName: stockName,
                lastPrice: lastPrice,
                lastPriceFetchedAt: lastPriceFetchedAt,
                prevClose: prevClose,
                dividendsFetchedUpto: dividendsFetchedUpto,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StockCardsTable, StockCard>(table),
                  $$StockCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stockTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (stockTransactionsRefs) db.stockTransactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stockTransactionsRefs)
                    await $_getPrefetchedData<
                      StockCard,
                      $StockCardsTable,
                      StockTransaction
                    >(
                      currentTable: table,
                      referencedTable: $$StockCardsTableReferences
                          ._stockTransactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$StockCardsTableReferences(
                            db,
                            table,
                            p0,
                          ).stockTransactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$StockCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockCardsTable,
      StockCard,
      $$StockCardsTableFilterComposer,
      $$StockCardsTableOrderingComposer,
      $$StockCardsTableAnnotationComposer,
      $$StockCardsTableCreateCompanionBuilder,
      $$StockCardsTableUpdateCompanionBuilder,
      (StockCard, $$StockCardsTableReferences),
      StockCard,
      PrefetchHooks Function({bool stockTransactionsRefs})
    >;
typedef $$StockTransactionsTableCreateCompanionBuilder =
    StockTransactionsCompanion Function({
      Value<int> id,
      required int cardId,
      required String type,
      required String entryMode,
      required DateTime date,
      required double price,
      required int quantity,
      required double totalAmount,
    });
typedef $$StockTransactionsTableUpdateCompanionBuilder =
    StockTransactionsCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<String> type,
      Value<String> entryMode,
      Value<DateTime> date,
      Value<double> price,
      Value<int> quantity,
      Value<double> totalAmount,
    });

final class $$StockTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransaction
        > {
  $$StockTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StockCardsTable _cardIdTable(_$AppDatabase db) =>
      db.stockCards.createAlias('stock_transactions__card_id__stock_cards__id');

  $$StockCardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$StockCardsTableTableManager(
      $_db,
      $_db.stockCards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryMode => $composableBuilder(
    column: $table.entryMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  $$StockCardsTableFilterComposer get cardId {
    final $$StockCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.stockCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockCardsTableFilterComposer(
            $db: $db,
            $table: $db.stockCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryMode => $composableBuilder(
    column: $table.entryMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  $$StockCardsTableOrderingComposer get cardId {
    final $$StockCardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.stockCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockCardsTableOrderingComposer(
            $db: $db,
            $table: $db.stockCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get entryMode =>
      $composableBuilder(column: $table.entryMode, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  $$StockCardsTableAnnotationComposer get cardId {
    final $$StockCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.stockCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransaction,
          $$StockTransactionsTableFilterComposer,
          $$StockTransactionsTableOrderingComposer,
          $$StockTransactionsTableAnnotationComposer,
          $$StockTransactionsTableCreateCompanionBuilder,
          $$StockTransactionsTableUpdateCompanionBuilder,
          (StockTransaction, $$StockTransactionsTableReferences),
          StockTransaction,
          PrefetchHooks Function({bool cardId})
        > {
  $$StockTransactionsTableTableManager(
    _$AppDatabase db,
    $StockTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> entryMode = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
              }) => StockTransactionsCompanion(
                id: id,
                cardId: cardId,
                type: type,
                entryMode: entryMode,
                date: date,
                price: price,
                quantity: quantity,
                totalAmount: totalAmount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String type,
                required String entryMode,
                required DateTime date,
                required double price,
                required int quantity,
                required double totalAmount,
              }) => StockTransactionsCompanion.insert(
                id: id,
                cardId: cardId,
                type: type,
                entryMode: entryMode,
                date: date,
                price: price,
                quantity: quantity,
                totalAmount: totalAmount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StockTransactionsTable, StockTransaction>(table),
                  $$StockTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$StockTransactionsTableReferences
                            ._cardIdTable(db),
                        referencedColumn: $$StockTransactionsTableReferences
                            ._cardIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StockTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockTransactionsTable,
      StockTransaction,
      $$StockTransactionsTableFilterComposer,
      $$StockTransactionsTableOrderingComposer,
      $$StockTransactionsTableAnnotationComposer,
      $$StockTransactionsTableCreateCompanionBuilder,
      $$StockTransactionsTableUpdateCompanionBuilder,
      (StockTransaction, $$StockTransactionsTableReferences),
      StockTransaction,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$MfCardsTableCreateCompanionBuilder = MfCardsCompanion Function({
  Value<int> id,
  required String schemeCode,
  required String isin,
  required String schemeName,
  required String amcName,
  required String plan,
  required String option,
  required String category,
});
typedef $$MfCardsTableUpdateCompanionBuilder = MfCardsCompanion Function({
  Value<int> id,
  Value<String> schemeCode,
  Value<String> isin,
  Value<String> schemeName,
  Value<String> amcName,
  Value<String> plan,
  Value<String> option,
  Value<String> category,
});

final class $$MfCardsTableReferences
    extends BaseReferences<_$AppDatabase, $MfCardsTable, MfCard> {
  $$MfCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MfTransactionsTable, List<MfTransaction>>
  _mfTransactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mfTransactions,
    aliasName: 'mf_cards__id__mf_transactions__card_id',
  );

  $$MfTransactionsTableProcessedTableManager get mfTransactionsRefs {
    final manager = $$MfTransactionsTableTableManager(
      $_db,
      $_db.mfTransactions,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mfTransactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MfCardsTableFilterComposer
    extends Composer<_$AppDatabase, $MfCardsTable> {
  $$MfCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isin => $composableBuilder(
    column: $table.isin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemeName => $composableBuilder(
    column: $table.schemeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amcName => $composableBuilder(
    column: $table.amcName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get option => $composableBuilder(
    column: $table.option,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mfTransactionsRefs(
    Expression<bool> Function($$MfTransactionsTableFilterComposer f) f,
  ) {
    final $$MfTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mfTransactions,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MfTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.mfTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MfCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $MfCardsTable> {
  $$MfCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isin => $composableBuilder(
    column: $table.isin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemeName => $composableBuilder(
    column: $table.schemeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amcName => $composableBuilder(
    column: $table.amcName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get option => $composableBuilder(
    column: $table.option,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MfCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MfCardsTable> {
  $$MfCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isin =>
      $composableBuilder(column: $table.isin, builder: (column) => column);

  GeneratedColumn<String> get schemeName => $composableBuilder(
    column: $table.schemeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amcName =>
      $composableBuilder(column: $table.amcName, builder: (column) => column);

  GeneratedColumn<String> get plan =>
      $composableBuilder(column: $table.plan, builder: (column) => column);

  GeneratedColumn<String> get option =>
      $composableBuilder(column: $table.option, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  Expression<T> mfTransactionsRefs<T extends Object>(
    Expression<T> Function($$MfTransactionsTableAnnotationComposer a) f,
  ) {
    final $$MfTransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mfTransactions,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MfTransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.mfTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MfCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MfCardsTable,
          MfCard,
          $$MfCardsTableFilterComposer,
          $$MfCardsTableOrderingComposer,
          $$MfCardsTableAnnotationComposer,
          $$MfCardsTableCreateCompanionBuilder,
          $$MfCardsTableUpdateCompanionBuilder,
          (MfCard, $$MfCardsTableReferences),
          MfCard,
          PrefetchHooks Function({bool mfTransactionsRefs})
        > {
  $$MfCardsTableTableManager(_$AppDatabase db, $MfCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MfCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MfCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MfCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> schemeCode = const Value.absent(),
                Value<String> isin = const Value.absent(),
                Value<String> schemeName = const Value.absent(),
                Value<String> amcName = const Value.absent(),
                Value<String> plan = const Value.absent(),
                Value<String> option = const Value.absent(),
                Value<String> category = const Value.absent(),
              }) => MfCardsCompanion(
                id: id,
                schemeCode: schemeCode,
                isin: isin,
                schemeName: schemeName,
                amcName: amcName,
                plan: plan,
                option: option,
                category: category,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String schemeCode,
                required String isin,
                required String schemeName,
                required String amcName,
                required String plan,
                required String option,
                required String category,
              }) => MfCardsCompanion.insert(
                id: id,
                schemeCode: schemeCode,
                isin: isin,
                schemeName: schemeName,
                amcName: amcName,
                plan: plan,
                option: option,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MfCardsTable, MfCard>(table),
                  $$MfCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mfTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mfTransactionsRefs) db.mfTransactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mfTransactionsRefs)
                    await $_getPrefetchedData<
                      MfCard,
                      $MfCardsTable,
                      MfTransaction
                    >(
                      currentTable: table,
                      referencedTable: $$MfCardsTableReferences
                          ._mfTransactionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$MfCardsTableReferences(
                        db,
                        table,
                        p0,
                      ).mfTransactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MfCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MfCardsTable,
      MfCard,
      $$MfCardsTableFilterComposer,
      $$MfCardsTableOrderingComposer,
      $$MfCardsTableAnnotationComposer,
      $$MfCardsTableCreateCompanionBuilder,
      $$MfCardsTableUpdateCompanionBuilder,
      (MfCard, $$MfCardsTableReferences),
      MfCard,
      PrefetchHooks Function({bool mfTransactionsRefs})
    >;
typedef $$MfTransactionsTableCreateCompanionBuilder =
    MfTransactionsCompanion Function({
      Value<int> id,
      required int cardId,
      required String type,
      required DateTime date,
      required double units,
      required double nav,
      Value<bool> isAvgEntry,
    });
typedef $$MfTransactionsTableUpdateCompanionBuilder =
    MfTransactionsCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<String> type,
      Value<DateTime> date,
      Value<double> units,
      Value<double> nav,
      Value<bool> isAvgEntry,
    });

final class $$MfTransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $MfTransactionsTable, MfTransaction> {
  $$MfTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MfCardsTable _cardIdTable(_$AppDatabase db) =>
      db.mfCards.createAlias('mf_transactions__card_id__mf_cards__id');

  $$MfCardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$MfCardsTableTableManager(
      $_db,
      $_db.mfCards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MfTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $MfTransactionsTable> {
  $$MfTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nav => $composableBuilder(
    column: $table.nav,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvgEntry => $composableBuilder(
    column: $table.isAvgEntry,
    builder: (column) => ColumnFilters(column),
  );

  $$MfCardsTableFilterComposer get cardId {
    final $$MfCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.mfCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MfCardsTableFilterComposer(
            $db: $db,
            $table: $db.mfCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MfTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MfTransactionsTable> {
  $$MfTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nav => $composableBuilder(
    column: $table.nav,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvgEntry => $composableBuilder(
    column: $table.isAvgEntry,
    builder: (column) => ColumnOrderings(column),
  );

  $$MfCardsTableOrderingComposer get cardId {
    final $$MfCardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.mfCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MfCardsTableOrderingComposer(
            $db: $db,
            $table: $db.mfCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MfTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MfTransactionsTable> {
  $$MfTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<double> get nav =>
      $composableBuilder(column: $table.nav, builder: (column) => column);

  GeneratedColumn<bool> get isAvgEntry => $composableBuilder(
    column: $table.isAvgEntry,
    builder: (column) => column,
  );

  $$MfCardsTableAnnotationComposer get cardId {
    final $$MfCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.mfCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MfCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.mfCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MfTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MfTransactionsTable,
          MfTransaction,
          $$MfTransactionsTableFilterComposer,
          $$MfTransactionsTableOrderingComposer,
          $$MfTransactionsTableAnnotationComposer,
          $$MfTransactionsTableCreateCompanionBuilder,
          $$MfTransactionsTableUpdateCompanionBuilder,
          (MfTransaction, $$MfTransactionsTableReferences),
          MfTransaction,
          PrefetchHooks Function({bool cardId})
        > {
  $$MfTransactionsTableTableManager(
    _$AppDatabase db,
    $MfTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MfTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MfTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MfTransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> units = const Value.absent(),
                Value<double> nav = const Value.absent(),
                Value<bool> isAvgEntry = const Value.absent(),
              }) => MfTransactionsCompanion(
                id: id,
                cardId: cardId,
                type: type,
                date: date,
                units: units,
                nav: nav,
                isAvgEntry: isAvgEntry,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String type,
                required DateTime date,
                required double units,
                required double nav,
                Value<bool> isAvgEntry = const Value.absent(),
              }) => MfTransactionsCompanion.insert(
                id: id,
                cardId: cardId,
                type: type,
                date: date,
                units: units,
                nav: nav,
                isAvgEntry: isAvgEntry,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MfTransactionsTable, MfTransaction>(table),
                  $$MfTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$MfTransactionsTableReferences
                            ._cardIdTable(db),
                        referencedColumn: $$MfTransactionsTableReferences
                            ._cardIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MfTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MfTransactionsTable,
      MfTransaction,
      $$MfTransactionsTableFilterComposer,
      $$MfTransactionsTableOrderingComposer,
      $$MfTransactionsTableAnnotationComposer,
      $$MfTransactionsTableCreateCompanionBuilder,
      $$MfTransactionsTableUpdateCompanionBuilder,
      (MfTransaction, $$MfTransactionsTableReferences),
      MfTransaction,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardTagsTable, List<CardTag>> _cardTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cardTags,
    aliasName: 'tags__id__card_tags__tag_id',
  );

  $$CardTagsTableProcessedTableManager get cardTagsRefs {
    final manager = $$CardTagsTableTableManager(
      $_db,
      $_db.cardTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardTagsRefs(
    Expression<bool> Function($$CardTagsTableFilterComposer f) f,
  ) {
    final $$CardTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableFilterComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> cardTagsRefs<T extends Object>(
    Expression<T> Function($$CardTagsTableAnnotationComposer a) f,
  ) {
    final $$CardTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool cardTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => TagsCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) => TagsCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardTagsRefs) db.cardTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, CardTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._cardTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).cardTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool cardTagsRefs})
    >;
typedef $$CardTagsTableCreateCompanionBuilder = CardTagsCompanion Function({
  required int cardId,
  required int tagId,
  required String cardType,
  Value<int> rowid,
});
typedef $$CardTagsTableUpdateCompanionBuilder = CardTagsCompanion Function({
  Value<int> cardId,
  Value<int> tagId,
  Value<String> cardType,
  Value<int> rowid,
});

final class $$CardTagsTableReferences
    extends BaseReferences<_$AppDatabase, $CardTagsTable, CardTag> {
  $$CardTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('card_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardTagsTableFilterComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnFilters(column),
  );

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnOrderings(column),
  );

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardTagsTable,
          CardTag,
          $$CardTagsTableFilterComposer,
          $$CardTagsTableOrderingComposer,
          $$CardTagsTableAnnotationComposer,
          $$CardTagsTableCreateCompanionBuilder,
          $$CardTagsTableUpdateCompanionBuilder,
          (CardTag, $$CardTagsTableReferences),
          CardTag,
          PrefetchHooks Function({bool tagId})
        > {
  $$CardTagsTableTableManager(_$AppDatabase db, $CardTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<String> cardType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardTagsCompanion(
                cardId: cardId,
                tagId: tagId,
                cardType: cardType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int cardId,
                required int tagId,
                required String cardType,
                Value<int> rowid = const Value.absent(),
              }) => CardTagsCompanion.insert(
                cardId: cardId,
                tagId: tagId,
                cardType: cardType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardTagsTable, CardTag>(table),
                  $$CardTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$CardTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$CardTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CardTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardTagsTable,
      CardTag,
      $$CardTagsTableFilterComposer,
      $$CardTagsTableOrderingComposer,
      $$CardTagsTableAnnotationComposer,
      $$CardTagsTableCreateCompanionBuilder,
      $$CardTagsTableUpdateCompanionBuilder,
      (CardTag, $$CardTagsTableReferences),
      CardTag,
      PrefetchHooks Function({bool tagId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StockCardsTableTableManager get stockCards =>
      $$StockCardsTableTableManager(_db, _db.stockCards);
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(_db, _db.stockTransactions);
  $$MfCardsTableTableManager get mfCards =>
      $$MfCardsTableTableManager(_db, _db.mfCards);
  $$MfTransactionsTableTableManager get mfTransactions =>
      $$MfTransactionsTableTableManager(_db, _db.mfTransactions);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$CardTagsTableTableManager get cardTags =>
      $$CardTagsTableTableManager(_db, _db.cardTags);
}
