/// 卡片透明度（主题页 → 独立页）：滑杆调节 + 实时预览。
///
/// 口径（2026-10-20 用户需求）：「透明度可以自定义，通过拖拽进度条的方式，
/// 并且可以实时看到实际效果」。
///
/// 实现要点：
/// - 拖动的每一帧都写 `ThemePrefs.cardOpacity` → `main` 重建 `ThemeData`
///   → 全 app（含本页的预览卡）立刻跟着变，这才是「实时看到实际效果」；
///   松手才落盘（`persist: true`），避免每帧写 SharedPreferences。
/// - 预览区不是假图：它用的就是 `context.colors` 里的同一批令牌
///   （pageBg / surface / surfaceMuted / border），和真页面同源。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/design_system/plain_ui.dart';

/// 预览卡片的定位 key（只给测试用，业务不读它）。
const Key kCardOpacityPreviewCardKey = ValueKey('cardOpacityPreviewCard');

/// 滑杆的定位 key。
const Key kCardOpacitySliderKey = ValueKey('cardOpacitySlider');

class CardOpacityPage extends ConsumerWidget {
  const CardOpacityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final prefs = ref.watch(themePrefsProvider);
    final notifier = ref.read(themePrefsProvider.notifier);
    final pct = (prefs.cardOpacity * 100).round();

    return Scaffold(
      backgroundColor: colors.pageBg,
      appBar: PlainTopBar(title: s.cardOpacityTitle, showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 实时预览：迷你「流水页」，全部走真实令牌 ──
          PlainEyebrow(s.cardOpacityPreviewTitle,
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 8)),
          _Preview(
            chip1: s.cardOpacityDemoChip1,
            chip2: s.cardOpacityDemoChip2,
            amount: s.cardOpacityDemoAmount,
            category: s.cardOpacityDemoCategory,
            keyLabel: s.cardOpacityDemoKey,
          ),

          const SizedBox(height: Spacing.lg),

          // ── 滑杆 ──
          PlainPanel(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.cardOpacityTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      s.cardOpacityValue(pct),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.primaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.lineStrong,
                    thumbColor: colors.primary,
                    overlayColor: colors.primary.withValues(alpha: 0.12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    key: kCardOpacitySliderKey,
                    value: prefs.cardOpacity.clamp(0.0, 1.0),
                    // 每帧都改状态：主题立刻重建 → 预览与整页实时变化。
                    onChanged: (v) => notifier.setCardOpacity(v, persist: false),
                    // 松手才落盘。
                    onChangeEnd: (v) => notifier.setCardOpacity(v),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    Text(
                      s.cardOpacityMinLabel,
                      style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                    ),
                    const Spacer(),
                    Text(
                      s.cardOpacityMaxLabel,
                      style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Spacing.md),
          PlainRow(
            title: s.cardOpacityReset,
            subtitle: '${(kCardOpacityDefault * 100).round()}%',
            onTap: () => notifier.setCardOpacity(kCardOpacityDefault),
          ),

          const SizedBox(height: Spacing.lg),
          Text(
            s.cardOpacityHint,
            style: TextStyle(
              fontSize: 12,
              height: 1.72,
              color: colors.inkTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.cardOpacityNote,
            style: TextStyle(
              fontSize: 12,
              height: 1.72,
              color: colors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 迷你流水页：页面底 + 卡片 + 胶囊 + 键帽，全部读 `context.colors`。
class _Preview extends StatelessWidget {
  const _Preview({
    required this.chip1,
    required this.chip2,
    required this.amount,
    required this.category,
    required this.keyLabel,
  });

  final String chip1;
  final String chip2;
  final String amount;
  final String category;
  final String keyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.pageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 卡片
          Container(
            // 测试用它取真实渲染出来的卡片底色（验证「实时生效」）。
            key: kCardOpacityPreviewCardKey,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(fontSize: 12, color: colors.inkSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  '¥ -28.00',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 胶囊 chip + 键帽
          Row(
            children: [
              _Chip(label: chip1),
              const SizedBox(width: 8),
              _Chip(label: chip2),
              const Spacer(),
              Container(
                width: 44,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  keyLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: colors.inkSecondary),
      ),
    );
  }
}
