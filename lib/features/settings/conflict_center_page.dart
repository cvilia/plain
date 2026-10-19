/// STORY-8.1 冲突中心（SP-5-09）：两端同一字段改成不同值时在这里裁决。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/sync_conflict.dart';
import 'package:plain/domain/services/sync_conflict_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';

final _conflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final service = SyncConflictService(
    repository: deps.syncConflictRepository,
    applier: deps.syncApplier,
    createEntry: deps.createEntry,
    clock: deps.clock,
    bookId: deps.bookId,
    deviceId: deps.deviceId,
  );
  return (await service.openConflicts()).successOrNull ?? const [];
});

class ConflictCenterPage extends ConsumerWidget {
  const ConflictCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final async = ref.watch(_conflictsProvider);
    return Scaffold(
      appBar: PlainTopBar(title: s.conflictCenterTitle, showBack: true),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return ContentWidthConstraint(
              child: AppEmptyState(
                icon: PlainIconData.check,
                title: s.conflictEmptyTitle,
                subtitle: s.conflictEmptySubtitle,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
            children: [
              Text(
                '共 ${conflicts.length} 条待裁决。合并时默认取了「最后写入」的一版，'
                '下面可以改成另一版；选「都保留」会另存一笔冲突副本。',
                style: TextStyle(
                  fontSize: 12,
                  height: designLineHeight(12) * 1.4,
                  color: context.colors.inkTertiary,
                ),
              ),
              const SizedBox(height: Spacing.md),
              for (final c in conflicts) _ConflictCard(conflict: c),
            ],
          );
        },
      ),
    );
  }
}

class _ConflictCard extends ConsumerStatefulWidget {
  const _ConflictCard({required this.conflict});
  final SyncConflict conflict;

  @override
  ConsumerState<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends ConsumerState<_ConflictCard> {
  bool _busy = false;

  Future<void> _resolve(ConflictResolution choice) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final service = SyncConflictService(
      repository: deps.syncConflictRepository,
      applier: deps.syncApplier,
      createEntry: deps.createEntry,
      clock: deps.clock,
      bookId: deps.bookId,
      deviceId: deps.deviceId,
    );
    setState(() => _busy = true);
    final res = await service.resolve(widget.conflict, choice);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isFailure) {
      showAppToast(context, '裁决失败：${res.failureOrNull!.code}');
      return;
    }
    showAppToast(context, s.conflictResolved(choice.label(s)));
    ref.invalidate(_conflictsProvider);
    ref.invalidateData.bumpEntryMutated();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.conflict;
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(Radii.r3),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlainIcon(PlainIconData.filter, size: 16, color: colors.inkFaint),
              const SizedBox(width: 6),
              Text(
                '${c.entityLabel} · ${c.field}',
                style: TextStyle(
                  fontSize: 15,
                  height: designLineHeight(15),
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _Side(
            label: s.conflictLocal,
            value: c.localValue,
            at: c.localChangedAt,
            highlight: c.winner == 'local',
          ),
          const SizedBox(height: 6),
          _Side(
            label: s.conflictRemote,
            value: c.remoteValue,
            at: c.remoteChangedAt,
            highlight: c.winner == 'remote',
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            children: [
              _ChoiceButton(
                label: s.conflictKeepLocalAction,
                busy: _busy,
                onPressed: () => _resolve(ConflictResolution.keepLocal),
              ),
              _ChoiceButton(
                label: s.conflictKeepRemoteAction,
                busy: _busy,
                onPressed: () => _resolve(ConflictResolution.keepRemote),
              ),
              if (c.entityType == 'transaction')
                _ChoiceButton(
                  label: s.conflictKeepBoth,
                  busy: _busy,
                  onPressed: () => _resolve(ConflictResolution.keepBoth),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.value,
    required this.at,
    required this.highlight,
  });

  final String label;
  final String? value;
  final DateTime? at;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = at == null
        ? ''
        : '（${at!.toLocal().toString().substring(0, 16)}）';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: designLineHeight(12),
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              color: highlight ? colors.primaryInk : colors.inkTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${value ?? '—'}$time',
            style: TextStyle(
              fontSize: 14,
              height: designLineHeight(14),
              color: colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.busy, required this.onPressed});
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      child: Text(label),
    );
  }
}
