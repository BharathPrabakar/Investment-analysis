// test/mf_dao_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:my_new_app/database/app_database.dart';
import 'package:my_new_app/database/daos/mf_dao.dart';

void main() {
  late AppDatabase db;
  late MfDao mfDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mfDao = db.mfDao;
  });

  tearDown(() async {
    await db.close();
  });

  test('MF card deletion cascades to transactions and tag links', () async {
    // Create a tag first
    final tagId = await db.into(db.tags).insert(
      TagsCompanion.insert(name: 'LongTerm'),
    );

    // Create MF card
    final cardId = await mfDao.insertMfCard(
      MfCardsCompanion.insert(
        schemeCode: '119551',
        isin: 'INF846K01103',
        schemeName: 'Axis Bluechip Fund',
        amcName: 'Axis Mutual Fund',
        plan: 'Direct',
        option: 'Growth',
        category: 'Equity',
      ),
    );

    // Link tag with cardType = 'mf'
    await mfDao.linkTag(cardId, tagId);

    // Insert transaction
    await mfDao.insertTransaction(
      MfTransactionsCompanion.insert(
        cardId: cardId,
        type: 'Purchase',
        date: DateTime(2026, 1, 1),
        units: 100.0,
        nav: 20.0,
      ),
    );

    // Verify card, transaction, and tag link exist
    var card = await mfDao.getMfCardById(cardId);
    expect(card, isNotNull);

    var txs = await mfDao.getTransactionsForCard(cardId);
    expect(txs.length, 1);

    var tags = await mfDao.getTagsForCard(cardId);
    expect(tags.length, 1);

    // Delete card
    await mfDao.deleteMfCard(cardId);

    // Verify card is gone
    card = await mfDao.getMfCardById(cardId);
    expect(card, isNull);

    // Verify transactions are cascaded
    txs = await mfDao.getTransactionsForCard(cardId);
    expect(txs, isEmpty);

    // Verify tag links for 'mf' are removed
    tags = await mfDao.getTagsForCard(cardId);
    expect(tags, isEmpty);
  });

  test('MF card deletion preserves stock tag links', () async {
    // Create a tag
    final tagId = await db.into(db.tags).insert(
      TagsCompanion.insert(name: 'EquityTag'),
    );

    // Insert stock card tag link (cardType = 'stock')
    await db.into(db.cardTags).insert(
      CardTagsCompanion.insert(
        cardId: 999,
        tagId: tagId,
        cardType: 'stock',
      ),
    );

    // Create MF card and link same tag with cardType = 'mf'
    final mfCardId = await mfDao.insertMfCard(
      MfCardsCompanion.insert(
        schemeCode: '120503',
        isin: 'INF200K01121',
        schemeName: 'SBI Small Cap Fund',
        amcName: 'SBI Mutual Fund',
        plan: 'Direct',
        option: 'Growth',
        category: 'Equity',
      ),
    );
    await mfDao.linkTag(mfCardId, tagId);

    // Delete MF card
    await mfDao.deleteMfCard(mfCardId);

    // Verify stock tag link is still intact
        final allStockLinks = await (db.select(db.cardTags)
          ..where((t) => t.cardType.equals('stock')))
        .get();
    final stockTagLinks =
        allStockLinks.where((l) => l.tagId == tagId).toList();
    expect(stockTagLinks.length, 1);
  });
}
