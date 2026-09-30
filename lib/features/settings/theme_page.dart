/// Theme selection page (SP-5-02). 10 themes × color cards + appearance 3-state.
/// See 需求变更.md §2.1. Switch takes effect immediately — no save button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/design_tokens.dart';
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
          Text('外观', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BrandColors.inkTertiary)),
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
          Text('主题', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BrandColors.inkTertiary)),
          const SizedBox(height: 8),
          ...ThemeId.values.map((id) => _ThemeCard(
            spec: themeSpecOf(id),
            selected: prefs.themeId == id,
            onTap: () {
              ref.read(themePrefsProvider.notifier).setTheme(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已切换主题：${id.name}'), duration: const Duration(seconds: 1)),
              );
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
          color: selected ? Color(brand.pd) : BrandColors.divider,
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
                    Text(spec.tag, style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary)),
                  ],
                ),
              ),
              // Checkmark — use deep primary so light themes stay visible on card
              if (selected)
                Icon(Icons.check_circle, color: Color(brand.pd), size: 22)
              else
                Icon(Icons.circle_outlined, color: BrandColors.inkTertiary, size: 22),
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
        border: Border.all(color: BrandColors.divider, width: 1),
      ),
    );
  }
}
