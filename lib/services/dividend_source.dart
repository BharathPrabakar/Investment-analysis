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

/// Service to fetch and parse dividend announcements from NSE and BSE.
class DividendSource {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Optional HTTP client for dependency injection / tests.
  static http.Client? httpClient;

  /// Optional cache directory override for testing.
  static Directory? cacheDirOverrideForTesting;

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
      if (!subject.toLowerCase().contains('div')) continue;

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
}
