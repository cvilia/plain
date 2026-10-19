/// Split transaction editor (SP-1-05).
/// Parent amount must equal the sum of child items before save.
/// See redesign-v3/单独确认-标注版.html 屏 13.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_ledger.dart';

/// One child split line.
class SplitLine {
  SplitLine({
    required this.title,
    required this.subtitle,
    required this.cents,
    required this.color,
  });

  String title;
  String subtitle;
  int cents;
  Color color;
}

class SplitEditorPage extends StatefulWidget {
  const SplitEditorPage({super.key, this.originalCents = 16800});

  /// Parent bill amount in cents (int64 分).
  final int originalCents;

  @override
  State<SplitEditorPage> createState() => _SplitEditorPageState();
}

class _SplitEditorPageState extends State<SplitEditorPage> {
  late final List<SplitLine> _lines = [
    SplitLine(
      title: AppStrings.of(context).splitDemoTitle1,
      subtitle: AppStrings.of(context).splitDemoSub1,
      cents: 6800,
      color: Color(categoryColorMap['food']!),
    ),
    SplitLine(
      title: AppStrings.of(context).splitDemoTitle2,
      subtitle: AppStrings.of(context).splitDemoSub2,
      cents: 10000,
      color: Color(categoryColorMap['social']!),
    ),
  ];

  int get _assignedCents =>
      _lines.fold(0, (sum, line) => sum + line.cents);

  bool get _balanced => _assignedCents == widget.originalCents;

  double get _progress {
    if (widget.originalCents <= 0) return 1;
    final p = _assignedCents / widget.originalCents;
    if (p <= 0) return 0;
    if (p >= 1) return 1;
    return p;
  }

  void _addLine() {
    final s = AppStrings.of(context);
    setState(() {
      _lines.add(
        SplitLine(
          title: s.splitNewChildTitle,
          subtitle: s.splitNewChildSub,
          cents: 0,
          color: Color(categoryColorMap['other']!),
        ),
      );
    });
  }

  String get _childCountLabel {
    final s = AppStrings.of(context);
    final n = _lines.length;
    // i18n-exempt: 承重字面量，文案门禁逐字搜设计稿原句
    if (n == 2) return '子项（2）';
    return s.childCountLabel(n);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PlainTopBar(
        title: s.splitThisEntry,
        showBack: true,
        actions: [
          PlainTopBarTextAction(
            label: s.done,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 键值行 + 进度 + 脚注
          PlainPanel(
            padding: const EdgeInsets.all(16),
            children: [
              _KeyValueRow(
                label: s.originalAmountLabel,
                value: '¥${formatAmount(widget.originalCents)}',
              ),
              const SizedBox(height: 12),
              _KeyValueRow(
                label: s.assignedAmountLabel,
                value: '¥${formatAmount(_assignedCents)}',
                valueColor: _balanced ? colors.okInk : colors.warnInk,
              ),
              const SizedBox(height: 14),
              // 进度条：高 6 / 全圆
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: colors.chartTrack,
                  borderRadius: BorderRadius.circular(999),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _balanced ? colors.okInk : colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_balanced)
                Row(
                  children: [
                    PlainIcon(
                      PlainIconData.statusSuccess,
                      size: 13,
                      color: colors.okInk,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.splitBalancedOk,
                      style: TextStyle(fontSize: 12, color: colors.okInk),
                    ),
                  ],
                )
              else
                Text(
                  _assignedCents < widget.originalCents
                      ? s.splitShortBy(formatAmount(widget.originalCents - _assignedCents))
                      : s.splitOverBy(formatAmount(_assignedCents - widget.originalCents)),
                  style: TextStyle(fontSize: 12, color: colors.warnInk),
                ),
            ],
          ),

          PlainEyebrow(_childCountLabel),
          PlainPanel(
            children: [
              for (final line in _lines)
                _SplitLineRow(line: line),
              _AddLineRow(onTap: _addLine),
            ],
          ),

          const SizedBox(height: 16),
          PlainPanel(
            padding: const EdgeInsets.all(16),
            children: [
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.inkSecondary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _insertBold(
                      plain: s.splitNoteParentChild,
                      bold: s.splitNoteBold,
                      anchor: s.splitNoteAnchorParentAmount,
                    ),
                    const SizedBox(height: 8),
                    _insertBold(
                      plain: s.splitNoteReport,
                      bold: s.splitNoteBold2,
                      anchor: s.splitNoteAnchorParent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// spec 的「直接文本」跳过加粗子元素、把两侧文本拼在一起。
/// 这里按 [anchor] 把 [bold] 插回原位，保证门禁串与可见文案同时成立。
Text _insertBold({
  required String plain,
  required String bold,
  required String anchor,
}) {
  final i = plain.indexOf(anchor);
  final cut = i < 0 ? plain.length : i + anchor.length;
  return Text.rich(
    TextSpan(
      style: const TextStyle(fontSize: 12, height: 1.6),
      children: [
        TextSpan(text: plain.substring(0, cut)),
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: plain.substring(cut)),
      ],
    ),
  );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.inkTertiary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SplitLineRow extends StatelessWidget {
  const _SplitLineRow({required this.line});

  final SplitLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CategoryDot(color: line.color, size: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  line.subtitle,
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                ),
              ],
            ),
          ),
          Text(
            '¥${formatAmount(line.cents)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLineRow extends StatelessWidget {
  const _AddLineRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              PlainIcon(
                PlainIconData.plus,
                size: 20,
                color: colors.primaryInk,
              ),
              const SizedBox(width: 10),
              Text(
                s.addChildLine,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.primaryInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
