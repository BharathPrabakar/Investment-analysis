// lib/services/bse_bhavcopy_source.dart
//
// BSE UDiFF Equity Bhavcopy parser and downloader for past trading days.
// Matches rows primarily by scrip code (FinInstrmId), then by symbol (TckrSymb),
// and cross-checks with ISIN. Extracts that day's HghPric and LwPric.

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local_tickers.dart';
import '../utils/app_constants.dart';
import 'price_service.dart';

class _BseDayBhavcopyData {
  final Map<String, PriceRange> scripCodeToRange;
  final Map<String, PriceRange> symbolToRange;
  final Map<String, PriceRange> isinToRange;

  const _BseDayBhavcopyData({
    required this.scripCodeToRange,
    required this.symbolToRange,
    required this.isinToRange,
  });

  PriceRange? find({String? scripCode, String? symbol, String? isin}) {
    if (scripCode != null && scripCode.isNotEmpty) {
      final range = scripCodeToRange[scripCode.trim().toUpperCase()];
      if (range != null) return range;
    }
    if (symbol != null && symbol.isNotEmpty) {
      final range = symbolToRange[symbol.trim().toUpperCase()];
      if (range != null) return range;
    }
    if (isin != null && isin.isNotEmpty) {
      final range = isinToRange[isin.trim().toUpperCase()];
      if (range != null) return range;
    }
    return null;
  }
}

class BseBhavcopySource {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Optional HTTP client for testing
  static http.Client? httpClient;

  /// Optional cache directory override for testing
  static Directory? cacheDirOverrideForTesting;

  // In-memory cache for fast lookup during the current app run: "YYYYMMDD" -> _BseDayBhavcopyData
  static final Map<String, _BseDayBhavcopyData> _memoryCache = {};

  /// BSE migrated to UDiFF format in 2024. Prior dates use legacy EQ{DD}{MM}{YY}_CSV.ZIP.
  static final DateTime bseUdiffCutoff = kBseUdiffCutoff;

  static String getBseBhavcopyUrl(DateTime date) {
    if (!date.isBefore(bseUdiffCutoff)) {
      final dateKey = _formatDate(date);
      return 'https://www.bseindia.com/download/BhavCopy/Equity/BhavCopy_BSE_CM_0_0_0_${dateKey}_F_0000.CSV';
    } else {
      final dd = DateFormat('dd').format(date);
      final mm = DateFormat('MM').format(date);
      final yy = DateFormat('yy').format(date);
      return 'https://www.bseindia.com/download/BhavCopy/Equity/EQ$dd$mm${yy}_CSV.ZIP';
    }
  }

  /// Format date as YYYYMMDD
  static String _formatDate(DateTime date) => DateFormat('yyyyMMdd').format(date);

  /// Fetch price range for [tickerOrScrip] on past trading date [date].
  /// Matches by scrip code (primary), then ticker symbol, then ISIN.
  static Future<PriceRange> fetchDayPriceRange(
    String tickerOrScrip,
    DateTime date, {
    String? isin,
  }) async {
    final dateKey = _formatDate(date);
    final target = tickerOrScrip.trim().toUpperCase();

    // Resolve scripCode and ISIN from local ticker info if target is a symbol
    final info = await getTickerInfoBySymbol(target, exchange: 'BSE');
    final targetScrip = info?.scripCode?.toUpperCase() ?? (int.tryParse(target) != null ? target : null);
    final targetIsin = (isin?.trim().isNotEmpty == true)
        ? isin!.trim().toUpperCase()
        : (info?.isin.toUpperCase() ?? (await getIsinForSymbol(target, exchange: 'BSE'))?.toUpperCase());

    // 1. Check in-memory cache
    if (_memoryCache.containsKey(dateKey)) {
      final dayData = _memoryCache[dateKey]!;
      final range = dayData.find(
        scripCode: targetScrip ?? target,
        symbol: target,
        isin: targetIsin,
      );
      if (range != null) return range;
      throw PriceFetchException(
          'BSE stock $target (${targetIsin ?? "no ISIN"}) not found in BSE Bhavcopy for $dateKey');
    }

    // 2. Check disk cache
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bse_bhavcopy_$dateKey.json');

    if (await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        final rawMap = jsonDecode(content) as Map<String, dynamic>;

        final Map<String, PriceRange> scripMap = {};
        final Map<String, PriceRange> symbolMap = {};
        final Map<String, PriceRange> isinMap = {};

        if (rawMap.containsKey('scrip')) {
          (rawMap['scrip'] as Map<String, dynamic>).forEach((k, v) {
            final list = v as List<dynamic>;
            scripMap[k] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
        }
        if (rawMap.containsKey('sym')) {
          (rawMap['sym'] as Map<String, dynamic>).forEach((k, v) {
            final list = v as List<dynamic>;
            symbolMap[k] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
        }
        if (rawMap.containsKey('isin')) {
          (rawMap['isin'] as Map<String, dynamic>).forEach((k, v) {
            final list = v as List<dynamic>;
            isinMap[k] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
        }

        final dayData = _BseDayBhavcopyData(
          scripCodeToRange: scripMap,
          symbolToRange: symbolMap,
          isinToRange: isinMap,
        );
        _memoryCache[dateKey] = dayData;

        final range = dayData.find(
          scripCode: targetScrip ?? target,
          symbol: target,
          isin: targetIsin,
        );
        if (range != null) return range;

        throw PriceFetchException(
            'BSE stock $target (${targetIsin ?? "no ISIN"}) not found in BSE Bhavcopy for $dateKey');
      } catch (e) {
        if (e is PriceFetchException) rethrow;
        await cacheFile.delete().catchError((_) => cacheFile);
      }
    }

    // 3. Download from BSE archives
    return _downloadAndParseBhavcopy(
      date,
      target: target,
      targetScrip: targetScrip,
      targetIsin: targetIsin,
    );
  }

  /// Downloads and caches the Bhavcopy for [date] if not already cached.
  static Future<void> ensureBhavcopyCached(DateTime date) async {
    final dateKey = _formatDate(date);
    if (_memoryCache.containsKey(dateKey)) return;

    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bse_bhavcopy_$dateKey.json');
    if (await cacheFile.exists()) {
      return;
    }

    await _downloadAndParseBhavcopy(date);
  }

  static Future<PriceRange> _downloadAndParseBhavcopy(
    DateTime date, {
    String? target,
    String? targetScrip,
    String? targetIsin,
  }) async {
    final dateKey = _formatDate(date);
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bse_bhavcopy_$dateKey.json');

    final isUdiff = !date.isBefore(bseUdiffCutoff);
    final url = getBseBhavcopyUrl(date);
    final uri = Uri.parse(url);

    final http.Response response;
    try {
      final client = httpClient ?? http.Client();
      response = await client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://www.bseindia.com/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(timeoutDuration);
    } catch (e) {
      throw PriceFetchException('Failed to download BSE Bhavcopy: $e');
    }

    if (response.statusCode == 404) {
      throw PriceFetchException('BSE Bhavcopy not available for date $dateKey');
    }
    if (response.statusCode != 200) {
      throw PriceFetchException(
          'BSE server returned HTTP ${response.statusCode} for Bhavcopy $dateKey');
    }

    String csvContent;
    if (isUdiff) {
      final body = response.body.trim();
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html') || !body.startsWith('TradDt')) {
        throw PriceFetchException('BSE Bhavcopy not available for date $dateKey');
      }
      csvContent = body;
    } else {
      // Legacy ZIP archive
      try {
        final archive = ZipDecoder().decodeBytes(response.bodyBytes);
        final csvArchiveFile = archive.files.firstWhere(
          (f) => f.name.toLowerCase().endsWith('.csv'),
          orElse: () => throw PriceFetchException('No CSV file found inside BSE archive for $dateKey'),
        );
        csvContent = utf8.decode(csvArchiveFile.content as List<int>);
      } catch (e) {
        if (e is PriceFetchException) rethrow;
        throw PriceFetchException('Failed to extract BSE Bhavcopy ZIP for $dateKey: $e');
      }
    }

    try {
      final lines = const LineSplitter().convert(csvContent);
      if (lines.isEmpty) {
        throw PriceFetchException('Empty BSE Bhavcopy for $dateKey');
      }

      final headers = _parseCsvLine(lines[0]);
      // Support both modern UDiFF (FinInstrmId, HghPric, LwPric) and legacy (SC_CODE, HIGH, LOW)
      var scripIdx = headers.indexOf('FinInstrmId');
      if (scripIdx == -1) scripIdx = headers.indexOf('SC_CODE');

      var symbolIdx = headers.indexOf('TckrSymb');
      if (symbolIdx == -1) symbolIdx = headers.indexOf('SC_NAME');

      final isinIdx = headers.indexOf('ISIN');
      final typeIdx = headers.indexOf('FinInstrmTp');
      final scTypeIdx = headers.indexOf('SC_TYPE');

      var highIdx = headers.indexOf('HghPric');
      if (highIdx == -1) highIdx = headers.indexOf('HIGH');

      var lowIdx = headers.indexOf('LwPric');
      if (lowIdx == -1) lowIdx = headers.indexOf('LOW');

      if (scripIdx == -1 || highIdx == -1 || lowIdx == -1) {
        throw PriceFetchException('Unexpected BSE Bhavcopy CSV column format for $dateKey');
      }

      final Map<String, PriceRange> scripMap = {};
      final Map<String, PriceRange> symbolMap = {};
      final Map<String, PriceRange> isinMap = {};
      final Map<String, dynamic> diskCacheMap = {
        'scrip': <String, List<double>>{},
        'sym': <String, List<double>>{},
        'isin': <String, List<double>>{},
      };

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _parseCsvLine(line);
        if (cols.length <= scripIdx ||
            cols.length <= highIdx ||
            cols.length <= lowIdx) {
          continue;
        }

        // Filter: UDiFF uses FinInstrmTp == 'STK'; legacy format uses SC_TYPE == 'Q'
        if (typeIdx != -1 && cols.length > typeIdx && cols[typeIdx].trim() != 'STK') {
          continue;
        }
        if (scTypeIdx != -1 && cols.length > scTypeIdx && cols[scTypeIdx].trim().toUpperCase() != 'Q') {
          continue;
        }

        final scrip = cols[scripIdx].trim().toUpperCase();
        final symb = (symbolIdx != -1 && cols.length > symbolIdx)
            ? cols[symbolIdx].trim().toUpperCase()
            : '';
        final isinVal = (isinIdx != -1 && cols.length > isinIdx)
            ? cols[isinIdx].trim().toUpperCase()
            : '';
        final high = double.tryParse(cols[highIdx].trim());
        final low = double.tryParse(cols[lowIdx].trim());

        if (high != null && low != null) {
          final range = PriceRange(low: low, high: high);
          if (scrip.isNotEmpty) {
            scripMap[scrip] = range;
            (diskCacheMap['scrip'] as Map<String, List<double>>)[scrip] = [low, high];
          }
          if (symb.isNotEmpty) {
            symbolMap[symb] = range;
            (diskCacheMap['sym'] as Map<String, List<double>>)[symb] = [low, high];
          }
          if (isinVal.isNotEmpty) {
            isinMap[isinVal] = range;
            (diskCacheMap['isin'] as Map<String, List<double>>)[isinVal] = [low, high];
          }
        }
      }

      final dayData = _BseDayBhavcopyData(
        scripCodeToRange: scripMap,
        symbolToRange: symbolMap,
        isinToRange: isinMap,
      );
      _memoryCache[dateKey] = dayData;

      try {
        await cacheFile.writeAsString(jsonEncode(diskCacheMap));
      } catch (_) {}

      if (target != null) {
        final range = dayData.find(
          scripCode: targetScrip ?? target,
          symbol: target,
          isin: targetIsin,
        );
        if (range != null) return range;
        throw PriceFetchException(
            'BSE stock $target (${targetIsin ?? "no ISIN"}) not found in BSE Bhavcopy for $dateKey');
      }

      return PriceRange(low: 0, high: 0);
    } on PriceFetchException {
      rethrow;
    } catch (e) {
      throw PriceFetchException('Failed to parse BSE Bhavcopy for $dateKey: $e');
    }
  }

  static Future<Directory> _getCacheDirectory() async {
    if (cacheDirOverrideForTesting != null) {
      return cacheDirOverrideForTesting!;
    }
    Directory parentDir;
    try {
      parentDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      parentDir = Directory.systemTemp;
    }
    final dir = Directory('${parentDir.path}/bhavcopy_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }
}
