// lib/data/local_tickers.dart
//
// Official local dataset and offline autocomplete search for NSE and BSE equities.
//
// NOTE: These lists should be refreshed periodically as new companies list,
// demerge, or get renamed on the NSE/BSE. To refresh, run:
//   dart run scripts/update_nse_tickers.dart
//   dart run scripts/update_bse_tickers.dart
//
// The scripts update assets/EQUITY_L.csv, assets/nse_tickers.json, and assets/bse_tickers.json.

import 'dart:convert';
import 'package:flutter/services.dart';

class TickerInfo {
  final String symbol;
  final String companyName;
  final String exchange;
  final String isin;
  final String? scripCode;

  const TickerInfo({
    required this.symbol,
    required this.companyName,
    required this.exchange,
    required this.isin,
    this.scripCode,
  });

  factory TickerInfo.fromJson(Map<String, dynamic> json) {
    final ex = (json['exchange'] as String?)?.trim().toUpperCase() ?? 'NSE';
    final scrip = (json['scrip_code'] as String?)?.trim();
    final rawSymbol = (json['symbol'] as String?)?.trim() ?? '';
    // For BSE, if symbol is empty, fallback to scripCode
    final sym = rawSymbol.isNotEmpty ? rawSymbol : (scrip ?? '');

    return TickerInfo(
      symbol: sym,
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      exchange: ex,
      isin: (json['isin'] as String?)?.trim() ?? '',
      scripCode: scrip,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'company_name': companyName,
        'exchange': exchange,
        'isin': isin,
        if (scripCode != null) 'scrip_code': scripCode,
      };

  /// Identifies whether this instrument is a non-stock security:
  /// Mutual Funds, ETFs, NCDs/Bonds/Debt instruments, REITs, InvITs, SGBs, etc.
  bool get isNonStockSecurity {
    final upperIsin = isin.toUpperCase();
    // In India:
    // - INF... = Mutual Funds & ETFs
    // - IN0... = Government securities / Sovereign Gold Bonds
    // - INE... = Equities and corporate bonds
    if (upperIsin.startsWith('INF') || upperIsin.startsWith('IN0')) return true;

    // BSE debt/NCD series: scrip codes starting with 9 (e.g. 93xxxx, 9xxxxx)
    if (scripCode != null && scripCode!.isNotEmpty) {
      final scripTrim = scripCode!.trim();
      if (scripTrim.startsWith('9')) return true;
    }

    final upperName = companyName.toUpperCase();
    final upperSym = symbol.toUpperCase();

    // Check REITs and InvITs
    if (upperName.contains('REIT') ||
        upperSym.contains('REIT') ||
        upperName.contains('INVIT') ||
        upperSym.contains('INVIT') ||
        upperName.contains('INFRASTRUCTURE INVESTMENT TRUST') ||
        upperName.contains('REAL ESTATE INVESTMENT TRUST')) {
      return true;
    }

    // Check NCDs, Bonds, Debentures, Debt instruments
    if (upperName.contains('NCD') ||
        upperSym.contains('NCD') ||
        upperName.contains('TAXFREE') ||
        upperSym.contains('TAXFREE') ||
        upperName.contains('DEBENTURE') ||
        upperName.contains('-BOND') ||
        upperName.endsWith(' BOND') ||
        upperName.endsWith(' BONDS') ||
        upperName.contains('SECURED REDEEMABLE') ||
        upperName.contains('UNSECURED REDEEMABLE') ||
        upperSym.endsWith('NCD') ||
        upperSym.endsWith('BOND') ||
        // Check coupon rate pattern like 7.50% or 8.05%
        RegExp(r'\d+\.?\d*%\s*-').hasMatch(upperName)) {
      return true;
    }

    // Check common mutual fund & ETF identifiers in company name or ticker symbol
    if (upperName.contains('MUTUAL FUND') ||
        upperName.contains(' ETF') ||
        upperName.startsWith('ETF ') ||
        upperName.endsWith(' ETF') ||
        upperSym.endsWith('BEES') ||
        upperSym.endsWith('IETF') ||
        upperSym.endsWith('ETF') ||
        upperName.contains('BEES') ||
        upperName.contains('SGB') ||
        upperName.contains('SOVEREIGN GOLD BOND') ||
        upperName.contains('GROWW MUTUAL') ||
        upperName.contains('KOTAK MAHINDRA MUTUAL') ||
        upperName.contains('NIPPON INDIA ETF') ||
        upperName.contains('HDFC MUTUAL FUND') ||
        upperName.contains('SBI MUTUAL FUND') ||
        upperName.contains('AXIS MUTUAL FUND') ||
        upperName.contains('UTI MUTUAL FUND') ||
        upperName.contains('ICICI PRUDENTIAL MUTUAL')) {
      return true;
    }
    return false;
  }

  /// Backward-compatible alias for [isNonStockSecurity].
  bool get isMutualFundOrEtf => isNonStockSecurity;
}

/// Internal searchable item wrapper to avoid repeated string allocations per search.
class _SearchableTicker {
  final TickerInfo ticker;
  final String upperSymbol;
  final String upperCompanyName;
  final String upperScripCode;

  _SearchableTicker(this.ticker)
      : upperSymbol = ticker.symbol.toUpperCase(),
        upperCompanyName = ticker.companyName.toUpperCase(),
        upperScripCode = (ticker.scripCode ?? '').toUpperCase();
}

List<_SearchableTicker>? _cachedSearchables;
Map<String, TickerInfo>? _symbolToTickerMap;
Map<String, TickerInfo>? _isinToTickerMap;
Future<void>? _loadingFuture;

/// Clears cached tickers so the dataset can be re-indexed.
void clearTickerCache() {
  _cachedSearchables = null;
  _symbolToTickerMap = null;
  _isinToTickerMap = null;
  _loadingFuture = null;
}

/// Initializes the local ticker index asynchronously from the bundled assets.
/// Loads both NSE and BSE datasets into a unified search index.
Future<void> ensureTickersLoaded([AssetBundle? bundle]) {
  if (_cachedSearchables != null) return Future.value();
  if (_loadingFuture != null) return _loadingFuture!;

  _loadingFuture = () async {
    final assetBundle = bundle ?? rootBundle;
    final searchables = <_SearchableTicker>[];
    final symMap = <String, TickerInfo>{};
    final isinMap = <String, TickerInfo>{};

    void processTicker(TickerInfo ticker) {
      // Exclude Mutual Funds and ETFs from the Stocks search index
      if (!ticker.isMutualFundOrEtf) {
        searchables.add(_SearchableTicker(ticker));
      }
      final ex = ticker.exchange.toUpperCase();

      // Key by symbol: $EX:$SYMBOL and naked $SYMBOL
      if (ticker.symbol.isNotEmpty) {
        final symKey = ticker.symbol.toUpperCase();
        symMap['$ex:$symKey'] = ticker;
        symMap.putIfAbsent(symKey, () => ticker);
      }
      // If BSE scrip code exists, also index by scrip code
      if (ticker.scripCode != null && ticker.scripCode!.isNotEmpty) {
        final scripKey = ticker.scripCode!.toUpperCase();
        symMap['$ex:$scripKey'] = ticker;
        symMap.putIfAbsent(scripKey, () => ticker);
      }
      if (ticker.isin.isNotEmpty) {
        final isinKey = ticker.isin.toUpperCase();
        isinMap['$ex:$isinKey'] = ticker;
        isinMap.putIfAbsent(isinKey, () => ticker);
      }
    }

    // 1. Load NSE tickers
    try {
      final nseJsonStr = await assetBundle.loadString('assets/nse_tickers.json');
      final nseRawList = jsonDecode(nseJsonStr) as List<dynamic>;
      for (final item in nseRawList) {
        processTicker(TickerInfo.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {}

    // 2. Load BSE tickers
    try {
      final bseJsonStr = await assetBundle.loadString('assets/bse_tickers.json');
      final bseRawList = jsonDecode(bseJsonStr) as List<dynamic>;
      for (final item in bseRawList) {
        processTicker(TickerInfo.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {}

    _cachedSearchables = searchables;
    _symbolToTickerMap = symMap;
    _isinToTickerMap = isinMap;
  }();

  return _loadingFuture!;
}

/// Allows manually populating or overriding the in-memory ticker list (useful for tests).
void setLocalTickersForTesting(List<TickerInfo> tickers) {
  final searchables = <_SearchableTicker>[];
  final symMap = <String, TickerInfo>{};
  final isinMap = <String, TickerInfo>{};

  for (final ticker in tickers) {
    searchables.add(_SearchableTicker(ticker));
    final ex = ticker.exchange.toUpperCase();

    if (ticker.symbol.isNotEmpty) {
      final symKey = ticker.symbol.toUpperCase();
      symMap['$ex:$symKey'] = ticker;
      symMap.putIfAbsent(symKey, () => ticker);
    }
    if (ticker.scripCode != null && ticker.scripCode!.isNotEmpty) {
      final scripKey = ticker.scripCode!.toUpperCase();
      symMap['$ex:$scripKey'] = ticker;
      symMap.putIfAbsent(scripKey, () => ticker);
    }
    if (ticker.isin.isNotEmpty) {
      final isinKey = ticker.isin.toUpperCase();
      isinMap['$ex:$isinKey'] = ticker;
      isinMap.putIfAbsent(isinKey, () => ticker);
    }
  }

  _cachedSearchables = searchables;
  _symbolToTickerMap = symMap;
  _isinToTickerMap = isinMap;
  _loadingFuture = Future.value();
}

/// Synchronously lookup ISIN for a symbol if already loaded.
String? getIsinForSymbolSync(String symbol, {String? exchange}) {
  final upper = symbol.trim().toUpperCase();
  if (exchange != null) {
    final exKey = '${exchange.trim().toUpperCase()}:$upper';
    final found = _symbolToTickerMap?[exKey];
    if (found != null) return found.isin;
  }
  return _symbolToTickerMap?[upper]?.isin;
}

/// Synchronously lookup TickerInfo for a symbol if already loaded.
TickerInfo? getTickerInfoBySymbolSync(String symbol, {String? exchange}) {
  final upper = symbol.trim().toUpperCase();
  if (exchange != null) {
    final exKey = '${exchange.trim().toUpperCase()}:$upper';
    final found = _symbolToTickerMap?[exKey];
    if (found != null) return found;
  }
  return _symbolToTickerMap?[upper];
}

/// Lookup ISIN for a symbol, ensuring the dataset is loaded.
Future<String?> getIsinForSymbol(String symbol, {String? exchange}) async {
  await ensureTickersLoaded();
  return getIsinForSymbolSync(symbol, exchange: exchange);
}

/// Lookup TickerInfo by symbol or scrip code.
Future<TickerInfo?> getTickerInfoBySymbol(String symbol, {String? exchange}) async {
  await ensureTickersLoaded();
  final upper = symbol.trim().toUpperCase();
  if (exchange != null) {
    final exKey = '${exchange.trim().toUpperCase()}:$upper';
    final found = _symbolToTickerMap?[exKey];
    if (found != null) return found;
  }
  return _symbolToTickerMap?[upper];
}

/// Lookup TickerInfo by ISIN.
Future<TickerInfo?> getTickerInfoByIsin(String isin, {String? exchange}) async {
  await ensureTickersLoaded();
  final upper = isin.trim().toUpperCase();
  if (exchange != null) {
    final exKey = '${exchange.trim().toUpperCase()}:$upper';
    final found = _isinToTickerMap?[exKey];
    if (found != null) return found;
  }
  return _isinToTickerMap?[upper];
}

/// Search tickers by prefix or substring match on symbol, scrip code, or company name.
///
/// Rules:
/// - Case-insensitive match.
/// - Matches on symbol/scripCode prefix AND company-name words (e.g. "tata motors" or "500325").
/// - Ranks symbol/scrip prefix matches first, then symbol/scrip contains, then company-name matches.
/// - When exchange is specified ('NSE' or 'BSE'), restricts results to that exchange.
/// - When searching across ALL exchanges, balances/interleaves matches so that one exchange does not crowd out the other.
/// - Capped at [limit] results (default 30).
List<TickerInfo> searchTickers(String query, {int limit = 30, String? exchange}) {
  final cleanQuery = query.trim();
  if (cleanQuery.isEmpty) return [];

  final searchables = _cachedSearchables;
  if (searchables == null || searchables.isEmpty) {
    // If not yet loaded synchronously, start load and return empty for this tick
    ensureTickersLoaded();
    return [];
  }

  final targetEx = (exchange != null && exchange != 'ALL' && exchange.isNotEmpty)
      ? exchange.toUpperCase()
      : null;

  final qUpper = cleanQuery.toUpperCase();
  final words = qUpper.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  final prefixMatches = <TickerInfo>[];
  final containsMatches = <TickerInfo>[];
  final nameMatches = <TickerInfo>[];

  for (var i = 0; i < searchables.length; i++) {
    final item = searchables[i];
    if (item.ticker.isMutualFundOrEtf) {
      continue;
    }
    if (targetEx != null && item.ticker.exchange.toUpperCase() != targetEx) {
      continue;
    }

    final sym = item.upperSymbol;
    final scrip = item.upperScripCode;
    final name = item.upperCompanyName;
    final isin = item.ticker.isin.toUpperCase();

    // 1. Symbol or Scrip Code prefix match
    if (sym.startsWith(qUpper) || (scrip.isNotEmpty && scrip.startsWith(qUpper))) {
      prefixMatches.add(item.ticker);
      continue;
    }

    // 2. ISIN match (exact, prefix, or contains)
    if (isin.isNotEmpty && (isin.startsWith(qUpper) || isin.contains(qUpper))) {
      prefixMatches.add(item.ticker);
      continue;
    }

    // 3. Symbol or Scrip Code substring match
    if (sym.contains(qUpper) || (scrip.isNotEmpty && scrip.contains(qUpper))) {
      containsMatches.add(item.ticker);
      continue;
    }

    // 4. Company name word match: all query words must appear in company name
    var matchesAllWords = true;
    for (var w = 0; w < words.length; w++) {
      if (!name.contains(words[w])) {
        matchesAllWords = false;
        break;
      }
    }

    if (matchesAllWords) {
      nameMatches.add(item.ticker);
    }
  }

  // Interleave/balance multi-exchange results so BSE tickers are not eclipsed
  List<TickerInfo> collect(List<TickerInfo> source, int maxCount) {
    if (targetEx != null || source.isEmpty) {
      return source.take(maxCount).toList();
    }
    // If searching across all exchanges, group by exchange and interleave
    final nse = source.where((t) => t.exchange.toUpperCase() == 'NSE').iterator;
    final bse = source.where((t) => t.exchange.toUpperCase() == 'BSE').iterator;
    final other = source.where((t) => t.exchange.toUpperCase() != 'NSE' && t.exchange.toUpperCase() != 'BSE').iterator;

    final out = <TickerInfo>[];
    while (out.length < maxCount) {
      var added = false;
      if (nse.moveNext()) {
        out.add(nse.current);
        added = true;
        if (out.length >= maxCount) break;
      }
      if (bse.moveNext()) {
        out.add(bse.current);
        added = true;
        if (out.length >= maxCount) break;
      }
      if (other.moveNext()) {
        out.add(other.current);
        added = true;
        if (out.length >= maxCount) break;
      }
      if (!added) break;
    }
    return out;
  }

  final results = <TickerInfo>[];
  results.addAll(collect(prefixMatches, limit));

  if (results.length < limit) {
    final remaining = limit - results.length;
    results.addAll(collect(containsMatches, remaining));
  }

  if (results.length < limit) {
    final remaining = limit - results.length;
    results.addAll(collect(nameMatches, remaining));
  }

  return results;
}
