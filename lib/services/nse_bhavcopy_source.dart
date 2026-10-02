// lib/services/nse_bhavcopy_source.dart
//
// NSE UDiFF Equity Bhavcopy parser and downloader for past trading days.

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../data/local_tickers.dart';
import 'price_service.dart';

class _DayBhavcopyData {
  final Map<String, PriceRange> isinToRange;
  final Map<String, PriceRange> symbolToRange;

  const _DayBhavcopyData({
    required this.isinToRange,
    required this.symbolToRange,
  });

  PriceRange? find({String? isin, String? ticker}) {
    if (isin != null && isin.isNotEmpty) {
      final range = isinToRange[isin.toUpperCase()];
      if (range != null) return range;
    }
    if (ticker != null && ticker.isNotEmpty) {
      final range = symbolToRange[ticker.toUpperCase()];
      if (range != null) return range;
    }
    return null;
  }
}

class NseBhavcopySource {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Optional HTTP client for testing
  static http.Client? httpClient;

  // In-memory cache for fast lookup during the current app run: "YYYYMMDD" -> _DayBhavcopyData
  static final Map<String, _DayBhavcopyData> _memoryCache = {};

  /// Format date as YYYYMMDD
  static String _formatDate(DateTime date) => DateFormat('yyyyMMdd').format(date);

  /// Fetch price range for [ticker] on past trading date [date].
  /// Matches by [isin] first (retrieved from local ticker list if not provided),
  /// falling back to [ticker] symbol.
  static Future<PriceRange> fetchDayPriceRange(
    String ticker,
    DateTime date, {
    String? isin,
  }) async {
    final dateKey = _formatDate(date);
    final targetTicker = ticker.trim().toUpperCase();
    final targetIsin = (isin?.trim().isNotEmpty == true)
        ? isin!.trim().toUpperCase()
        : (await getIsinForSymbol(targetTicker))?.toUpperCase();

    // 1. Check in-memory cache
    if (_memoryCache.containsKey(dateKey)) {
      final dayData = _memoryCache[dateKey]!;
      final range = dayData.find(isin: targetIsin, ticker: targetTicker);
      if (range != null) return range;
      throw PriceFetchException(
          'Stock $targetTicker (${targetIsin ?? "no ISIN"}) not found in NSE Bhavcopy for $dateKey');
    }

    // 2. Check disk cache
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bhavcopy_$dateKey.json');

    if (await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        final rawMap = jsonDecode(content) as Map<String, dynamic>;

        final Map<String, PriceRange> isinMap = {};
        final Map<String, PriceRange> symbolMap = {};

        // V2 cache format has 'isin' and 'sym' sub-maps
        if (rawMap.containsKey('isin') && rawMap.containsKey('sym')) {
          final rawIsin = rawMap['isin'] as Map<String, dynamic>;
          final rawSym = rawMap['sym'] as Map<String, dynamic>;

          rawIsin.forEach((key, val) {
            final list = val as List<dynamic>;
            isinMap[key] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
          rawSym.forEach((key, val) {
            final list = val as List<dynamic>;
            symbolMap[key] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
        } else {
          // Legacy V1 cache (only symbol keys)
          rawMap.forEach((key, val) {
            final list = val as List<dynamic>;
            symbolMap[key] = PriceRange(
              low: (list[0] as num).toDouble(),
              high: (list[1] as num).toDouble(),
            );
          });
        }

        final dayData = _DayBhavcopyData(
          isinToRange: isinMap,
          symbolToRange: symbolMap,
        );
        _memoryCache[dateKey] = dayData;

        final range = dayData.find(isin: targetIsin, ticker: targetTicker);
        if (range != null) return range;

        // If legacy cache didn't have ISIN map and symbol lookup failed,
        // re-fetch from official archive to get ISIN-based mapping.
        if (isinMap.isEmpty && targetIsin != null) {
          await cacheFile.delete().catchError((_) => cacheFile);
          _memoryCache.remove(dateKey);
        } else {
          throw PriceFetchException(
              'Stock $targetTicker (${targetIsin ?? "no ISIN"}) not found in NSE Bhavcopy for $dateKey');
        }
      } catch (e) {
        if (e is PriceFetchException) rethrow;
        // If file corrupted, delete and re-fetch
        await cacheFile.delete().catchError((_) => cacheFile);
      }
    }

    // 3. Download from NSE archives
    return _downloadAndParseBhavcopy(date, targetTicker: targetTicker, targetIsin: targetIsin);
  }

  /// Downloads and caches the Bhavcopy for [date] if not already cached.
  /// Throws [PriceFetchException] with status code or error on failure.
  static Future<void> ensureBhavcopyCached(DateTime date) async {
    final dateKey = _formatDate(date);
    if (_memoryCache.containsKey(dateKey)) return;

    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bhavcopy_$dateKey.json');
    if (await cacheFile.exists()) {
      return;
    }

    await _downloadAndParseBhavcopy(date);
  }

  /// Cutoff date for UDiFF format: 2024-07-08
  static final DateTime nseCutoffDate = DateTime(2024, 7, 8);

  /// Generates the appropriate NSE Bhavcopy URL based on date:
  /// - Dates >= 2024-07-08 use the new UDiFF format:
  ///   https://nsearchives.nseindia.com/content/cm/BhavCopy_NSE_CM_0_0_0_YYYYMMDD_F_0000.csv.zip
  /// - Dates < 2024-07-08 use the old format:
  ///   https://nsearchives.nseindia.com/content/historical/EQUITIES/YYYY/MMM/cmDDMMMYYYYbhav.csv.zip
  static String getNseBhavcopyUrl(DateTime date) {
    if (!date.isBefore(nseCutoffDate)) {
      final dateKey = _formatDate(date);
      return 'https://nsearchives.nseindia.com/content/cm/BhavCopy_NSE_CM_0_0_0_${dateKey}_F_0000.csv.zip';
    } else {
      final year = DateFormat('yyyy').format(date);
      final monthUpper = DateFormat('MMM').format(date).toUpperCase();
      final dd = DateFormat('dd').format(date);
      return 'https://nsearchives.nseindia.com/content/historical/EQUITIES/$year/$monthUpper/cm$dd$monthUpper${year}bhav.csv.zip';
    }
  }

  static Map<String, String> get browserHeaders => const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.nseindia.com/',
      };

  static Future<PriceRange> _downloadAndParseBhavcopy(
    DateTime date, {
    String? targetTicker,
    String? targetIsin,
  }) async {
    final dateKey = _formatDate(date);
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/bhavcopy_$dateKey.json');

    final url = getNseBhavcopyUrl(date);
    final uri = Uri.parse(url);

    http.Response? response;
    final client = httpClient ?? http.Client();

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        response = await client.get(
          uri,
          headers: browserHeaders,
        ).timeout(timeoutDuration);

        // Do not retry 404 or 200
        if (response.statusCode == 200 || response.statusCode == 404) {
          break;
        }
      } catch (e) {
        if (attempt == 1) {
          throw PriceFetchException('Failed to download NSE Bhavcopy: $e');
        }
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    if (response == null) {
      throw PriceFetchException('Failed to download NSE Bhavcopy for date $dateKey');
    }

    if (response.statusCode == 404) {
      throw PriceFetchException('NSE Bhavcopy not available for date $dateKey');
    }
    if (response.statusCode != 200) {
      throw PriceFetchException('NSE server returned HTTP ${response.statusCode} for Bhavcopy $dateKey');
    }

    // 4. Unzip and parse CSV
    try {
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      final csvArchiveFile = archive.files.firstWhere(
        (f) => f.name.endsWith('.csv'),
        orElse: () => throw PriceFetchException('No CSV file found inside Bhavcopy archive for $dateKey'),
      );

      final csvContent = utf8.decode(csvArchiveFile.content as List<int>);
      final lines = const LineSplitter().convert(csvContent);
      if (lines.isEmpty) {
        throw PriceFetchException('Empty Bhavcopy CSV for $dateKey');
      }

      // Column headers - supports both new UDiFF and old formats
      final headers = _parseCsvLine(lines[0]);
      final isinIdx = headers.indexOf('ISIN');

      // Symbol: TckrSymb (UDiFF) or SYMBOL (old format)
      var symbolIdx = headers.indexOf('TckrSymb');
      if (symbolIdx == -1) symbolIdx = headers.indexOf('SYMBOL');

      // Series: SctySrs (UDiFF) or SERIES (old format)
      var seriesIdx = headers.indexOf('SctySrs');
      if (seriesIdx == -1) seriesIdx = headers.indexOf('SERIES');

      // High price: HghPric (UDiFF) or HIGH (old format)
      var highIdx = headers.indexOf('HghPric');
      if (highIdx == -1) highIdx = headers.indexOf('HIGH');

      // Low price: LwPric (UDiFF) or LOW (old format)
      var lowIdx = headers.indexOf('LwPric');
      if (lowIdx == -1) lowIdx = headers.indexOf('LOW');

      if (symbolIdx == -1 || seriesIdx == -1 || highIdx == -1 || lowIdx == -1) {
        throw PriceFetchException('Unexpected Bhavcopy CSV column format for $dateKey');
      }

      final Map<String, PriceRange> isinMap = {};
      final Map<String, PriceRange> symbolMap = {};
      final Map<String, dynamic> diskCacheMap = {
        'isin': <String, List<double>>{},
        'sym': <String, List<double>>{},
      };

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _parseCsvLine(line);
        if (cols.length <= symbolIdx ||
            cols.length <= seriesIdx ||
            cols.length <= highIdx ||
            cols.length <= lowIdx) {
          continue;
        }

        final series = cols[seriesIdx].trim();
        // Accept both EQ and BE series
        if (series == 'EQ' || series == 'BE') {
          final symb = cols[symbolIdx].trim().toUpperCase();
          final isinVal = (isinIdx != -1 && cols.length > isinIdx)
              ? cols[isinIdx].trim().toUpperCase()
              : '';
          final high = double.tryParse(cols[highIdx].trim());
          final low = double.tryParse(cols[lowIdx].trim());

          if (high != null && low != null) {
            final range = PriceRange(low: low, high: high);
            // In case a stock had trades in both EQ and BE, combine or prefer EQ
            if (symbolMap.containsKey(symb) && series != 'EQ') {
              // keep existing
            } else {
              symbolMap[symb] = range;
              (diskCacheMap['sym'] as Map<String, List<double>>)[symb] = [low, high];
            }

            if (isinVal.isNotEmpty) {
              if (isinMap.containsKey(isinVal) && series != 'EQ') {
                // keep existing
              } else {
                isinMap[isinVal] = range;
                (diskCacheMap['isin'] as Map<String, List<double>>)[isinVal] = [low, high];
              }
            }
          }
        }
      }

      final dayData = _DayBhavcopyData(
        isinToRange: isinMap,
        symbolToRange: symbolMap,
      );
      _memoryCache[dateKey] = dayData;

      // Persist to disk cache
      try {
        await cacheFile.writeAsString(jsonEncode(diskCacheMap));
      } catch (_) {
        // Disk write error shouldn't crash query
      }

      final range = dayData.find(isin: targetIsin, ticker: targetTicker);
      if (range != null) return range;
      throw PriceFetchException(
          'Stock $targetTicker (${targetIsin ?? "no ISIN"}) not found in NSE Bhavcopy for $dateKey');
    } on PriceFetchException {
      rethrow;
    } catch (e) {
      throw PriceFetchException('Failed to parse NSE Bhavcopy for $dateKey: $e');
    }
  }

  static Future<Directory> _getCacheDirectory() async {
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
