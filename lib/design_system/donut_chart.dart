/// Donut chart with drill-down. Quiet Ledger: four-part center amount +
/// legend rows (name / pct / amount), segments sorted descending.
/// See redesign-v3/08-SCREENS-SPEC/05-reports.md.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/l10n/app_strings.dart';
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

/// 环几何与盒子尺寸。
///
/// ⚠️ **fl_chart 的 `radius` 是「环厚」，不是设计稿里的 `R`** —— 设计稿的 R 是
/// **中线半径**（`.donut 136×136 / R=52 / stroke-width=13`）。首版把 `R=52` 当环厚
/// 用，就成了下面这组「大环」数值 —— 这是**用户明确要的尺寸，别改小**
/// （2026-10-16：改成设计稿的 136/45.5/13 后用户回「不要缩小圆环」）。
///
/// 真正错的是**盒子**：首版 `kDonutSize = 200`，但环外半径 = 66 + 52 = 118 >
/// 盒子半径 100 ⇒ **圆环整体溢出容器 18pt**（按下加粗到 58 更到 24pt）。
/// 三个症状全是这一处：① 环顶压住上面的「分类占比」；② 环底顶到图例；
/// ③ 图例看着"贴"在环上。
///
/// 修法 = **环尺寸不动，把盒子放大到装得下**：环外直径 236，上下各留 9.5
/// （设计稿里环到盒子边的余量比例），得 255；按下时外直径 248 也仍装得下。
/// 于是「环 ↔ 文字」的间距与设计稿同一节奏：环顶距 eyebrow 底 21.5、环底距图例 23.5。
const double _kHoleRadius = 66;
const double _kRingWidth = 52;
const double _kRingWidthPressed = 58;

/// 画布边长。`size` 只做整体等比缩放（目前全库 1 个调用点，用默认值）。
const double kDonutSize = 255;

/// 图例默认显示几条（= 设计稿原型里的行数）。超出的折叠到「展开其余 N 类」里。
const int kLegendPreviewCount = 5;

/// Interactive donut chart with click-to-drill.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.onSegmentTap,
    this.drillSegment,
    this.onDrillBack,
    this.onSubcategoryTap,
    this.size = kDonutSize,
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
  /// 当前「按下」的那一段（-1 = 没有）。**只在按住期间有效**，抬手/取消立刻复位 ——
  /// 不做常驻状态：首版会在被点段的外侧挂一个常驻黑色气泡，它画在环外，
  /// 正好把下面的图例盖住（用户截图）。
  int _touchedIndex = -1;

  /// 图例是否已展开。默认只显示前 [kLegendPreviewCount] 条。
  ///
  /// 为什么必须封顶：分类可以有很多（预设就 12 个一级 + 41 个二级），
  /// 图例一行一类的写法会让这块面板**无限长高** —— 20 类就是 20 行 ≈ 620pt，
  /// 一个"分类占比"面板把整屏吃掉。封顶 5（= 设计稿原型里的行数）+「展开其余 N 类」，
  /// 默认高度恒定，要看全的再展开。
  bool _showAll = false;

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 钻进某一类 / 返回时，段集合整个换了 —— 展开态跟着复位，
    // 否则「上一层的展开」会莫名其妙作用到下一层。
    if (oldWidget.drillSegment?.name != widget.drillSegment?.name) {
      _showAll = false;
    }
  }

  /// 段序（按金额降序）—— 图例、扇区、点击回调**必须同取这一份**，否则索引错位。
  List<DonutSegment> get _segments {
    final raw = widget.drillSegment?.children ?? widget.segments;
    return [...raw]..sort((a, b) => b.value.compareTo(a.value));
  }

  void _onTouch(FlTouchEvent event, PieTouchResponse? response) {
    final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
    if (event is FlTapDownEvent || event is FlLongPressStart) {
      if (idx != _touchedIndex) setState(() => _touchedIndex = idx);
      return;
    }
    if (event is FlTapCancelEvent || event is FlLongPressEnd) {
      if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
      return;
    }
    if (event is! FlTapUpEvent) return;
    if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
    final segments = _segments;
    if (idx < 0 || idx >= segments.length) return;
    final seg = segments[idx];
    if (widget.drillSegment != null) {
      widget.onSubcategoryTap?.call(seg);
    } else {
      widget.onSegmentTap(seg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final segments = _segments;
    final total = segments.fold(0, (sum, s) => sum + s.value);
    // 几何按 `kDonutSize` 定，`size` 只做整体缩放（目前全库只有 1 个调用点，用默认值）。
    final scale = widget.size / kDonutSize;

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
                  pieTouchData: PieTouchData(touchCallback: _onTouch),
                  sectionsSpace: 2,
                  centerSpaceRadius: _kHoleRadius * scale,
                  sections: _buildSections(segments, scale),
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
                // ⚠️ 中心金额的**宽度硬约束**（`05-reports.md` §4.1 首版返工过）：
                // 可用宽 = 内孔直径 91 − 左右各 2 = **87**。`AmountDisplay` 自己
                // **不会降档**，超长值会直接压在圆环上（暗态尤其明显）。
                // 按全库既有做法套 `FittedBox.scaleDown`（「金额永不截断」的
                // 最后手段，宽度够时是空操作，见 `entry_input_page`/`credit_reconcile_page`）。
                child: SizedBox(
                  width: (_kHoleRadius * 2 - 4) * scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Legend rows: dot / name / pct / amount
        // ⚠️ 上面这 14 = 设计 `.donut-wrap{padding:4px 0 14px}` 的下内边距；环自身
        // 在 255 的盒子里还有 9.5 的余量，所以环底→首行图例的实际视觉间距 ≈ 23.5 ✓。
        //
        // 默认只渲染前 `kLegendPreviewCount` 条：分类数量是不设上限的，
        // 一行一类会让面板无限长高（详见 `_showAll` 的注释）。
        for (final s in _showAll ? segments : segments.take(kLegendPreviewCount))
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
        // 折叠入口：只在「确实有被折起来的分类」时出现。
        if (segments.length > kLegendPreviewCount)
          InkWell(
            onTap: () => setState(() => _showAll = !_showAll),
            borderRadius: BorderRadius.circular(Radii.r2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showAll ? s.collapse : s.expandRemaining(segments.length - kLegendPreviewCount),
                    style: TextStyle(
                      // 字阶只有 44/34/22/20/15/14/12，别用 13（字阶门禁会拦）。
                      fontSize: 14,
                      height: designLineHeight(14),
                      fontWeight: FontWeight.w500,
                      color: context.colors.inkTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PlainIcon(
                    _showAll ? PlainIconData.chevronUp : PlainIconData.chevronDown,
                    size: 16,
                    color: context.colors.inkTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 扇区半径 = **环厚**（不是中线半径 R）。按下加粗一档做点击反馈。
  ///
  /// 这里**不挂 `badgeWidget`**：badge 的位置是
  /// `centerRadius + radius × badgePositionPercentageOffset`，天生画在环**外**，
  /// 底部那一段的气泡必然盖住下面的图例。名字与金额图例里都有，不需要气泡。
  List<PieChartSectionData> _buildSections(
    List<DonutSegment> segments,
    double scale,
  ) {
    return [
      for (var i = 0; i < segments.length; i++)
        PieChartSectionData(
          value: segments[i].value.toDouble(),
          title: '',
          color: segments[i].color,
          radius: (i == _touchedIndex ? _kRingWidthPressed : _kRingWidth) * scale,
          titleStyle: const TextStyle(fontSize: 0),
        ),
    ];
  }
}
