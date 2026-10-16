/// Donut chart with drill-down. Quiet Ledger: four-part center amount +
/// legend rows (name / pct / amount), segments sorted descending.
/// See redesign-v3/08-SCREENS-SPEC/05-reports.md.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// Data for one donut segment. [value] is cents.
class DonutSegment {
  const DonutSegment({
    required this.name,
    required this.value,
    required this.color,
    this.children = const [],
  });

  final String name;
  final int value;
  final Color color;
  final List<DonutSegment> children;
}

/// Interactive donut chart with click-to-drill.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.onSegmentTap,
    this.drillSegment,
    this.onDrillBack,
    this.onSubcategoryTap,
    this.size = 200,
  });

  final List<DonutSegment> segments;
  final void Function(DonutSegment segment) onSegmentTap;
  final DonutSegment? drillSegment;
  final VoidCallback? onDrillBack;
  final void Function(DonutSegment sub)? onSubcategoryTap;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final raw = widget.drillSegment?.children ?? widget.segments;
    // Design: legend sorted descending by value.
    final segments = [...raw]..sort((a, b) => b.value.compareTo(a.value));
    final total = segments.fold(0, (sum, s) => sum + s.value);

    return Column(
      children: [
        if (widget.drillSegment != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const PlainIcon(PlainIconData.back, size: 18),
                  onPressed: widget.onDrillBack,
                ),
                Text(
                  widget.drillSegment!.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent) {
                        final idx =
                            pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1;
                        setState(() => _touchedIndex = idx);
                        if (idx >= 0 && idx < segments.length) {
                          final seg = segments[idx];
                          if (widget.drillSegment != null) {
                            widget.onSubcategoryTap?.call(seg);
                          } else {
                            widget.onSegmentTap(seg);
                          }
                        }
                      }
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * 0.33,
                  sections: _buildSections(segments, total),
                ),
              ),
              // Quiet Ledger center: four-part amount + TOTAL
              //
              // ⚠️ 中心这块**不是 `.amt` 系列**。`spec.json` 实测（SP-3-01）：
              // `.dn-c1` = `size:20 · wt:600 · lh:normal · ls:normal`，行盒 27；
              // `.dn-cur/.dn-dec` = `size:12.4`（0.62em）· `lh:normal` · 行盒 16。
              // 两段都是 `normal` → **各按自身字号重算**，与 `.amt` 的比值继承相反。
              // `fontSize: 20` 不在 `.amt` 四档里，`amountLineHeight` 自动兜到
              // `designLineHeight`，正好是 27/20 与 12.4→16.44→16 ✓。
              // 但 tracking 要显式归零：`.dn-*` 是 `letter-spacing: normal`，
              // 只有 `.amt` 才带 `-.02em`。
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountDisplay(
                      cents: total,
                      fontSize: 20,
                      integerWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TOTAL',
                      // 设计 `.dn-c2`：size 12 · wt 600 · ls 1.2px（= .1em）· 行盒 16。
                      style: TextStyle(
                        fontSize: 12,
                        height: designLineHeight(12),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1 * 12,
                        color: context.colors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // Legend rows: dot / name / pct / amount
        for (final s in segments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${total == 0 ? 0 : (s.value / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 110,
                  child: AmountDisplay(
                    cents: s.value,
                    fontSize: 15,
                    integerWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(List<DonutSegment> segments, int total) {
    return segments.asMap().entries.map((entry) {
      final i = entry.key;
      final seg = entry.value;
      final isTouched = i == _touchedIndex;

      return PieChartSectionData(
        value: seg.value.toDouble(),
        title: '',
        color: seg.color,
        radius: isTouched ? 58 : 52,
        titleStyle: const TextStyle(fontSize: 0),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.ink,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  seg.name,
                  style: TextStyle(fontSize: 12, color: context.colors.surface),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.15,
      );
    }).toList();
  }
}
