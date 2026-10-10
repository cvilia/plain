/// Onboarding (first launch). Matches 09-高保真UI.html SP-0-01.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/brand_mark.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onDone});
  final Future<void> Function()? onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      final done = widget.onDone;
      if (done != null) {
        done();
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceCard,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _ObStep(
                    brandMark: true,
                    logo: '记',
                    title: '3 秒，记一笔',
                    subtitle: '选好分类点 OK 即可，键盘极简\n数字/小数点/OK · 离线全功能',
                    onPrimary: '开始使用',
                    onNext: _next,
                  ),
                  _ObStep(
                    logo: '✓',
                    title: '四条承诺',
                    promises: const [
                      '无广告、无开屏',
                      '数据只存在你的手机里',
                      '不申请与记账无关的权限',
                      '数据随时导出，永不锁定',
                    ],
                    onPrimary: '我了解了',
                    onNext: _next,
                  ),
                  _ObStep(
                    logo: '🔔',
                    title: '需要通知权限吗？',
                    subtitle: '当前版本不需要任何权限。\n未来的预算超支提醒（V1.1）会用到通知，\n到时再开启也完全来得及。',
                    onPrimary: '暂不开启，直接进入',
                    onNext: _next,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final on = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: on ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: on ? context.colors.primary : context.colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: Spacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ObStep extends StatelessWidget {
  const _ObStep({
    required this.logo,
    required this.title,
    required this.onPrimary,
    required this.onNext,
    this.subtitle,
    this.promises,
    this.brandMark = false,
  });

  final String logo;
  final String title;
  final String? subtitle;
  final List<String>? promises;
  final String onPrimary;
  final VoidCallback onNext;

  /// 首屏用手绘品牌标（透明底、跟主题色）。
  final bool brandMark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xxl, Spacing.xl, Spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 手绘小猪品牌标：颜色随主题，背景透明
          if (brandMark)
            const BrandMark(size: 120, showLabel: true)
          else
            Icon(Icons.savings_outlined, size: 80, color: context.colors.primary),
          const SizedBox(height: Spacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.colors.ink),
          ),
          const SizedBox(height: Spacing.md),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.colors.inkSecondary, height: 1.7),
            ),
          if (promises != null) ...[
            const SizedBox(height: Spacing.lg),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < promises!.length; i++)
                    Container(
                      decoration: BoxDecoration(
                        border: i == promises!.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: context.colors.divider)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 18, color: context.colors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(promises![i], style: TextStyle(fontSize: 13, color: context.colors.ink)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Spacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: onNext, child: Text(onPrimary)),
          ),
        ],
      ),
    );
  }
}
