// lib/services/dividend_source.dart
//
// Native Dart service for fetching dividend announcements for Indian equities
// from NSE and BSE India with disk caching, browser-like headers, and fallbacks.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local_tickers.dart';

/// A single dividend announcement for a company.
class DividendEvent {
  /// Record date of the dividend.
  final DateTime recordDate;

  /// Per-share dividend amount in INR.
  final double amountPerShare;

  /// Raw description or purpose (e.g., "Interim Dividend - Rs 12 Per Share").
  final String purpose;

  /// Exchange source ("NSE" or "BSE").
  final String source;

  const DividendEvent({
    required this.recordDate,
    required this.amountPerShare,
    required this.purpose,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'recordDate': recordDate.toIso8601String(),
        'amountPerShare': amountPerShare,
        'purpose': purpose,
        'source': source,
      };

  factory DividendEvent.fromJson(Map<String, dynamic> json) => DividendEvent(
        recordDate: DateTime.parse(json['recordDate'] as String),
        amountPerShare: (json['amountPerShare'] as num).toDouble(),
        purpose: json['purpose'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );

  @override
  String toString() =>
      'DividendEvent(recordDate: ${DateFormat('yyyy-MM-dd').format(recordDate)}, amount: ₹$amountPerShare, purpose: "$purpose", source: $source)';
}

/// A single bonus issue announcement for a company.
class BonusEvent {
  /// Record date / Ex-date of the bonus issue.
  final DateTime recordDate;

  /// Number of bonus shares issued per [existingShares] held (e.g. 1 in a 1:1 or 1:2 bonus).
  final int bonusShares;

  /// Number of existing shares required (e.g. 1 in a 1:1, or 2 in a 1:2 bonus).
  final int existingShares;

  /// Raw description or purpose (e.g. "Bonus Issue 1:1").
  final String purpose;

  /// Source exchange ("NSE", "BSE", or "YAHOO").
  final String source;

  const BonusEvent({
    required this.recordDate,
    required this.bonusShares,
    required this.existingShares,
    required this.purpose,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'recordDate': recordDate.toIso8601String(),
        'bonusShares': bonusShares,
        'existingShares': existingShares,
        'purpose': purpose,
        'source': source,
      };

  factory BonusEvent.fromJson(Map<String, dynamic> json) => BonusEvent(
        recordDate: DateTime.parse(json['recordDate'] as String),
        bonusShares: json['bonusShares'] as int,
        existingShares: json['existingShares'] as int,
        purpose: json['purpose'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );

  @override
  String toString() =>
      'BonusEvent(recordDate: ${DateFormat('yyyy-MM-dd').format(recordDate)}, ratio: $bonusShares:$existingShares, purpose: "$purpose", source: $source)';
}

/// A single stock split event (sub-division of equity shares).
class SplitEvent {
  /// Record date or ex-date of the split.
  final DateTime recordDate;

  /// Old face value / denomination (e.g. 10.0 in a 10 to 2 split).
  final double oldFaceValue;

  /// New face value / denomination (e.g. 2.0 in a 10 to 2 split).
  final double newFaceValue;

  /// Raw description or purpose.
  final String purpose;

  /// Source exchange ("NSE", "BSE", or "YAHOO").
  final String source;

  const SplitEvent({
    required this.recordDate,
    required this.oldFaceValue,
    required this.newFaceValue,
    required this.purpose,
    required this.source,
  });

  /// Ratio multiplier of new shares received per 1 old share held.
  /// E.g. FV 10 -> FV 2 is multiplier 5.0 (each 1 share turns into 5 shares).
  double get multiplier => (newFaceValue > 0) ? (oldFaceValue / newFaceValue) : 1.0;

  /// Number of net new shares added per 1 old share held.
  /// E.g. FV 10 -> FV 2 adds 4 additional shares.
  int addedSharesPerExisting() {
    if (newFaceValue <= 0) return 0;
    final m = (oldFaceValue / newFaceValue).round();
    return m > 1 ? m - 1 : 0;
  }

  Map<String, dynamic> toJson() => {
        'recordDate': recordDate.toIso8601String(),
        'oldFaceValue': oldFaceValue,
        'newFaceValue': newFaceValue,
        'purpose': purpose,
        'source': source,
      };

  factory SplitEvent.fromJson(Map<String, dynamic> json) => SplitEvent(
        recordDate: DateTime.parse(json['recordDate'] as String),
        oldFaceValue: (json['oldFaceValue'] as num).toDouble(),
        newFaceValue: (json['newFaceValue'] as num).toDouble(),
        purpose: json['purpose'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );

  @override
  String toString() =>
      'SplitEvent(recordDate: ${DateFormat('yyyy-MM-dd').format(recordDate)}, FV: $oldFaceValue->$newFaceValue (x$multiplier), purpose: "$purpose", source: $source)';
}

/// Service to fetch and parse dividend and corporate action announcements from NSE, BSE, and Yahoo.
class DividendSource {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Optional HTTP client for dependency injection / tests.
  static http.Client? httpClient;

  /// Optional cache directory override for testing.
  static Directory? cacheDirOverrideForTesting;

  /// Parses stock split face values or ratio from an announcement purpose string.
  /// Examples:
  /// - "Sub-Division of Shares from Rs. 10/- to Rs. 2/-" -> (oldFaceValue: 10.0, newFaceValue: 2.0)
  /// - "Face Value Split From Rs 10 To Rs 1" -> (oldFaceValue: 10.0, newFaceValue: 1.0)
  /// - "Stock Split from Rs.5/- to Rs.1/- per share" -> (oldFaceValue: 5.0, newFaceValue: 1.0)
  /// - "Split 1:5" -> (oldFaceValue: 5.0, newFaceValue: 1.0)
  /// - "Split 1:10" -> (oldFaceValue: 10.0, newFaceValue: 1.0)
  /// - "Sub-division From Rs 10 To Re 1" -> (oldFaceValue: 10.0, newFaceValue: 1.0)
  static ({double oldFaceValue, double newFaceValue})? parseSplitRatio(String purpose) {
    if (purpose.trim().isEmpty) return null;

    final lower = purpose.toLowerCase();
    // Must contain split, sub-division / subdivision, or consolidation keywords
    final isSplitAnnouncement = lower.contains('split') ||
        lower.contains('sub-division') ||
        lower.contains('sub division') ||
        lower.contains('subdivision') ||
        lower.contains('consolidation');

    if (!isSplitAnnouncement) return null;

    // Pattern 1: "from Rs. 10/- to Rs. 2/-" or "from 10 to 2" or "from Rs 10 to Re 1"
    final fromToRegex = RegExp(
      r'from\s*(?:rs\.?|re\.?)?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:/-)?\s*to\s*(?:rs\.?|re\.?)?\s*([0-9]+(?:\.[0-9]+)?)(?:\s*(?:/-)?\s*per\s*share)?',
      caseSensitive: false,
    );
    final ftMatch = fromToRegex.firstMatch(purpose);
    if (ftMatch != null) {
      final oldFv = double.tryParse(ftMatch.group(1) ?? '');
      final newFv = double.tryParse(ftMatch.group(2) ?? '');
      if (oldFv != null && newFv != null && oldFv > 0 && newFv > 0 && oldFv != newFv) {
        return (oldFaceValue: oldFv, newFaceValue: newFv);
      }
    }

    // Pattern 2: "Rs. 10/- to Rs. 2/-" without 'from'
    final bareToRegex = RegExp(
      r'(?:rs\.?|re\.?)\s*([0-9]+(?:\.[0-9]+)?)\s*(?:/-)?\s*to\s*(?:rs\.?|re\.?)?\s*([0-9]+(?:\.[0-9]+)?)(?:\s*(?:/-)?\s*per\s*share)?',
      caseSensitive: false,
    );
    final btMatch = bareToRegex.firstMatch(purpose);
    if (btMatch != null) {
      final oldFv = double.tryParse(btMatch.group(1) ?? '');
      final newFv = double.tryParse(btMatch.group(2) ?? '');
      if (oldFv != null && newFv != null && oldFv > 0 && newFv > 0 && oldFv != newFv) {
        return (oldFaceValue: oldFv, newFaceValue: newFv);
      }
    }

    // Pattern 3: "split 1:5", "subdivision 1:10", "split 10:1", "consolidation 10:1"
    final ratioRegex = RegExp(
      r'(?:split|sub-?division|consolidation).*?\b(\d+)\s*:\s*(\d+)\b',
      caseSensitive: false,
    );
    final rMatch = ratioRegex.firstMatch(purpose);
    if (rMatch != null) {
      final part1 = double.tryParse(rMatch.group(1) ?? '');
      final part2 = double.tryParse(rMatch.group(2) ?? '');
      if (part1 != null && part2 != null) {
        if (lower.contains('consolidation')) {
          // Consolidation 10:1 merges 10 into 1 -> oldFv: 1, newFv: 10
          if (part1 > part2 && part2 > 0) {
            return (oldFaceValue: 1.0, newFaceValue: part1 / part2);
          }
        } else {
          if (part2 > part1 && part1 > 0) {
            // 1:5 split -> multiplier is part2 / part1
            return (oldFaceValue: part2 / part1, newFaceValue: 1.0);
          } else if (part1 > part2 && part2 > 0) {
            // 5:1 split -> multiplier is part1 / part2
            return (oldFaceValue: part1 / part2, newFaceValue: 1.0);
          }
        }
      }
    }

    return null;
  }

  /// Parses bonus ratio from an announcement purpose string.
  /// Examples:
  /// - "Bonus Issue 1:1" -> (bonus: 1, existing: 1)
  /// - "Bonus 1:2" -> (bonus: 1, existing: 2)
  /// - "Bonus 2:1" -> (bonus: 2, existing: 1)
  /// - "Bonus Issue 4:3" -> (bonus: 4, existing: 3)
  static ({int bonus, int existing})? parseBonusRatio(String purpose) {
    if (purpose.trim().isEmpty) return null;
    final regex = RegExp(
      r'bonus.*?\b(\d+)\s*:\s*(\d+)\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(purpose);
    if (match != null) {
      final b = int.tryParse(match.group(1) ?? '');
      final e = int.tryParse(match.group(2) ?? '');
      if (b != null && e != null && b > 0 && e > 0) {
        return (bonus: b, existing: e);
      }
    }
    return null;
  }

  /// Parses per-share dividend amount from an announcement description string.
  /// Examples:
  /// - "Dividend - Rs 6 Per Share" -> 6.0
  /// - "Interim Dividend - Rs 12 Per Share" -> 12.0
  /// - "Interim Dividend - Rs 5.50  Per Share" -> 5.5
  /// - "Dividend - Re 1 Per Share" -> 1.0
  /// - "Interim Dividend Rs 11 Per Share/ Special Dividend Rs 46 Per Share" -> 57.0 (sum of both)
  /// - "Special Dividend - Rs 46 Per Share" -> 46.0
  static double? parseDividendAmount(String purpose) {
    if (purpose.trim().isEmpty) return null;

    final lower = purpose.toLowerCase();
    // Guard against stock split/sub-division announcements being misparsed as dividends
    final hasSplitKeywords = lower.contains('split') ||
        lower.contains('sub-division') ||
        lower.contains('sub division') ||
        lower.contains('subdivision');
    // Note: Do NOT use .contains('div') because 'sub-division' contains 'div'!
    final hasDividendKeywords = lower.contains('dividend') ||
        lower.contains('interim') ||
        lower.contains('final') ||
        RegExp(r'\bdiv\b').hasMatch(lower);

    if (hasSplitKeywords && !hasDividendKeywords) {
      return null;
    }

    // Look for Rs. / Rs / Re. / Re followed by a decimal number and optionally "Per Share"
    // Regex matches e.g. "Rs 12", "Rs. 5.50", "Re 1", "Re. 0.50"
    final regex = RegExp(
      r'(?:rs\.?|re\.?)\s*([0-9]+(?:\.[0-9]+)?)(?:\s*(?:/-)?\s*per\s*share)?',
      caseSensitive: false,
    );

    final matches = regex.allMatches(purpose).toList();
    if (matches.isEmpty) {
      // Fallback: look for "Amount: X" or bare "X per share"
      final bareRegex = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*per\s*share', caseSensitive: false);
      final bareMatches = bareRegex.allMatches(purpose).toList();
      if (bareMatches.isNotEmpty) {
        double sum = 0;
        for (final m in bareMatches) {
          final val = double.tryParse(m.group(1) ?? '');
          if (val != null) sum += val;
        }
        return sum > 0 ? sum : null;
      }
      return null;
    }

    double total = 0;
    for (final m in matches) {
      final val = double.tryParse(m.group(1) ?? '');
      if (val != null) total += val;
    }

    return total > 0 ? total : null;
  }

  /// Parses date string in common Indian market formats:
  /// - "15-Jul-2026" / "15-JUL-2026"
  /// - "05 Jun 2026"
  /// - "2026-07-15"
  /// - "15/07/2026"
  static DateTime? parseMarketDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr.trim() == '-') {
      return null;
    }
    final clean = dateStr.trim();
    final formats = [
      'dd-MMM-yyyy',
      'dd MMM yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'd-MMM-yyyy',
      'd MMM yyyy',
    ];

    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt, 'en_US').parseLoose(clean);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }
    return null;
  }

  static Future<Directory> _getCacheDirectory() async {
    if (cacheDirOverrideForTesting != null) {
      return cacheDirOverrideForTesting!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/dividend_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Fetches historical dividends for [ticker] on [exchange] ("NSE" or "BSE").
  ///
  /// Caches past dividends permanently to disk for reliability and offline support.
  /// If the network fetch fails, returns any cached dividends.
  /// If network succeeds, merges newly fetched dividends into cache and returns.
  static Future<List<DividendEvent>> fetchDividends(
    String ticker, {
    String exchange = 'NSE',
    String? scripCode,
  }) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final cleanExchange = exchange.trim().toUpperCase();

    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/div_${cleanExchange}_$cleanTicker.json');

    List<DividendEvent> cached = [];
    if (await cacheFile.exists()) {
      try {
        final jsonStr = await cacheFile.readAsString();
        final rawList = jsonDecode(jsonStr) as List<dynamic>;
        cached = rawList
            .map((e) => DividendEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        developer.log('Error reading dividend cache for $cleanTicker: $e', name: 'DividendSource');
      }
    }

    try {
      final List<DividendEvent> fetched;
      if (cleanExchange == 'BSE') {
        fetched = await _fetchBseDividends(cleanTicker, scripCode: scripCode);
      } else {
        fetched = await _fetchNseDividends(cleanTicker);
      }

      // Merge fetched events with cached (deduplicate by recordDate + amountPerShare)
      final map = <String, DividendEvent>{};
      for (final ev in cached) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.amountPerShare.toStringAsFixed(4)}';
        map[key] = ev;
      }
      for (final ev in fetched) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.amountPerShare.toStringAsFixed(4)}';
        map[key] = ev;
      }

      final merged = map.values.toList()
        ..sort((a, b) => a.recordDate.compareTo(b.recordDate));

      // Save merged back to cache
      await cacheFile.writeAsString(jsonEncode(merged.map((e) => e.toJson()).toList()));
      return merged;
    } catch (e) {
      developer.log('Dividend fetch failed for $cleanTicker ($cleanExchange): $e', name: 'DividendSource');
      // Graceful degradation: return cached data on failure
      return cached;
    }
  }

  // ─── NSE Fetcher ─────────────────────────────────────────────────────────────

  static Future<List<DividendEvent>> _fetchNseDividends(String symbol) async {
    final client = httpClient ?? http.Client();
    final baseUri = Uri.parse('https://www.nseindia.com');

    // 1. Warm up session cookie by visiting NSE homepage
    final cookieMap = <String, String>{};
    try {
      final warmResp = await client.get(
        baseUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(timeoutDuration);

      final rawCookie = warmResp.headers['set-cookie'];
      if (rawCookie != null) {
        for (final piece in rawCookie.split(',')) {
          final firstPart = piece.split(';').first.trim();
          final eqIdx = firstPart.indexOf('=');
          if (eqIdx > 0) {
            cookieMap[firstPart.substring(0, eqIdx).trim()] =
                firstPart.substring(eqIdx + 1).trim();
          }
        }
      }
    } catch (e) {
      developer.log('NSE session warm up warning: $e', name: 'DividendSource');
    }

    final cookieHeader = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

    // 2. Query corporateActions endpoint
    final apiUri = Uri.parse(
        'https://www.nseindia.com/api/corporates-corporateActions?index=equities&symbol=${Uri.encodeComponent(symbol)}');

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.nseindia.com/',
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) {
      throw HttpException('NSE corporateActions returned HTTP ${apiResp.statusCode}');
    }

    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map && rawData.containsKey('data')) {
      list = rawData['data'] as List<dynamic>;
    } else {
      list = [];
    }

    final events = <DividendEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final subject = (item['subject'] ?? item['purpose'] ?? '').toString();
      final subLower = subject.toLowerCase();
      // Must explicitly mention dividend, interim, special div, or div - not bare "sub-division"
      final isSubDivision = subLower.contains('sub-division') ||
          subLower.contains('sub division') ||
          subLower.contains('subdivision');
      final isRealDiv = subLower.contains('dividend') ||
          subLower.contains('interim') ||
          subLower.contains('final') ||
          subLower.contains('special') ||
          RegExp(r'\bdiv\b').hasMatch(subLower);

      if (!isRealDiv || (isSubDivision && !subLower.contains('dividend'))) {
        continue;
      }

      final amount = parseDividendAmount(subject);
      if (amount == null || amount <= 0) continue;

      // Use recDate if available, fallback to exDate
      final recDateStr = (item['recDate'] ?? item['recDt'])?.toString();
      final exDateStr = (item['exDate'] ?? item['exDt'])?.toString();

      final recordDate = parseMarketDate(recDateStr) ?? parseMarketDate(exDateStr);
      if (recordDate == null) continue;

      events.add(DividendEvent(
        recordDate: recordDate,
        amountPerShare: amount,
        purpose: subject,
        source: 'NSE',
      ));
    }

    return events;
  }

  // ─── BSE Fetcher ─────────────────────────────────────────────────────────────

  static Future<List<DividendEvent>> _fetchBseDividends(
    String ticker, {
    String? scripCode,
  }) async {
    String? effectiveScrip = scripCode;
    if (effectiveScrip == null || effectiveScrip.isEmpty) {
      final info = await getTickerInfoBySymbol(ticker, exchange: 'BSE');
      effectiveScrip = info?.scripCode ?? (int.tryParse(ticker) != null ? ticker : null);
    }

    if (effectiveScrip == null || effectiveScrip.isEmpty) {
      throw ArgumentError('BSE dividend fetch requires numeric scripCode for $ticker');
    }

    final client = httpClient ?? http.Client();

    // 1. Warm up by visiting BSE corporate actions page
    final warmUri = Uri.parse('https://www.bseindia.com/corporates/corporate_act.aspx');
    final cookieMap = <String, String>{};
    try {
      final warmResp = await client.get(
        warmUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(timeoutDuration);

      final rawCookie = warmResp.headers['set-cookie'];
      if (rawCookie != null) {
        for (final piece in rawCookie.split(',')) {
          final firstPart = piece.split(';').first.trim();
          final eqIdx = firstPart.indexOf('=');
          if (eqIdx > 0) {
            cookieMap[firstPart.substring(0, eqIdx).trim()] =
                firstPart.substring(eqIdx + 1).trim();
          }
        }
      }
    } catch (e) {
      developer.log('BSE session warm up warning: $e', name: 'DividendSource');
    }

    final cookieHeader = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

    // 2. Fetch corporate action from BSE API
    final apiUri = Uri.parse(
      'https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w?'
      'strCat=D&strPrevDate=20150101&strScrip=&strSearch=S&strToDate=20301231&strType=C&scripcode=$effectiveScrip',
    );

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
        'Origin': 'https://www.bseindia.com',
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) {
      throw HttpException('BSE CorporateAction API returned HTTP ${apiResp.statusCode}');
    }

    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list;
    if (rawData is Map && rawData.containsKey('Table')) {
      list = rawData['Table'] as List<dynamic>? ?? [];
    } else if (rawData is List) {
      list = rawData;
    } else {
      list = [];
    }

    final events = <DividendEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final purpose = (item['purpose_name'] ?? item['Purpose'] ?? '').toString();

      // Amount might be a numeric field in BSE JSON or embedded in purpose string
      double? amount;
      if (item['Amount'] != null) {
        amount = (item['Amount'] as num?)?.toDouble();
      }
      amount ??= parseDividendAmount(purpose);

      if (amount == null || amount <= 0) continue;

      // Date field in BSE: BCRD_from or RD_DATE or RecordDate
      final dateStr = (item['BCRD_from'] ?? item['RD_DATE'] ?? item['RecordDate'])?.toString();
      final recordDate = parseMarketDate(dateStr);
      if (recordDate == null) continue;

      events.add(DividendEvent(
        recordDate: recordDate,
        amountPerShare: amount,
        purpose: purpose.isNotEmpty ? purpose : 'Dividend',
        source: 'BSE',
      ));
    }

    return events;
  }

  // ─── Bonus Issues Fetcher ────────────────────────────────────────────────────

  /// Fetches historical bonus issue announcements for [ticker] on [exchange].
  ///
  /// Uses disk cache for offline access and queries NSE/BSE corporate actions,
  /// falling back to Yahoo Finance splits/bonus data.
  static Future<List<BonusEvent>> fetchBonusIssues(
    String ticker, {
    String exchange = 'NSE',
    String? scripCode,
  }) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final cleanExchange = exchange.trim().toUpperCase();

    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bonus_${cleanExchange}_$cleanTicker.json');

    List<BonusEvent> cached = [];
    if (await cacheFile.exists()) {
      try {
        final jsonStr = await cacheFile.readAsString();
        final rawList = jsonDecode(jsonStr) as List<dynamic>;
        cached = rawList
            .map((e) => BonusEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        developer.log('Error reading bonus cache for $cleanTicker: $e', name: 'DividendSource');
      }
    }

    try {
      final List<BonusEvent> fetched = [];

      // 1. Try Exchange Corporate Actions
      try {
        if (cleanExchange == 'BSE') {
          fetched.addAll(await _fetchBseBonus(cleanTicker, scripCode: scripCode));
        } else {
          fetched.addAll(await _fetchNseBonus(cleanTicker));
        }
      } catch (e) {
        developer.log('Exchange bonus fetch failed for $cleanTicker: $e', name: 'DividendSource');
      }

      // 2. Query Yahoo Finance fallback ONLY for dates not identified as Stock Splits
      // Note: Yahoo represents both bonus issues and splits under events=split.
      // Exchange corporate action feeds (NSE/BSE) are the authoritative source.
      try {
        final splitEvents = await fetchStockSplits(cleanTicker, exchange: cleanExchange, scripCode: scripCode);
        final yEvents = await _fetchYahooBonus(cleanTicker, exchange: cleanExchange);
        for (final yb in yEvents) {
          final alreadyPresentInBonus = fetched.any((fb) =>
              fb.recordDate.year == yb.recordDate.year &&
              fb.recordDate.month == yb.recordDate.month &&
              (fb.recordDate.day - yb.recordDate.day).abs() <= 2);
          final isActuallySplit = splitEvents.any((sp) =>
              sp.recordDate.year == yb.recordDate.year &&
              sp.recordDate.month == yb.recordDate.month &&
              (sp.recordDate.day - yb.recordDate.day).abs() <= 2);
          if (!alreadyPresentInBonus && !isActuallySplit) {
            fetched.add(yb);
          }
        }
      } catch (e) {
        developer.log('Yahoo bonus fetch error for $cleanTicker: $e', name: 'DividendSource');
      }

      // Merge fetched with cached
      final map = <String, BonusEvent>{};
      for (final ev in cached) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.bonusShares}_${ev.existingShares}';
        map[key] = ev;
      }
      for (final ev in fetched) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.bonusShares}_${ev.existingShares}';
        map[key] = ev;
      }

      final merged = map.values.toList()
        ..sort((a, b) => a.recordDate.compareTo(b.recordDate));

      if (merged.isNotEmpty) {
        await cacheFile.writeAsString(jsonEncode(merged.map((e) => e.toJson()).toList()));
      }
      return merged.isNotEmpty ? merged : cached;
    } catch (e) {
      return cached;
    }
  }

  static Future<List<BonusEvent>> _fetchNseBonus(String symbol) async {
    final client = httpClient ?? http.Client();
    final apiUri = Uri.parse(
        'https://www.nseindia.com/api/corporates-corporateActions?index=equities&symbol=${Uri.encodeComponent(symbol)}');

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Referer': 'https://www.nseindia.com/',
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) return [];
    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map && rawData.containsKey('data')) {
      list = rawData['data'] as List<dynamic>;
    } else {
      list = [];
    }

    final events = <BonusEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final subject = (item['subject'] ?? item['purpose'] ?? '').toString();
      final ratio = parseBonusRatio(subject);
      if (ratio == null) continue;

      final recDateStr = (item['recDate'] ?? item['recDt'])?.toString();
      final exDateStr = (item['exDate'] ?? item['exDt'])?.toString();
      final recordDate = parseMarketDate(recDateStr) ?? parseMarketDate(exDateStr);
      if (recordDate == null) continue;

      events.add(BonusEvent(
        recordDate: recordDate,
        bonusShares: ratio.bonus,
        existingShares: ratio.existing,
        purpose: subject,
        source: 'NSE',
      ));
    }
    return events;
  }

  static Future<List<BonusEvent>> _fetchBseBonus(
    String ticker, {
    String? scripCode,
  }) async {
    String? effectiveScrip = scripCode;
    if (effectiveScrip == null || effectiveScrip.isEmpty) {
      final info = await getTickerInfoBySymbol(ticker, exchange: 'BSE');
      effectiveScrip = info?.scripCode ?? (int.tryParse(ticker) != null ? ticker : null);
    }
    if (effectiveScrip == null || effectiveScrip.isEmpty) return [];

    final client = httpClient ?? http.Client();
    final apiUri = Uri.parse(
      'https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w?'
      'strCat=B&strPrevDate=20150101&strScrip=&strSearch=S&strToDate=20301231&strType=C&scripcode=$effectiveScrip',
    );

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) return [];
    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list = rawData is Map && rawData.containsKey('Table')
        ? (rawData['Table'] as List<dynamic>? ?? [])
        : (rawData is List ? rawData : []);

    final events = <BonusEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final purpose = (item['purpose_name'] ?? item['Purpose'] ?? '').toString();
      final ratio = parseBonusRatio(purpose);
      if (ratio == null) continue;

      final dateStr = (item['BCRD_from'] ?? item['RD_DATE'] ?? item['RecordDate'])?.toString();
      final recordDate = parseMarketDate(dateStr);
      if (recordDate == null) continue;

      events.add(BonusEvent(
        recordDate: recordDate,
        bonusShares: ratio.bonus,
        existingShares: ratio.existing,
        purpose: purpose,
        source: 'BSE',
      ));
    }
    return events;
  }

  static Future<List<BonusEvent>> _fetchYahooBonus(
    String ticker, {
    String exchange = 'NSE',
  }) async {
    final suffix = exchange.toUpperCase() == 'BSE' ? '.BO' : '.NS';
    final symbol = '$ticker$suffix';
    final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1mo&range=10y&events=split');

    final client = httpClient ?? http.Client();
    final resp = await client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    ).timeout(timeoutDuration);

    if (resp.statusCode != 200) return [];
    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    final chart = jsonMap['chart'] as Map<String, dynamic>?;
    final results = chart?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) return [];

    final eventsMap = results.first['events'] as Map<String, dynamic>?;
    final splitsMap = eventsMap?['splits'] as Map<String, dynamic>?;
    if (splitsMap == null || splitsMap.isEmpty) return [];

    final list = <BonusEvent>[];
    for (final entry in splitsMap.values) {
      if (entry is Map<String, dynamic>) {
        final timestamp = entry['date'] as num?;
        final numVal = (entry['numerator'] as num?)?.toInt() ?? 0;
        final denVal = (entry['denominator'] as num?)?.toInt() ?? 0;
        final splitRatio = (entry['splitRatio'] as String?) ?? '';

        if (timestamp != null && numVal > denVal && denVal > 0) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
          final bonus = numVal - denVal;
          list.add(BonusEvent(
            recordDate: DateTime(date.year, date.month, date.day),
            bonusShares: bonus,
            existingShares: denVal,
            purpose: 'Bonus Issue $bonus:$denVal ($splitRatio)',
            source: 'YAHOO',
          ));
        }
      }
    }
    return list;
  }

  // ─── Stock Splits Fetcher ──────────────────────────────────────────────────

  /// Fetches historical stock splits for [ticker] on [exchange] ("NSE" or "BSE").
  ///
  /// Caches past splits permanently to disk for reliability and offline support.
  /// Deduplicates across NSE, BSE, and Yahoo Finance feeds.
  static Future<List<SplitEvent>> fetchStockSplits(
    String ticker, {
    String exchange = 'NSE',
    String? scripCode,
  }) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final cleanExchange = exchange.trim().toUpperCase();

    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/split_${cleanExchange}_$cleanTicker.json');

    List<SplitEvent> cached = [];
    if (await cacheFile.exists()) {
      try {
        final jsonStr = await cacheFile.readAsString();
        final rawList = jsonDecode(jsonStr) as List<dynamic>;
        cached = rawList
            .map((e) => SplitEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        developer.log('Error reading split cache for $cleanTicker: $e', name: 'DividendSource');
      }
    }

    try {
      final List<SplitEvent> fetched = [];

      // 1. Try Exchange Corporate Actions
      try {
        if (cleanExchange == 'BSE') {
          fetched.addAll(await _fetchBseSplits(cleanTicker, scripCode: scripCode));
        } else {
          fetched.addAll(await _fetchNseSplits(cleanTicker));
        }
      } catch (e) {
        developer.log('Exchange split fetch failed for $cleanTicker: $e', name: 'DividendSource');
      }

      // 2. Query Yahoo Finance fallback
      try {
        final yEvents = await _fetchYahooSplits(cleanTicker, exchange: cleanExchange);
        for (final yb in yEvents) {
          final alreadyPresent = fetched.any((fb) =>
              fb.recordDate.year == yb.recordDate.year &&
              fb.recordDate.month == yb.recordDate.month &&
              (fb.recordDate.day - yb.recordDate.day).abs() <= 2);
          if (!alreadyPresent) {
            fetched.add(yb);
          }
        }
      } catch (e) {
        developer.log('Yahoo split fetch error for $cleanTicker: $e', name: 'DividendSource');
      }

      // Merge fetched with cached
      final map = <String, SplitEvent>{};
      for (final ev in cached) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.oldFaceValue}_${ev.newFaceValue}';
        map[key] = ev;
      }
      for (final ev in fetched) {
        final key = '${DateFormat('yyyyMMdd').format(ev.recordDate)}_${ev.oldFaceValue}_${ev.newFaceValue}';
        map[key] = ev;
      }

      final merged = map.values.toList()
        ..sort((a, b) => a.recordDate.compareTo(b.recordDate));

      if (merged.isNotEmpty) {
        await cacheFile.writeAsString(jsonEncode(merged.map((e) => e.toJson()).toList()));
      }
      return merged.isNotEmpty ? merged : cached;
    } catch (e) {
      return cached;
    }
  }

  static Future<List<SplitEvent>> _fetchNseSplits(String symbol) async {
    final client = httpClient ?? http.Client();
    final apiUri = Uri.parse(
        'https://www.nseindia.com/api/corporates-corporateActions?index=equities&symbol=${Uri.encodeComponent(symbol)}');

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Referer': 'https://www.nseindia.com/',
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) return [];
    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map && rawData.containsKey('data')) {
      list = rawData['data'] as List<dynamic>;
    } else {
      list = [];
    }

    final events = <SplitEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final subject = (item['subject'] ?? item['purpose'] ?? '').toString();
      final ratio = parseSplitRatio(subject);
      if (ratio == null) continue;

      final recDateStr = (item['recDate'] ?? item['recDt'])?.toString();
      final exDateStr = (item['exDate'] ?? item['exDt'])?.toString();
      final recordDate = parseMarketDate(recDateStr) ?? parseMarketDate(exDateStr);
      if (recordDate == null) continue;

      events.add(SplitEvent(
        recordDate: recordDate,
        oldFaceValue: ratio.oldFaceValue,
        newFaceValue: ratio.newFaceValue,
        purpose: subject,
        source: 'NSE',
      ));
    }
    return events;
  }

  static Future<List<SplitEvent>> _fetchBseSplits(
    String ticker, {
    String? scripCode,
  }) async {
    String? effectiveScrip = scripCode;
    if (effectiveScrip == null || effectiveScrip.isEmpty) {
      final info = await getTickerInfoBySymbol(ticker, exchange: 'BSE');
      effectiveScrip = info?.scripCode ?? (int.tryParse(ticker) != null ? ticker : null);
    }
    if (effectiveScrip == null || effectiveScrip.isEmpty) return [];

    final client = httpClient ?? http.Client();
    final apiUri = Uri.parse(
      'https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w?'
      'strCat=S&strPrevDate=20150101&strScrip=&strSearch=S&strToDate=20301231&strType=C&scripcode=$effectiveScrip',
    );

    final apiResp = await client.get(
      apiUri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
      },
    ).timeout(timeoutDuration);

    if (apiResp.statusCode != 200) return [];
    final rawData = jsonDecode(apiResp.body);
    final List<dynamic> list = rawData is Map && rawData.containsKey('Table')
        ? (rawData['Table'] as List<dynamic>? ?? [])
        : (rawData is List ? rawData : []);

    final events = <SplitEvent>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final purpose = (item['purpose_name'] ?? item['Purpose'] ?? '').toString();
      final ratio = parseSplitRatio(purpose);
      if (ratio == null) continue;

      final dateStr = (item['BCRD_from'] ?? item['RD_DATE'] ?? item['RecordDate'])?.toString();
      final recordDate = parseMarketDate(dateStr);
      if (recordDate == null) continue;

      events.add(SplitEvent(
        recordDate: recordDate,
        oldFaceValue: ratio.oldFaceValue,
        newFaceValue: ratio.newFaceValue,
        purpose: purpose,
        source: 'BSE',
      ));
    }
    return events;
  }

  static Future<List<SplitEvent>> _fetchYahooSplits(
    String ticker, {
    String exchange = 'NSE',
  }) async {
    final suffix = exchange.toUpperCase() == 'BSE' ? '.BO' : '.NS';
    final symbol = '$ticker$suffix';
    final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1mo&range=10y&events=split');

    final client = httpClient ?? http.Client();
    final resp = await client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    ).timeout(timeoutDuration);

    if (resp.statusCode != 200) return [];
    final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    final chart = jsonMap['chart'] as Map<String, dynamic>?;
    final results = chart?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) return [];

    final eventsMap = results.first['events'] as Map<String, dynamic>?;
    final splitsMap = eventsMap?['splits'] as Map<String, dynamic>?;
    if (splitsMap == null || splitsMap.isEmpty) return [];

    final list = <SplitEvent>[];
    for (final entry in splitsMap.values) {
      if (entry is Map<String, dynamic>) {
        final timestamp = entry['date'] as num?;
        final numVal = (entry['numerator'] as num?)?.toDouble() ?? 0.0;
        final denVal = (entry['denominator'] as num?)?.toDouble() ?? 0.0;
        final splitRatio = (entry['splitRatio'] as String?) ?? '';

        if (timestamp != null && numVal > denVal && denVal > 0) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
          list.add(SplitEvent(
            recordDate: DateTime(date.year, date.month, date.day),
            oldFaceValue: numVal,
            newFaceValue: denVal,
            purpose: 'Stock Split $numVal:$denVal ($splitRatio)',
            source: 'YAHOO',
          ));
        }
      }
    }
    return list;
  }
}
