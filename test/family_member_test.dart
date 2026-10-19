/// STORY-8.2 家庭共享：成员生命周期、角色权限、成员维度统计、AA 分摊。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/member_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/services/member_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookId = 'book-1';
  const deviceId = 'dev-1';

  late AppDatabase db;
  late FixedClock clock;
  late MemberRepositoryImpl memberRepo;
  late MemberService service;
  late LedgerRepositoryImpl ledgerRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    memberRepo = MemberRepositoryImpl(
      db: db, changeLogWriter: changeLog, idGen: UuidV7(), clock: clock);
    service = MemberService(repository: memberRepo, idGen: UuidV7(), clock: clock);
    ledgerRepo = LedgerRepositoryImpl(
        db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(
      repository: ledgerRepo, clock: clock, idGen: UuidV7(),
      memberRepository: memberRepo,
    );

    final accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    await accountRepo.create(Account(
      id: 'acc-bank', name: '工资卡', type: AccountType.debit,
      currency: 'CNY', openingBalance: 0, sortOrder: 1,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
  });

  tearDown(() => db.close());

  Future<Member> joinAs(String name, {MemberRole role = MemberRole.member}) async {
    final code = await service.inviteCode();
    final res = await service.join(
      bookId: bookId, deviceId: deviceId, code: code, name: name, role: role);
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
    return res.requireValue;
  }

  Future<String> addExpense(int cents, {String? memberId}) async {
    final res = await createEntry(CreateEntryInput(
      amountExpression: '${cents / 100}',
      type: EntryType.expense,
      categoryId: '',
      accountId: 'acc-cash',
      bookId: bookId,
      deviceId: deviceId,
      memberId: memberId,
    ), s: kDefaultAppStrings);
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
    return res.requireValue.id;
  }

  group('「我」与邀请', () {
    test('ensureMe 幂等，且「我」是所有者', () async {
      final a = await service.ensureMe(bookId: bookId, deviceId: deviceId);
      final b = await service.ensureMe(bookId: bookId, deviceId: deviceId);
      expect(a.requireValue.id, b.requireValue.id);
      expect(a.requireValue.role, MemberRole.owner);
      expect(a.requireValue.isMe, isTrue);
      expect((await memberRepo.countActive(bookId)).requireValue, 1);
    });

    test('邀请码持久化且长度符合规则', () async {
      final code = await service.inviteCode();
      expect(code.length, MemberRules.inviteCodeLength);
      expect(await service.inviteCode(), code);
      // 易混字符不出现在字母表里
      expect(code.contains(RegExp(r'[01OI]')), isFalse);
    });

    test('邀请码不对 → 拒绝加入', () async {
      await service.ensureMe(bookId: bookId, deviceId: deviceId);
      final res = await service.join(
        bookId: bookId, deviceId: deviceId, code: 'WRONG1', name: '张三');
      expect(res.failureOrNull!.code, 'member.invite_code_invalid');
      expect((await memberRepo.countActive(bookId)).requireValue, 1);
    });

    test('AC1：第 7 人被拦（上限 6 名活跃成员）', () async {
      await service.ensureMe(bookId: bookId, deviceId: deviceId);
      for (var i = 1; i <= 5; i++) {
        await joinAs('成员$i');
      }
      expect((await memberRepo.countActive(bookId)).requireValue,
          MemberRules.maxActiveMembers);

      final code = await service.inviteCode();
      final seventh = await service.join(
        bookId: bookId, deviceId: deviceId, code: code, name: '第7人');
      expect(seventh.failureOrNull!.code, 'member.too_many');
      // 服务只回错误码，界面文案由 family_page._memberError 映射为「最多 6 人」
      expect((await memberRepo.countActive(bookId)).requireValue, 6);
    });
  });

  group('AC4：退出不占名额、历史归属保留', () {
    test('退出后新成员可加入，且退出者的账单完整保留', () async {
      final me = (await service.ensureMe(bookId: bookId, deviceId: deviceId)).requireValue;
      for (var i = 1; i <= 5; i++) {
        await joinAs('成员$i');
      }
      final leaver = (await service.activeMembers(bookId)).requireValue
          .firstWhere((m) => m.name == '成员1');
      final leaverEntry = await addExpense(5000, memberId: leaver.id);

      // 退出
      expect((await service.leave(leaver.id)).isSuccess, isTrue);
      expect((await memberRepo.countActive(bookId)).requireValue, 5);

      // 腾出名额 → 第 7 人可加入
      final joiner = await joinAs('新成员');
      expect(joiner.isActive, isTrue);
      expect((await memberRepo.countActive(bookId)).requireValue, 6);

      // 退出者的历史账单仍在，归属仍指向那条记录
      final entry = (await ledgerRepo.getById(leaverEntry)).requireValue;
      expect(entry.memberId, leaver.id);
      final all = (await service.allMembers(bookId)).requireValue;
      expect(all.any((m) => m.id == leaver.id), isTrue, reason: '记录保留');
      expect(all.firstWhere((m) => m.id == leaver.id).isActive, isFalse);
      // 已退出者不再出现在选择器（活跃列表）里
      final selectable = (await service.activeMembers(bookId)).requireValue;
      expect(selectable.any((m) => m.id == leaver.id), isFalse);
      // 归属显示为「已退出成员」
      expect(all.firstWhere((m) => m.id == leaver.id).attributionLabel(kDefaultAppStrings),
          contains('已退出成员'));
      expect(me.isMe, isTrue);
    });

    test('最后一名所有者不能退出，「我」也不能被删/退出', () async {
      final me = (await service.ensureMe(bookId: bookId, deviceId: deviceId)).requireValue;
      expect((await service.leave(me.id)).failureOrNull!.code, 'member.cannot_leave_me');
      expect((await service.remove(me.id)).failureOrNull!.code, 'member.cannot_delete_me');
      expect((await memberRepo.countActive(bookId)).requireValue, 1);
    });

    test('同名成员被拒', () async {
      await service.ensureMe(bookId: bookId, deviceId: deviceId);
      await joinAs('张三');
      final code = await service.inviteCode();
      final dup = await service.join(
        bookId: bookId, deviceId: deviceId, code: code, name: '张三');
      expect(dup.failureOrNull!.code, 'member.name_taken');
    });
  });

  group('AC2：角色权限', () {
    test('只读成员不能记账，成员与所有者可以', () async {
      await service.ensureMe(bookId: bookId, deviceId: deviceId);
      expect(await service.canWrite(bookId), isTrue);

      // 模拟同步后本机账号被设为只读
      final me = (await memberRepo.getMe(bookId)).requireValue!;
      await memberRepo.update(me.copyWith(role: MemberRole.viewer, updatedAt: clock.now()));
      expect(await service.canWrite(bookId), isFalse);
      expect(await service.canManageMembers(bookId), isFalse);

      await memberRepo.update(me.copyWith(role: MemberRole.member, updatedAt: clock.now()));
      expect(await service.canWrite(bookId), isTrue);
      expect(await service.canManageMembers(bookId), isFalse);
    });

    test('没有成员记录时（单人本地使用）放行', () async {
      expect(await service.canWrite(bookId), isTrue);
      expect(await service.canManageMembers(bookId), isTrue);
    });

    test('角色语义与 PRD 三角色一致', () {
      expect(MemberRole.owner.canWrite, isTrue);
      expect(MemberRole.owner.canManageMembers, isTrue);
      expect(MemberRole.member.canWrite, isTrue);
      expect(MemberRole.member.canManageMembers, isFalse);
      expect(MemberRole.viewer.canWrite, isFalse);
      expect(MemberRole.viewer.canManageMembers, isFalse);
    });
  });

  group('AC3：成员维度统计', () {
    test('各成员笔数与金额正确，未归属的老账单独成组', () async {
      final me = (await service.ensureMe(bookId: bookId, deviceId: deviceId)).requireValue;
      final a = await joinAs('配偶');
      final b = await joinAs('孩子');

      // 我 2 笔（默认归属到我）、配偶 1 笔、孩子 1 笔；另加一笔未归属
      await addExpense(10000);
      await addExpense(20000);
      await addExpense(30000, memberId: a.id);
      await addExpense(3000, memberId: b.id);
      // 未指定归属：用例会回落到「我」，所以这里显式造一笔老数据
      db.raw.execute(
        'INSERT INTO transactions (id,book_id,type,amount_cents,currency,category_id,'
        'account_id,to_account_id,occurred_at,note,source,batch_id,split_role,parent_id,'
        'reimburse_status,exclude_from_stats,reconciled_at,member_id,created_at,updated_at,'
        'deleted_at,revision,device_id,base_revision) '
        "VALUES ('legacy','$bookId','expense',800,'CNY',NULL,'acc-cash',NULL,?,NULL,'manual',"
        "NULL,'normal',NULL,'none',0,NULL,NULL,?,?,NULL,1,'$deviceId',0)",
        [clock.now().millisecondsSinceEpoch, clock.now().millisecondsSinceEpoch,
          clock.now().millisecondsSinceEpoch],
      );

      final from = clock.now().subtract(const Duration(days: 1));
      final to = clock.now().add(const Duration(days: 1));
      final aggs = (await ledgerRepo.memberSummary(
        bookId: bookId,
        fromMs: from.millisecondsSinceEpoch,
        toMs: to.millisecondsSinceEpoch,
      )).requireValue;
      final byId = {for (final g in aggs) g.memberId: g};

      expect(byId[me.id]!.txCount, 2);
      expect(byId[me.id]!.expenseCents, 30000);
      expect(byId[a.id]!.txCount, 1);
      expect(byId[a.id]!.expenseCents, 30000);
      expect(byId[b.id]!.txCount, 1);
      expect(byId[b.id]!.expenseCents, 3000);
      // 未归属的归到空 id 组，不丢数据
      expect(byId['']!.txCount, 1);
      expect(byId['']!.expenseCents, 800);
    });

    test('汇总口径与统计口径一致：转账不计入成员汇总', () async {
      await service.ensureMe(bookId: bookId, deviceId: deviceId);
      await addExpense(10000);
      // 一笔真实转账（现金 → 工资卡）：是钱的移动，不是收支，不该进成员汇总
      final transfer = await createEntry(CreateEntryInput(
        amountExpression: '50', type: EntryType.transfer, categoryId: '',
        accountId: 'acc-cash', toAccountId: 'acc-bank', bookId: bookId,
        deviceId: deviceId,
      ), s: kDefaultAppStrings);
      expect(transfer.isSuccess, isTrue, reason: '${transfer.failureOrNull}');

      final from = clock.now().subtract(const Duration(days: 1));
      final to = clock.now().add(const Duration(days: 1));
      final aggs = (await ledgerRepo.memberSummary(
        bookId: bookId,
        fromMs: from.millisecondsSinceEpoch,
        toMs: to.millisecondsSinceEpoch,
      )).requireValue;
      expect(aggs.fold<int>(0, (s, g) => s + g.txCount), 1);
      expect(aggs.fold<int>(0, (s, g) => s + g.expenseCents), 10000);
    });
  });

  group('AC5：AA 分摊', () {
    test('300 元 3 人 → 每人 100', () {
      final shares = MemberService.splitEqually(30000, const ['a', 'b', 'c']);
      expect(shares.length, 3);
      expect(shares.every((s) => s.cents == 10000), isTrue);
    });

    test('除不尽时余数分给靠前者，且总额守恒', () {
      final shares = MemberService.splitEqually(100, const ['a', 'b', 'c']);
      expect(shares.map((s) => s.cents).toList(), [34, 33, 33]);
      expect(shares.fold<int>(0, (s, x) => s + x.cents), 100);
      final two = MemberService.splitEqually(101, const ['a', 'b']);
      expect(two.map((s) => s.cents).toList(), [51, 50]);
      expect(two.fold<int>(0, (s, x) => s + x.cents), 101);
    });

    test('没有参与人则不分摊', () {
      expect(MemberService.splitEqually(30000, const []), isEmpty);
    });

    test('参与人落库并按顺序读回，重复设置整组替换', () async {
      final a = (await service.ensureMe(bookId: bookId, deviceId: deviceId)).requireValue;
      final b = await joinAs('配偶');
      final entryId = await addExpense(30000);

      await service.setParticipants(
        entryId: entryId, bookId: bookId,
        memberIds: [a.id, b.id], deviceId: deviceId);
      final first = (await service.participantsOf(entryId)).requireValue;
      expect(first.map((p) => p.memberId).toList(), [a.id, b.id]);
      expect(MemberService.splitEqually(30000, [for (final p in first) p.memberId])
          .every((s) => s.cents == 15000), isTrue);

      // 整组替换：只剩 b
      await service.setParticipants(
        entryId: entryId, bookId: bookId, memberIds: [b.id], deviceId: deviceId);
      final second = (await service.participantsOf(entryId)).requireValue;
      expect(second.length, 1);
      expect(second.first.memberId, b.id);
      expect(second.first.sortOrder, 0);
    });
  });
}
