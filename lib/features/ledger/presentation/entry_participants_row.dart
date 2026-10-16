/// STORY-8.2 AA 分摊：一笔账单标记参与人，自动平均分摊（AC5）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/services/member_service.dart';

/// 详情页的「参与分摊」行。
class EntryParticipantsRow extends ConsumerStatefulWidget {
  const EntryParticipantsRow({
    super.key,
    required this.entryId,
    required this.amountCents,
  });

  final String entryId;
  final int amountCents;

  @override
  ConsumerState<EntryParticipantsRow> createState() => _EntryParticipantsRowState();
}

class _EntryParticipantsRowState extends ConsumerState<EntryParticipantsRow> {
  List<Member> _members = const [];
  List<String> _participantIds = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final membersRes = await deps.memberService.allMembers(deps.bookId);
    final partsRes = await deps.memberService.participantsOf(widget.entryId);
    if (!mounted) return;
    setState(() {
      _members = membersRes.successOrNull ?? const [];
      _participantIds = [
        for (final p in partsRes.successOrNull ?? const <EntryParticipant>[]) p.memberId,
      ];
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final deps = ref.read(appDependenciesProvider);
    // 只列**在册**成员（已退出者不再出现在选择器里，PRD 8.2 生命周期）；
    // 但若该笔已标记了已退出成员，仍要显示出来，避免「标记凭空消失」
    final selectable = _members.where((m) => m.isActive).toList();
    final selected = {..._participantIds};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('谁一起花的', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: Spacing.sm),
                Text(
                  '选中的每个人平均分摊（共 ¥${formatAmount(widget.amountCents, hide: false)}）',
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12),
                    color: context.colors.inkTertiary,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final m in selectable)
                          CheckboxListTile(
                            value: selected.contains(m.id),
                            title: Text(m.name),
                            subtitle: Text(m.role.label),
                            onChanged: (v) => setSheet(() {
                              if (v == true) {
                                selected.add(m.id);
                              } else {
                                selected.remove(m.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                FilledButton(
                  onPressed: () async {
                    final res = await deps.memberService.setParticipants(
                      entryId: widget.entryId,
                      bookId: deps.bookId,
                      memberIds: selected.toList(),
                      deviceId: deps.deviceId,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, res.isSuccess);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (mounted) showAppToast(context, '已更新参与人');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final byId = {for (final m in _members) m.id: m};
    final shares = MemberService.splitEqually(widget.amountCents, _participantIds);
    final label = _loading
        ? '…'
        : _participantIds.isEmpty
            ? '未标记'
            : '${_participantIds.map((id) => MemberService.labelOf(id, byId)).join('、')}'
                ' · 每人 ¥${formatAmount(shares.isEmpty ? 0 : shares.first.cents, hide: false)}';

    return InkWell(
      onTap: _loading ? null : _edit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Text(
              '参与分摊',
              style: TextStyle(
                fontSize: 14,
                height: designLineHeight(14),
                color: colors.inkTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  height: designLineHeight(14),
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            PlainIcon(PlainIconData.chevronRight, size: 16, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}
