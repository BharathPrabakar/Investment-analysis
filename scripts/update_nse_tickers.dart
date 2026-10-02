import 'dart:convert';
import 'dart:io';

/// Script to update the bundled NSE equity tickers dataset.
///
/// Source: Official NSE Listed Equities CSV
/// URL: https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv
///
/// NOTE: This list should be refreshed periodically as new companies list,
/// demerge, or get renamed on the NSE.
///
/// Usage:
///   dart run scripts/update_nse_tickers.dart
Future<void> main() async {
  final csvUrl =
      'https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv';
  final rawCsvFile = File('assets/EQUITY_L.csv');
  final outputJsonFile = File('assets/nse_tickers.json');

  stdout.writeln('Fetching latest NSE equity list from: $csvUrl');

  String csvContent;
  try {
    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    final request = await client.getUrl(Uri.parse(csvUrl));
    final response = await request.close();
    if (response.statusCode == 200) {
      csvContent = await response.transform(utf8.decoder).join();
      await rawCsvFile.writeAsString(csvContent);
      stdout.writeln('Downloaded and saved ${rawCsvFile.path}');
    } else {
      stdout.writeln(
          'HTTP ${response.statusCode} while downloading. Falling back to existing ${rawCsvFile.path}...');
      if (!await rawCsvFile.exists()) {
        throw Exception(
            'Failed to download and no local file found at ${rawCsvFile.path}');
      }
      csvContent = await rawCsvFile.readAsString();
    }
  } catch (e) {
    stdout.writeln(
        'Download encountered error ($e). Checking existing ${rawCsvFile.path}...');
    if (!await rawCsvFile.exists()) {
      rethrow;
    }
    csvContent = await rawCsvFile.readAsString();
  }

  final lines = const LineSplitter().convert(csvContent);
  if (lines.isEmpty) {
    throw Exception('CSV file is empty.');
  }

  // Parse header line (trim leading/trailing spaces from headers)
  final rawHeaders = _parseCsvLine(lines.first);
  final headers = rawHeaders.map((h) => h.trim().toUpperCase()).toList();

  final symbolIdx = headers.indexOf('SYMBOL');
  final nameIdx = headers.indexOf('NAME OF COMPANY');
  final seriesIdx = headers.indexOf('SERIES');
  final isinIdx = headers.indexOf('ISIN NUMBER');

  if (symbolIdx == -1 || nameIdx == -1 || seriesIdx == -1 || isinIdx == -1) {
    throw Exception(
        'Required columns missing. Found headers: $rawHeaders. Expected SYMBOL, NAME OF COMPANY, SERIES, ISIN NUMBER');
  }

  final tickerEntries = <Map<String, String>>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length <= symbolIdx ||
        cols.length <= nameIdx ||
        cols.length <= seriesIdx ||
        cols.length <= isinIdx) {
      continue;
    }

    final series = cols[seriesIdx].trim();
    // Keep only series EQ and BE
    if (series != 'EQ' && series != 'BE') {
      continue;
    }

    final symbol = cols[symbolIdx].trim();
    final name = cols[nameIdx].trim();
    final isin = cols[isinIdx].trim();

    if (symbol.isEmpty || isin.isEmpty) continue;

    tickerEntries.add({
      'symbol': symbol,
      'company_name': name,
      'exchange': 'NSE',
      'isin': isin,
    });
  }

  final jsonEncoder = const JsonEncoder.withIndent('  ');
  await outputJsonFile.writeAsString(jsonEncoder.convert(tickerEntries));

  stdout.writeln(
      'Successfully generated ${outputJsonFile.path} with ${tickerEntries.length} tickers (EQ & BE).');
}

List<String> _parseCsvLine(String line) {
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
