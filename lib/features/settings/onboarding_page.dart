/// Onboarding (first launch). Quiet Ledger single screen.
/// Order: wordmark → claim → sub → amount sample → 3 features → CTA
/// See redesign-v3/08-SCREENS-SPEC/01-guide.md.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, this.onDone});
  final Future<void> Function()? onDone;

  Future<void> _done(BuildContext context) async {
    final done = onDone;
    if (done != null) {
      await done();
    } else if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 字标
              Text(
                '素记 Plain',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.06 * 15,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 30),
              // 2. 主张
              Text(
                '记账，三秒钟的事',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              // 3. 副题
              Text(
                '本地存储 · 无广告 · 无理财',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: colors.inkTertiary,
                ),
              ),
              const SizedBox(height: 28),
              // 4. 产品实样：两条发丝线夹金额（结构靠线，无卡片）
              Divider(height: 1, thickness: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月结余',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08 * 12,
                        color: colors.inkTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AmountDisplay(cents: 1248000, fontSize: 34),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: colors.border),
              const SizedBox(height: 8),
              // 5. 三条特性
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    _Feature(
                      icon: PlainIconData.navAdd,
                      title: '三秒记一笔',
                      subtitle: '只记数字，不填表格',
                    ),
                    _Feature(
                      icon: PlainIconData.lock,
                      title: '数据只在你手机里',
                      subtitle: '没有账号，没有服务器',
                    ),
                    _Feature(
                      icon: PlainIconData.palette,
                      title: '十套配色，昼夜两态',
                      subtitle: '冷底暖点，久看不累',
                    ),
                  ],
                ),
              ),
              // 6. CTA
              PlainPrimaryButton(
                label: '开始记账',
                onPressed: () => _done(context),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '数据全部本地存储 · 卸载前请先备份',
                  style: TextStyle(fontSize: 12, color: colors.inkFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final PlainIconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlainIcon(icon, size: 22, color: colors.inkSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
