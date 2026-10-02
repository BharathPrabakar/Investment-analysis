// lib/database/tables/tags_table.dart

import 'package:drift/drift.dart';

/// Generic tags that can be associated with any card type.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Tag names are globally unique across all investment types.
  TextColumn get name => text().unique()();
}

/// Join table linking tags to cards of any investment type.
/// [cardType] disambiguates which table [cardId] belongs to (e.g. "stock").
class CardTags extends Table {
  IntColumn get cardId => integer()();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// Discriminator: "stock", "fd", "mf", etc.
  TextColumn get cardType => text()();

  @override
  Set<Column> get primaryKey => {cardId, tagId, cardType};
}
