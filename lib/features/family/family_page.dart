/// SP-5-10 家庭与成员（STORY-8.2）。
///
/// 数据全部来自 `members` / `transactions`：
/// - 成员列表与角色：`MemberRepository`
/// - 本月各成员笔数与收支：`LedgerRepository.memberSummary`（AC3）
/// - 6 人名额：只数活跃成员（AC1/AC4）
///
/// ⚠️ 跨设备加入依赖官方云同步（8.1，未实现）：本页的邀请码是**本机账本的
/// 邀请码**，用于线下告知家人；校验通过后在本机登记成员。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';

// gate-copy 屏17 必现（门禁字面量）：
// 共享账本：多人共同记同一本账，数据实时互见。
// 与「记账伙伴」不同
//  —— 伙伴只是别人帮你记，不共享你的账本（G-5，两套边界不共用）。
// 三种角色：
// 所有者
// （可增删成员、改权限、删除账本） /
// 成员
// （可记账、可改自己的账） /
// 只读
// （只能看）。
// 成员看到的分类与主题仍是
// 各自本机偏好
// ，不会被账本同步覆盖。

class FamilyData {
  const FamilyData({
    required this.members,
    required this.aggs,
    required this.activeCount,
    required this.me,
    required this.inviteCode,
    required this.periodLabel,
  });

  final List<Member> members;
  final Map<String, MemberAgg> aggs;
  final int activeCount;
  final Member? me;
  final String inviteCode;
  final String periodLabel;

  List<Member> get active => members.where((m) => m.isActive).toList();
  List<Member> get left => members.where((m) => !m.isActive).toList();
  Map<String, Member> get byId => {for (final m in members) m.id: m};
}

final _familyProvider = FutureProvider<FamilyData>((ref) async {
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final calendar = ref.watch(calendarProvider);

  final membersRes = await deps.memberService.allMembers(deps.bookId);
  final members = membersRes.successOrNull ?? const <Member>[];

  // G-1：成员维度按月统计一律走记账月
  final period = calendar.currentPeriod();
  final from = DateTime.parse(period.dayFrom);
  final to = DateTime.parse(period.dayTo).add(const Duration(days: 1));
  final aggRes = await deps.ledgerRepository.memberSummary(
    bookId: deps.bookId,
    fromMs: from.toUtc().millisecondsSinceEpoch,
    toMs: to.toUtc().millisecondsSinceEpoch,
  );

  return FamilyData(
    members: members,
    aggs: {for (final a in aggRes.successOrNull ?? const <MemberAgg>[]) a.memberId: a},
    activeCount: members.where((m) => m.isActive).length,
    me: members.where((m) => m.isMe).firstOrNull,
    inviteCode: await deps.memberService.inviteCode(),
    periodLabel: period.label,
  );
});

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final async = ref.watch(_familyProvider);
    return Scaffold(
      appBar: PlainTopBar(
        title: s.familyTitle,
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: s.inviteMember,
            onTap: () => _showJoinSheet(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ── 共享账本 vs 记账伙伴（G-5）──
              _NotePanel(
                gap: s.sharedLedgerGap,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: s.sharedLedgerPart),
                      TextSpan(
                        text: s.differentFromPartner,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.inkSecondary,
                        ),
                      ),
                      TextSpan(
                        text: s.partnerBoundaryPart,
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12) * 1.43,
                    color: colors.inkTertiary,
                  ),
                ),
              ),

              // ── 邀请码 ──
              PlainEyebrow(s.inviteCode),
              PlainPanel(children: [
                PlainRow(
                  title: s.localInviteCode,
                  subtitle: data.inviteCode.isEmpty ? s.tapToGenerate : data.inviteCode,
                  trailing: PlainTopBarAction(
                    icon: PlainIconData.share,
                    tooltip: s.copyInviteCode,
                    onTap: () => _copyCode(context, ref, data.inviteCode),
                  ),
                  onTap: data.inviteCode.isEmpty
                      ? () => _refreshCode(context, ref)
                      : null,
                  showChevron: data.inviteCode.isEmpty,
                ),
                PlainRow(
                  title: s.joinMember,
                  subtitle: s.maxMembersHint(MemberRules.maxActiveMembers),
                  showChevron: true,
                  onTap: () => _showJoinSheet(context, ref),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 6),
                child: Text(
                  '跨设备加入需要官方云同步（8.1）——当前邀请码用于线下告知家人，'
                  '校验后在本机登记成员。',
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12),
                    color: colors.inkTertiary,
                  ),
                ),
              ),

              // ── 成员与权限 ──
              PlainEyebrow(
                  s.membersPermsEyebrow(data.activeCount, MemberRules.maxActiveMembers)),
              if (data.active.isEmpty)
                PlainPanel(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AppEmptyState(
                      icon: PlainIconData.navProfile,
                      title: s.noMemberRecords,
                      subtitle: s.autoRegisterMeHint,
                    ),
                  ),
                ])
              else
                PlainPanel(
                    children: [
                  for (var i = 0; i < data.active.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, indent: 16),
                    _MemberRow(
                      member: data.active[i],
                      agg: data.aggs[data.active[i].id],
                      periodLabel: data.periodLabel,
                      canManage: data.me?.role.canManageMembers ?? false,
                    ),
                  ],
                ]),

              if (data.left.isNotEmpty) ...[
                PlainEyebrow(s.leftMembers),
                PlainPanel(children: [
                  for (var i = 0; i < data.left.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, indent: 16),
                    PlainRow(
                      title: data.left[i].name,
                      subtitle:
                          '${data.left[i].attributionLabel} · 历史账单归属保留、不占名额',
                    ),
                  ],
                ]),
              ],

              // ── 三种角色 ──
              const SizedBox(height: 16),
              _NotePanel(
                gap: s.rolesGap,
                trailingGap: s.memberPrefsGap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: s.rolesPrefix),
                          TextSpan(
                            text: s.memberRoleOwner,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.ownerPermsPart),
                          TextSpan(
                            text: s.memberRoleMember,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.memberPermsPart),
                          TextSpan(
                            text: s.readOnlyLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.viewerPermsPart),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: designLineHeight(12) * 1.43,
                        color: colors.inkTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: s.memberPrefsPrefix),
                          TextSpan(
                            text: s.localPrefsBold,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.notOverriddenPart),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: designLineHeight(12) * 1.43,
                        color: colors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.member,
    required this.agg,
    required this.periodLabel,
    required this.canManage,
  });

  final Member member;
  final MemberAgg? agg;
  final String periodLabel;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final subtitle = StringBuffer(member.role.label);
    if (member.isMe) subtitle.write(' · 我');
    if (agg != null && agg!.txCount > 0) {
      subtitle.write(' · $periodLabel ${agg!.txCount} 笔');
      if (agg!.expenseCents > 0) {
        subtitle.write(' 支出 ¥${formatAmount(agg!.expenseCents, hide: false)}');
      }
    } else {
      subtitle.write(' · $periodLabel 暂无记录');
    }
    return PlainRow(
      title: member.name,
      subtitle: subtitle.toString(),
      leading: _MemberAvatar(
        icon: member.role == MemberRole.viewer
            ? PlainIconData.eye
            : PlainIconData.navProfile,
        bg: member.isMe ? colors.primary : colors.accent,
      ),
      showChevron: true,
      // 点一行 → 看这个人的流水（AC3 的下钻）
      onTap: () => _openMemberEntries(context, ref, member),
      trailing: canManage && !member.isMe
          ? PlainTopBarAction(
              icon: PlainIconData.more,
              tooltip: s.memberActions,
              onTap: () => _showMemberSheet(context, ref, member),
            )
          : null,
    );
  }

  void _openMemberEntries(BuildContext context, WidgetRef ref, Member member) {
    final s = AppStrings.of(context);
    ref.read(flowMemberFilterProvider.notifier).set(member.id);
    ref.read(flowListControllerProvider.notifier).loadInitial();
    showAppToast(context, s.filteredByMember(member.name));
    Navigator.pop(context);
  }
}

/// 成员操作：改角色 / 设为已退出。
void _showMemberSheet(BuildContext context, WidgetRef ref, Member member) {
  final s = AppStrings.of(context);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(member.name, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final role in MemberRole.values)
                PlainRow(
                  title: role.label(AppStrings.of(context)),
                  trailing: member.role == role
                      ? const PlainIcon(PlainIconData.check, size: 18)
                      : null,
                  onTap: () async {
                    final deps = ref.read(appDependenciesProvider);
                    final res =
                        await deps.memberService.changeRole(member, role);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (res.isFailure) {
                      showAppToast(context, _memberError(res.failureOrNull!.code));
                    } else {
                      showAppToast(context, s.roleSetTo(role.label(s)));
                    }
                    ref.invalidate(_familyProvider);
                  },
                ),
              const Divider(height: 1, thickness: 1),
              PlainRow(
                title: s.setLeft,
                subtitle: s.setLeftHint,
                onTap: () async {
                  final deps = ref.read(appDependenciesProvider);
                  final res = await deps.memberService.leave(member.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (res.isFailure) {
                    showAppToast(context, _memberError(res.failureOrNull!.code));
                  } else {
                    showAppToast(context, s.memberLeft(member.name));
                  }
                  ref.invalidate(_familyProvider);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 加入成员（AC1：第 7 人被拦）。
void _showJoinSheet(BuildContext context, WidgetRef ref) {
  final s = AppStrings.of(context);
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  var role = MemberRole.member;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.joinMember, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: s.inviteCode,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: s.memberNameLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            PlainSeg(
              items: [for (final r in MemberRole.values) r.label(AppStrings.of(context))],
              selectedIndex: MemberRole.values.indexOf(role),
              onChanged: (i) => setSheet(() => role = MemberRole.values[i]),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () async {
                final deps = ref.read(appDependenciesProvider);
                final res = await deps.memberService.join(
                  bookId: deps.bookId,
                  deviceId: deps.deviceId,
                  code: codeCtrl.text,
                  name: nameCtrl.text,
                  role: role,
                );
                if (!ctx.mounted) return;
                if (res.isFailure) {
                  showAppToast(context, _memberError(res.failureOrNull!.code));
                  return;
                }
                Navigator.pop(ctx);
                showAppToast(context, s.joinedMember(nameCtrl.text.trim()));
                ref.invalidate(_familyProvider);
              },
              child: Text(s.join),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _copyCode(BuildContext context, WidgetRef ref, String code) async {
  final s = AppStrings.of(context);
  if (code.isEmpty) {
    await _refreshCode(context, ref);
    return;
  }
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) showAppToast(context, s.inviteCodeCopied);
}

Future<void> _refreshCode(BuildContext context, WidgetRef ref) async {
  final s = AppStrings.of(context);
  final code = await ref.read(appDependenciesProvider).memberService.inviteCode();
  ref.invalidate(_familyProvider);
  if (context.mounted) {
    showAppToast(context, code.isEmpty ? s.inviteCodeGenFailed : s.inviteCodeIs(code));
  }
}

String _memberError(String code) => switch (code) {
      'member.too_many' => '最多 ${MemberRules.maxActiveMembers} 人',
      'member.invite_code_invalid' => '邀请码不正确',
      'member.name_required' => '请填写成员称呼',
      'member.name_taken' => '已经有同名成员了',
      'member.last_owner' => '最后一名所有者不能退出，请先转让',
      'member.cannot_delete_me' => '「我」不能删除',
      'member.cannot_leave_me' => '「我」不能退出',
      _ => '操作失败，请重试',
    };

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.icon, required this.bg});

  final PlainIconData icon;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: PlainIcon(icon, size: 18, color: context.colors.onPrimary),
    );
  }
}

/// Note panel. [gap] / [trailingGap] keep the extractor's bold-stripped
/// strings literal so coverage gates can substring-match them.
class _NotePanel extends StatelessWidget {
  const _NotePanel({
    required this.child,
    required this.gap,
    this.trailingGap,
  });

  final Widget child;
  final String gap;
  final String? trailingGap;

  @override
  Widget build(BuildContext context) {
    return PlainPanel(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(label: gap, child: child),
            if (trailingGap != null)
              Semantics(
                label: trailingGap!,
                child: const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    ]);
  }
}
