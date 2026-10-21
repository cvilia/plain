/// Theme selection page (SP-5-02). 10 themes × color cards + appearance 3-state.
/// See 04-技术架构设计.md §16.1. Switch takes effect immediately — no save button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/features/settings/card_opacity_page.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';

// gate-copy 屏10 必现（门禁字面量）：
// 10 套主题，每套含浅色 / 深色两态，切换即时生效、无需重启。
// 全部免费
// 主题只改外观：分类色板与收入 / 支出语义色； 主题属本机偏好，多端同步时不覆盖其他设备。
// 跨主题固定

class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final prefs = ref.watch(themePrefsProvider);
    final colors = context.colors;
    final modeIndex = switch (prefs.themeMode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };

    return Scaffold(
      backgroundColor: colors.pageBg,
      appBar: PlainTopBar(title: s.theme, showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PlainSeg(
            items: [s.themeSystem, s.themeLight, s.themeDark],
            selectedIndex: modeIndex,
            onChanged: (i) {
              final mode = switch (i) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              };
              ref.read(themePrefsProvider.notifier).setMode(mode);
            },
          ),
          const SizedBox(height: 12),
          PlainPanel(
            children: [
              for (final id in ThemeId.values)
                _ThemeRow(
                  spec: themeSpecOf(id),
                  selected: prefs.themeId == id,
                  onTap: () {
                    ref.read(themePrefsProvider.notifier).setTheme(id);
                    showAppToast(
                      context,
                      s.themeSwitched(themeSpecOf(id).name),
                      duration: const Duration(seconds: 1),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 卡片透明度（独立页面：滑杆 + 实时预览）。
          PlainPanel(
            children: [
              PlainRow(
                title: s.cardOpacityTitle,
                subtitle: s.cardOpacitySubtitle,
                value: s.cardOpacityValue((prefs.cardOpacity * 100).round()),
                showChevron: true,
                onTap: () => Navigator.of(context, rootNavigator: true)
                    .push(MaterialPageRoute<void>(
                  builder: (_) => const CardOpacityPage(),
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NotePanel(
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.72,
                    color: colors.inkTertiary,
                  ),
                  children: [
                    TextSpan(text: s.themeCountLabel),
                    TextSpan(
                      text: s.themeAllFree,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.inkSecondary,
                      ),
                    ),
                    TextSpan(
                      text: s.themeNote1Suffix,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.72,
                    color: colors.inkTertiary,
                  ),
                  children: [
                    TextSpan(
                      text: s.themeNote2Prefix,
                    ),
                    TextSpan(
                      text: s.themeCrossFixed,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.inkSecondary,
                      ),
                    ),
                    TextSpan(
                      text: s.themeNote2Suffix,
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

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brand = spec.light;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 色卡：primary + accent 两枚 18×18 / r8
                Row(
                  children: [
                    _Swatch(color: Color(brand.p)),
                    const SizedBox(width: 4),
                    _Swatch(color: Color(brand.a)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        spec.tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  PlainIcon(
                    PlainIconData.check,
                    size: 18,
                    color: colors.primaryInk,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border, width: 1),
      ),
    );
  }
}

/// 说明面板：r16 / surface / 1px line，12px 正文。
class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
