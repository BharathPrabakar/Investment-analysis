// lib/database/tables/mf_transactions_table.dart

import 'package:drift/drift.dart';
import 'mf_cards_table.dart';

class MfTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer().references(MfCards, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // Purchase / Redemption
  DateTimeColumn get date => dateTime()();
  RealColumn get units => real()();
  RealColumn get nav => real()();
  BoolColumn get isAvgEntry => boolean().withDefault(const Constant(false))();
}