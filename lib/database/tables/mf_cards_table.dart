// lib/database/tables/mf_cards_table.dart

import 'package:drift/drift.dart';

class MfCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get schemeCode => text().unique()();
  TextColumn get isin => text()();
  TextColumn get schemeName => text()();
  TextColumn get amcName => text()();
  TextColumn get plan => text()(); // Direct / Regular
  TextColumn get option => text()(); // Growth / IDCW
  TextColumn get category => text()(); // Equity / Debt / Hybrid / Other
}