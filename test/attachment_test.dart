/// STORY-1.5 附件：限额、孤儿生命周期、巡检清理。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/platform/attachment_store.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/attachment_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/attachment_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

/// 1×1 透明 PNG（有效图像，供压缩/尺寸探测走真实解码路径）。
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AttachmentService service;
  late AttachmentStore store;
  late Directory tmp;
  late Directory attachmentsDir;
  late String pngPath;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    tmp = await Directory.systemTemp.createTemp('plain_attach_test');
    attachmentsDir = Directory('${tmp.path}/attachments');
    store = AttachmentStore(root: attachmentsDir);
    final changeLog = ChangeLogWriter(db, clock: clock);
    final attachmentRepo = AttachmentRepositoryImpl(db: db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
      attachments: attachmentRepo,
    );
    service = AttachmentService(
      repository: attachmentRepo,
      store: store,
      idGen: UuidV7(),
      clock: clock,
    );

    final bytes = base64Decode(_tinyPngBase64);
    pngPath = '${tmp.path}/小票.png';
    await File(pngPath).writeAsBytes(bytes);

    final accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
  });

  tearDown(() async {
    db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> newEntry() async {
    final useCase = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());
    final res = await useCase(CreateEntryInput(
      amountExpression: '20',
      type: EntryType.expense,
      categoryId: '',
      accountId: 'acc-cash',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ));
    return res.requireValue.id;
  }

  Future<void> addPng(String entryId, {String name = '小票.png'}) async {
    final res = await service.add(
      entryId: entryId,
      bookId: 'book-1',
      deviceId: 'dev-1',
      sourcePath: name == '小票.png' ? pngPath : '${tmp.path}/$name',
    );
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
  }

  group('限额校验（纯函数）', () {
    test('AC1：已满 5 张 → tooMany', () {
      expect(
        AttachmentService.validate(existingCount: 5, sizeBytes: 1024, fileName: 'a.png'),
        AttachmentRejection.tooMany,
      );
      expect(
        AttachmentService.validate(existingCount: 4, sizeBytes: 1024, fileName: 'a.png'),
        isNull,
      );
    });

    test('单张超 10MB：非图片直接拦，图片留给压缩后复检', () {
      const big = AttachmentRules.maxBytes + 1;
      expect(
        AttachmentService.validate(existingCount: 0, sizeBytes: big, fileName: 'a.pdf'),
        AttachmentRejection.tooLarge,
      );
      expect(
        AttachmentService.validate(existingCount: 0, sizeBytes: big, fileName: 'a.jpg'),
        isNull,
      );
    });

    test('格式白名单：仅 jpg/png/heic/pdf', () {
      for (final ok in ['a.jpg', 'a.jpeg', 'a.PNG', 'a.heic', 'a.heif', 'a.pdf']) {
        expect(AttachmentRules.mimeOf(ok), isNotNull, reason: ok);
      }
      for (final bad in ['a.gif', 'a.webp', 'a.txt', 'noext']) {
        expect(AttachmentRules.mimeOf(bad), isNull, reason: bad);
      }
      expect(
        AttachmentService.validate(existingCount: 0, sizeBytes: 10, fileName: 'a.gif'),
        AttachmentRejection.unsupportedType,
      );
    });

    test('空文件被拦', () {
      expect(
        AttachmentService.validate(existingCount: 0, sizeBytes: 0, fileName: 'a.png'),
        AttachmentRejection.emptyFile,
      );
    });
  });

  group('入库与落盘', () {
    test('新增一张：元数据 + 文件都在', () async {
      final entryId = await newEntry();
      await addPng(entryId);

      final list = await service.list(entryId);
      expect(list.requireValue.length, 1);
      final a = list.requireValue.first;
      expect(a.mime, 'image/png');
      expect(a.sizeBytes, greaterThan(0));
      expect(a.sortOrder, 0);
      final f = await store.fileOf(a.storedName);
      expect(f.existsSync(), isTrue);
      // ⚠️ 缩略图与像素尺寸依赖真实图像解码器：`flutter test` 的测试引擎
      //    在 `instantiateCodec` 上会失败（`Codec failed to produce an image`），
      //    因此这两项只能在**真机**验证。这里只断言「若有就自洽」。
      if (a.width != null) expect(a.height, 1);
      if (a.thumbnailName != null) {
        expect((await store.fileOf(a.thumbnailName!)).existsSync(), isTrue);
      }
    });

    test('AC1：到 5 张后第 6 张入库被拒（服务层兜底）', () async {
      final entryId = await newEntry();
      for (var i = 0; i < AttachmentRules.maxPerEntry; i++) {
        await addPng(entryId);
      }
      final sixth = await service.add(
        entryId: entryId,
        bookId: 'book-1',
        deviceId: 'dev-1',
        sourcePath: pngPath,
      );
      expect(sixth.isFailure, isTrue);
      expect(sixth.failureOrNull!.code, 'attachment.too_many');
      expect((await service.list(entryId)).requireValue.length, 5);
    });

    test('不支持的类型不会落盘', () async {
      final entryId = await newEntry();
      final gif = File('${tmp.path}/a.gif');
      await gif.writeAsBytes([1, 2, 3]);
      final res = await service.add(
        entryId: entryId,
        bookId: 'book-1',
        deviceId: 'dev-1',
        sourcePath: gif.path,
      );
      expect(res.failureOrNull!.code, 'attachment.unsupported_type');
      expect((await service.list(entryId)).requireValue, isEmpty);
    });

    test('移除附件：文件与元数据一起清掉', () async {
      final entryId = await newEntry();
      await addPng(entryId);
      final a = (await service.list(entryId)).requireValue.first;
      final file = await store.fileOf(a.storedName);
      expect(file.existsSync(), isTrue);

      final res = await service.remove(a.id);
      expect(res.isSuccess, isTrue);
      expect(await file.exists(), isFalse);
      expect((await service.list(entryId)).requireValue, isEmpty);
    });
  });

  group('孤儿生命周期（AC2 / AC3）', () {
    test('AC2：删账单 → 标记孤儿；30 天内恢复 → 复原', () async {
      final entryId = await newEntry();
      await addPng(entryId);
      await addPng(entryId);
      expect((await service.list(entryId)).requireValue.length, 2);

      await ledgerRepo.softDelete(entryId);
      final orphaned = (await service.list(entryId)).requireValue;
      expect(orphaned.every((a) => a.isOrphan), isTrue);
      expect(orphaned.every((a) => a.orphanedAt != null), isTrue);

      await ledgerRepo.restore(entryId);
      final restored = (await service.list(entryId)).requireValue;
      expect(restored.length, 2);
      expect(restored.every((a) => !a.isOrphan), isTrue);
    });

    test('AC3：超 30 天的孤儿被巡检物理清理，未超期的与其它账单的不受影响', () async {
      final staleEntry = await newEntry();
      await addPng(staleEntry);
      await ledgerRepo.softDelete(staleEntry);

      final freshEntry = await newEntry();
      await addPng(freshEntry);
      await ledgerRepo.softDelete(freshEntry);

      final aliveEntry = await newEntry();
      await addPng(aliveEntry);

      // 时间前进 31 天：两张孤儿都超期了；再把 fresh 的孤儿时间改成「刚刚」
      clock.advance(const Duration(days: 31));
      final freshOrphan = (await service.list(freshEntry)).requireValue.first;
      db.raw.execute(
        'UPDATE attachments SET orphaned_at = ? WHERE id = ?',
        [clock.now().millisecondsSinceEpoch, freshOrphan.id],
      );
      final staleOrphan = (await service.list(staleEntry)).requireValue.first;

      final purged = await service.purgeExpiredOrphans();
      expect(purged.requireValue, 1);

      // 超期的：行与文件都没了
      expect((await service.list(staleEntry)).requireValue, isEmpty);
      expect((await store.fileOf(staleOrphan.storedName)).existsSync(), isFalse);
      // 未超期的：还在
      expect((await service.list(freshEntry)).requireValue.length, 1);
      // 其它账单的：不受影响
      expect((await service.list(aliveEntry)).requireValue.length, 1);
    });

    test('孤儿在保留期内不会被清理', () async {
      final entryId = await newEntry();
      await addPng(entryId);
      await ledgerRepo.softDelete(entryId);

      clock.advance(const Duration(days: 29));
      expect((await service.purgeExpiredOrphans()).requireValue, 0);
      expect((await service.list(entryId)).requireValue.length, 1);
    });
  });
}
