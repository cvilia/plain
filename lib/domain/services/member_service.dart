/// STORY-8.2 家庭共享：成员生命周期、权限判定、AA 分摊。
///
/// **离线现实**：跨设备加入依赖官方云同步（STORY-8.1，尚未实现），
/// 因此这里的「邀请码」是**本机账本的邀请码**：用于线下告知家人，
/// 校验通过后在本机登记成员。等 8.1 落地后，`join` 换成远端校验即可，
/// 上层（6 人上限、角色、软删除）语义不变。
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// 一名参与人的应付份额。
class AaShare {
  const AaShare({required this.memberId, required this.cents});
  final String memberId;
  final int cents;
}

class MemberService {
  MemberService({
    required MemberRepository repository,
    required UuidV7 idGen,
    required Clock clock,
  })  : _repository = repository,
        _idGen = idGen,
        _clock = clock;

  final MemberRepository _repository;
  final UuidV7 _idGen;
  final Clock _clock;

  /// 活跃成员（名额与选择器只看这些）。
  Future<Result<List<Member>>> activeMembers(String bookId) =>
      _repository.listByBook(bookId, includeLeft: false);

  /// 全部成员（含已退出，用于历史归属显示）。
  Future<Result<List<Member>>> allMembers(String bookId) => _repository.listByBook(bookId);

  /// 本机用户；没有再回落为「未登记」（权限按只读处理，见 [canWrite]）。
  Future<Member?> me(String bookId) async =>
      (await _repository.getMe(bookId)).successOrNull;

  /// AC2 的权限判据：只读成员不能记账。没有成员记录时（单人本地使用）
  /// 一律放行 —— 家庭共享是可选能力，不能反过来卡住单人用户。
  Future<bool> canWrite(String bookId) async {
    final m = await me(bookId);
    return m == null || m.role.canWrite;
  }

  Future<bool> canManageMembers(String bookId) async {
    final m = await me(bookId);
    return m == null || m.role.canManageMembers;
  }

  /// 首次使用时登记「我」（所有者）。幂等。
  Future<Result<Member>> ensureMe({required String bookId, required String deviceId}) async {
    final existing = await _repository.getMe(bookId);
    if (existing.isSuccess && existing.requireValue != null) {
      return ok(existing.requireValue!);
    }
    final now = _clock.now();
    return _repository.create(Member(
      id: _idGen.generate(at: now),
      bookId: bookId,
      name: MemberRules.defaultMyName,
      role: MemberRole.owner,
      isMe: true,
      joinedAt: now,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    ));
  }

  /// 本机邀请码（首次生成后持久化，跨重启不变）。
  Future<String> inviteCode() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final existing = sp.getString(MemberRules.kPrefInviteCode) ?? '';
      if (existing.length == MemberRules.inviteCodeLength) return existing;
      final code = generateInviteCode();
      await sp.setString(MemberRules.kPrefInviteCode, code);
      return code;
    } catch (_) {
      return '';
    }
  }

  /// 生成邀请码：去掉容易看错的 0/O/1/I。
  static String generateInviteCode([Random? rnd]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = rnd ?? Random.secure();
    return List.generate(
      MemberRules.inviteCodeLength,
      (_) => alphabet[r.nextInt(alphabet.length)],
    ).join();
  }

  /// AC1：第 7 人加入被拦（只数活跃成员）。
  Future<Result<Member>> join({
    required String bookId,
    required String deviceId,
    required String code,
    required String name,
    MemberRole role = MemberRole.member,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return err(const ValidationFailure('member.name_required', 'name required'));
    }
    final expected = await inviteCode();
    if (expected.isEmpty || code.trim().toUpperCase() != expected) {
      return err(const ValidationFailure('member.invite_code_invalid', 'invalid code'));
    }
    final count = await _repository.countActive(bookId);
    if ((count.successOrNull ?? 0) >= MemberRules.maxActiveMembers) {
      return err(const ConflictFailure('member.too_many', 'max 6'));
    }
    final now = _clock.now();
    final existing = await _repository.listByBook(bookId);
    final order = (existing.successOrNull?.length ?? 0);
    return _repository.create(Member(
      id: _idGen.generate(at: now),
      bookId: bookId,
      name: trimmedName,
      role: role,
      joinedAt: now,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    ));
  }

  /// AC4：退出后不占名额（状态置 left，记录保留）。
  Future<Result<void>> leave(String memberId) =>
      _repository.leave(memberId, _clock.now());

  /// 改角色（仅所有者可做，调用方先判 [canManageMembers]）。
  Future<Result<Member>> changeRole(Member member, MemberRole role) =>
      _repository.update(member.copyWith(role: role, updatedAt: _clock.now()));

  /// 改名。
  Future<Result<Member>> rename(Member member, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(
          err<Member>(const ValidationFailure('member.name_required', 'name required')));
    }
    return _repository.update(member.copyWith(name: trimmed, updatedAt: _clock.now()));
  }

  /// 移除成员（软删，历史账单归属仍指向它）。
  Future<Result<void>> remove(String memberId) => _repository.softDelete(memberId);

  /// AC5：AA 平均分摊。
  ///
  /// 除不尽时**余数分给靠前的参与人**（100 分给 3 人 → 34/33/33），
  /// 保证 Σ 份额 == 账单金额，不会凭空多出或少掉 1 分。
  static List<AaShare> splitEqually(int totalCents, List<String> memberIds) {
    if (memberIds.isEmpty) return const [];
    final n = memberIds.length;
    final base = totalCents ~/ n;
    final remainder = totalCents % n;
    return [
      for (var i = 0; i < n; i++)
        AaShare(memberId: memberIds[i], cents: base + (i < remainder ? 1 : 0)),
    ];
  }

  /// 按成员 id 解析出显示名（已退出者标「已退出成员」）。
  static String labelOf(String memberId, Map<String, Member> byId, AppStrings s) =>
      byId[memberId]?.attributionLabel(s) ?? s.unknownMember;

  Future<Result<void>> setParticipants({
    required String entryId,
    required String bookId,
    required List<String> memberIds,
    required String deviceId,
  }) =>
      _repository.setParticipants(
        entryId: entryId,
        bookId: bookId,
        memberIds: memberIds,
        deviceId: deviceId,
      );

  Future<Result<List<EntryParticipant>>> participantsOf(String entryId) =>
      _repository.participantsOf(entryId);
}

/// 本机成员（「我」）；未登记时为 null。
final myMemberProvider = FutureProvider<Member?>((ref) async {
  final deps = ref.watch(appDependenciesProvider);
  return deps.memberService.me(deps.bookId);
});

/// STORY-8.2 AC2：本机是否有记账权限。
///
/// 没有成员记录时（单人本地使用）返回 true —— 家庭共享是可选能力，
/// 不该反过来卡住单人用户。记账页保存点会再用服务层判一次（双保险）。
final canWriteLedgerProvider = Provider<bool>((ref) {
  final me = ref.watch(myMemberProvider).value;
  return me == null || me.role.canWrite;
});
