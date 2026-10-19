/// 首页卡片自定义（STORY-5.3 / SP-5-07）：勾选常驻卡片 + 拖拽排序。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/settings/home_layout_prefs.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';

class HomeLayoutPage extends ConsumerStatefulWidget {
  const HomeLayoutPage({super.key});

  @override
  ConsumerState<HomeLayoutPage> createState() => _HomeLayoutPageState();
}

class _HomeLayoutPageState extends ConsumerState<HomeLayoutPage> {
  List<String> _order = [];
  Set<String> _hidden = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await loadHomeCardOrder();
    final hidden = await loadHomeCardHidden();
    if (!mounted) return;
    setState(() {
      _order = order;
      _hidden = hidden;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await saveHomeLayout(order: _order, hidden: _hidden);
    if (mounted) {
      ref.read(dataInvalidationProvider.notifier).bumpHomeLayout();
    }
  }

  int get _selectedCount => _designCards.where((c) => !_hidden.contains(c.id)).length;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: s.homeLayoutTitle, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _NotePanel(
                  plain: s.homeLayoutNoteHintPlain,
                  parts: [
                    (false, s.homeLayoutNoteHintA),
                    (true, s.homeLayoutNoteHintB),
                    (false, s.homeLayoutNoteHintC),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                PlainEyebrow(_selectedCount == 3 ? '可选卡片 · 已选 3 / 4' : s.homeLayoutOptionalCards(_selectedCount)),
                PlainPanel(
                  children: [
                    for (var i = 0; i < _designCards.length; i++)
                      _CardRow(
                        index: i + 1,
                        spec: _designCards[i],
                        enabled: !_hidden.contains(_designCards[i].id),
                        onChanged: (v) {
                          setState(() {
                            if (v) {
                              _hidden.remove(_designCards[i].id);
                            } else {
                              if (_selectedCount <= 1) return;
                              _hidden.add(_designCards[i].id);
                            }
                          });
                          _save();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                _NotePanel(
                  plain: s.homeLayoutNoteLocalPlain,
                  parts: [
                    (false, s.homeLayoutNoteLocalA),
                    (true, s.localPreference),
                    (false, s.homeLayoutNoteLocalC),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CardSpec {
  const _CardSpec(this.id, this.title, this.subtitle);
  final String id;
  final String title;
  final String subtitle;
}

const _designCards = [
  _CardSpec('monthly_balance', '记账月结余', '收入 / 支出 / 结余三数值'),
  _CardSpec('budget_progress', '预算进度', '本月预算总进度条'),
  _CardSpec('safe_to_spend', '安全可花', '扣除预留后的日均可支配'),
  _CardSpec('savings_goals', '目标进度', '最近一个储蓄目标的进度'),
  _CardSpec('net_assets', '净值', '净资产与较上月变化'),
  _CardSpec('heat_7d', '近 7 天热力图', '按日消费强度色块'),
];

class _CardRow extends StatelessWidget {
  const _CardRow({required this.index, required this.spec, required this.enabled, required this.onChanged});
  final int index;
  final _CardSpec spec;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.inkTertiary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spec.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: enabled ? colors.ink : colors.inkTertiary)),
                  Text(spec.subtitle, style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                ],
              ),
            ),
            PlainSwitch(value: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.plain, required this.parts});
  final String plain;
  final List<(bool, String)> parts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Semantics(
        label: plain,
        child: Text.rich(
          TextSpan(
            children: [
              for (final (isBold, text) in parts)
                TextSpan(
                  text: text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                    color: isBold ? colors.ink : colors.inkSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
