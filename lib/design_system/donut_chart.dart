/// Donut chart with drill-down. See PRD STORY-3.1 AC2.
/// Click sector -> expand to subcategories -> click subcategory -> filter list.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';

/// Data for one donut segment.
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

  /// When non-null, showing subcategories of this segment.
  final DonutSegment? drillSegment;
  final VoidCallback? onDrillBack;
  final void Function(DonutSegment sub)? onSubcategoryTap;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  final int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final segments = widget.drillSegment?.children ?? widget.segments;
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
                  icon: const Icon(Icons.arrow_back, size: 18),
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
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (event is FlTapUpEvent) {
                    final idx = pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1;
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
              centerSpaceRadius: widget.size * 0.25,
              sections: _buildSections(segments, total),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        // Legend
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.xs,
          alignment: WrapAlignment.center,
          children: segments.map((s) {
            final pct = total == 0 ? 0.0 : (s.value / total * 100);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.name} ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: context.colors.inkSecondary),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(List<DonutSegment> segments, int total) {
    return segments.asMap().entries.map((entry) {
      final i = entry.key;
      final seg = entry.value;
      final pct = total == 0 ? 0.0 : (seg.value / total * 100);
      final isTouched = i == _touchedIndex;

      return PieChartSectionData(
        value: seg.value.toDouble(),
        title: '${pct.toStringAsFixed(1)}%',
        color: seg.color,
        radius: isTouched ? 55 : 48,
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.ink,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  seg.name,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.2,
      );
    }).toList();
  }
}
