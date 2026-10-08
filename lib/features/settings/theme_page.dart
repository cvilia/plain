/// Theme selection page (SP-5-02). 10 themes × color cards + appearance 3-state.
/// See 04-技术架构设计.md §16.1. Switch takes effect immediately — no save button.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/section_title.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_registry.dart';

class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance 3-state ──
          SectionTitle('外观', color: context.colors.inkTertiary),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            style: SegmentedButton.styleFrom(textStyle: const TextStyle(fontSize: 13)),
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
            ],
            selected: {prefs.themeMode},
            onSelectionChanged: (s) {
              ref.read(themePrefsProvider.notifier).setMode(s.first);
            },
          ),
          const SizedBox(height: 24),

          // ── Theme grid ──
          SectionTitle('主题', color: context.colors.inkTertiary),
          const SizedBox(height: 8),
          ...ThemeId.values.map((id) => _ThemeCard(
            spec: themeSpecOf(id),
            selected: prefs.themeId == id,
            onTap: () {
              ref.read(themePrefsProvider.notifier).setTheme(id);
              showAppToast(context, '已切换主题：${id.name}', duration: const Duration(seconds: 1));
            },
          )),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.spec, required this.selected, required this.onTap});

  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Show 3 dots: body bg / primary / accent (use light palette for preview)
    final brand = spec.light;
    final tone = toneOf(spec.tone, false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Color(brand.pd) : context.colors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 3 color dots
              SizedBox(
                width: 72,
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 0, child: _Dot(color: Color(tone.bg))),
                    Positioned(left: 18, child: _Dot(color: Color(brand.p))),
                    Positioned(left: 36, child: _Dot(color: Color(brand.a))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Name + tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(spec.tag, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
                  ],
                ),
              ),
              // Checkmark — use deep primary so light themes stay visible on card
              if (selected)
                Icon(Icons.check_circle, color: Color(brand.pd), size: 22)
              else
                Icon(Icons.circle_outlined, color: context.colors.inkTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.divider, width: 1),
      ),
    );
  }
}
