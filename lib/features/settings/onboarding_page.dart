/// Onboarding page (first launch). See PRD STORY-5.1, 06-B3.
/// Shows brand promise and basic setup.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.savings_outlined,
                    title: '欢迎使用素记',
                    subtitle: '本地优先的极简记账',
                    description: '无广告 · 无开屏 · 数据只在你的手机里',
                  ),
                  _OnboardingPage(
                    icon: Icons.touch_app_outlined,
                    title: '3 秒记一笔',
                    subtitle: '点分类即保存',
                    description: '输入金额，点击分类，账单立即落库。\n没有多余的按钮和步骤。',
                  ),
                  _OnboardingPage(
                    icon: Icons.lock_outline,
                    title: '数据安全',
                    subtitle: '本地加密存储',
                    description: '数据全部加密存储在本地，可随时导出备份。\n不申请与记账无关的权限。',
                  ),
                ],
              ),
            ),
            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? BrandColors.primary : BrandColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: Spacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_currentPage < 2) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(_currentPage < 2 ? '下一步' : '开始使用'),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: BrandColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Icon(icon, size: 50, color: BrandColors.primary),
          ),
          const SizedBox(height: Spacing.xxl),
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: BrandColors.ink)),
          const SizedBox(height: Spacing.sm),
          Text(subtitle, style: TextStyle(fontSize: 16, color: BrandColors.primary)),
          const SizedBox(height: Spacing.xl),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: BrandColors.inkSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
