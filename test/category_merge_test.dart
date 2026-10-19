/// STORY-1.3 AC11–13：分类合并。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late CategoryRepositoryImpl catRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db);
    catRepo = CategoryRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    final ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());

    Category mk(String id, String name, {String? parentId, CategoryKind kind = CategoryKind.expense}) {
      return Category(
        id: id, parentId: parentId, name: name, kind: kind,
        iconRef: 'other', sortOrder: 0, isPreset: false,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
      );
    }

    await catRepo.create(mk('g-food', '餐饮'));
    await catRepo.create(mk('g-shop', '购物'));
    await catRepo.create(mk('c-breakfast', '早餐', parentId: 'g-food'));
    await catRepo.create(mk('c-clothes', '衣服', parentId: 'g-shop'));
    await catRepo.create(mk('c-breakfast2', '早餐', parentId: 'g-shop'));
  });

  tearDown(() => db.close());

  test('second-level merge moves entries and soft-deletes source', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '8', type: EntryType.expense,
      categoryId: 'c-breakfast', bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final r = await catRepo.mergeCategories(sourceId: 'c-breakfast', targetId: 'c-clothes');
    expect(r.isSuccess, true);
    expect(r.successOrNull!.movedEntries, 1);

    final rows = db.raw.select(
        "SELECT category_id FROM transactions WHERE id IS NOT NULL AND deleted_at IS NULL");
    expect(rows.first['category_id'], 'c-clothes');
    final src = db.raw.select(
        'SELECT deleted_at FROM categories WHERE id = ?', ['c-breakfast']);
    expect(src.first['deleted_at'], isNotNull);
  });

  test('first-level merge moves children and merges same-name', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '3', type: EntryType.expense,
      categoryId: 'c-breakfast', bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final r = await catRepo.mergeCategories(sourceId: 'g-food', targetId: 'g-shop');
    expect(r.isSuccess, true);
    expect(r.successOrNull!.mergedSameNameChildren, 1); // 早餐 → 早餐
    expect(r.successOrNull!.movedEntries, 1);
  });

  test('cross-level merge rejected', () async {
    final r = await catRepo.mergeCategories(sourceId: 'g-food', targetId: 'c-clothes');
    expect(r.isFailure, true);
  });
}
