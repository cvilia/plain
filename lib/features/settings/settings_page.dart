/// 我的 — 设置中心。
///
/// 改版口径（2026-10-19）：原先 6 组 28 行一路铺到底，找「语言」要滚三屏。
/// 现在按「用得多不多」分三层：
///   ① 常用功能宫格：8 个直达入口（分类 / 预算 / 周期 / 目标 / 备份 / 导入 / 同步 / 回收站）
///   ② 会改行为的选择与开关，只留三组：记账、外观、安全
///   ③ 低频项全部收进「更多设置」二级页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/settings/locale_prefs.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/features/security/app_lock_prefs.dart';
import 'package:plain/features/security/app_lock_screen.dart';
import 'package:plain/features/settings/backup_page.dart';
import 'package:plain/features/settings/budget_page.dart';
import 'package:plain/features/settings/category_manage_page.dart';
import 'package:plain/features/settings/import_page.dart';
import 'package:plain/features/settings/more_settings_page.dart';
import 'package:plain/features/settings/recurring_page.dart';
import 'package:plain/features/settings/reimburse_center_page.dart';
import 'package:plain/features/settings/reminders_page.dart';
import 'package:plain/features/settings/savings_goals_page.dart';
import 'package:plain/features/settings/sync_page.dart';
import 'package:plain/features/settings/theme_page.dart';
import 'package:plain/features/settings/trash_page.dart';
import 'package:plain/features/settings/automation_rules_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 二级页一律从根 Navigator 推入：本页在 ShellRoute 的 branch 里，
  /// branch 自带的嵌套 Navigator 会把页面压在 body 内 —— 底部导航条还在。
  void _open(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final prefs = ref.watch(themePrefsProvider);
    final languagePrefs = ref.watch(languagePrefsProvider);
    final monthStartDay = ref.watch(monthStartDayProvider);
    final display = ref.watch(displayPrefsProvider);

    final features = <_Feature>[
      _Feature(PlainIconData.tag, s.categories, () => _open(context, const CategoryManagePage())),
      _Feature(PlainIconData.budget, s.entityBudget, () => _open(context, const BudgetPage())),
      _Feature(PlainIconData.recurring, s.actionLogEntityRecurring, () => _open(context, const RecurringPage())),
      _Feature(PlainIconData.goal, s.goalSystemTitle, () => _open(context, const SavingsGoalsPage())),
      _Feature(PlainIconData.storage, s.backupRestore, () => _open(context, const BackupPage())),
      _Feature(PlainIconData.import, s.bulkImport, () => _open(context, const ImportPage())),
      _Feature(PlainIconData.cloud, s.webdavSync, () => _open(context, const SyncPage())),
      _Feature(PlainIconData.delete, s.trashTitle, () => _open(context, const TrashPage())),
    ];

    return Scaffold(
      // Tab 页是导航终点：无返回箭头（标题居中走 PlainTopBar 默认行为）
      appBar: PlainTopBar(title: s.navMine),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const _PrivacyNote(),

            PlainEyebrow(s.commonFeatures,
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8)),
            _FeatureGrid(items: features),

            // ── 记账 ──
            PlainEyebrow(s.secLedger),
            PlainPanel(children: [
              PlainRow(
                title: s.monthStartDay,
                value: s.monthStartDayValue(monthStartDay),
                showChevron: true,
                onTap: () async {
                  final d = await showPlainPickerSheet<int>(
                    context: context,
                    title: s.monthStartDay,
                    selected: monthStartDay,
                    options: [
                      for (var i = 1; i <= 28; i++)
                        (i, s.recurringMonthlyOnDay(i)),
                    ],
                  );
                  if (d == null) return;
                  ref.read(ledgerSettingsProvider.notifier).setMonthStartDay(d);
                },
              ),
              PlainRow(
                title: s.remindersEntry,
                showChevron: true,
                onTap: () => _open(context, const RemindersPage()),
              ),
              PlainRow(
                title: s.reimburseCenter,
                showChevron: true,
                onTap: () => _open(context, const ReimburseCenterPage()),
              ),
              PlainRow(
                title: s.automationRules,
                showChevron: true,
                onTap: () => _open(context, const AutomationRulesPage()),
              ),
            ]),

            // ── 外观 ──
            PlainEyebrow(s.appearance),
            PlainPanel(children: [
              PlainRow(
                title: s.theme,
                // 主题与明暗模式合成一行，避免「主题」「外观模式」两行都跳同一页。
                value: '${themeSpecOf(prefs.themeId).name} · '
                    '${switch (prefs.themeMode) {
                  ThemeMode.system => s.themeSystem,
                  ThemeMode.light => s.themeLight,
                  ThemeMode.dark => s.themeDark,
                }}',
                showChevron: true,
                onTap: () => _open(context, const ThemePage()),
              ),
              PlainRow(
                title: s.languageLabel,
                value: switch (languagePrefs.language) {
                  AppLanguage.zh => s.languageChinese,
                  AppLanguage.en => s.languageEnglish,
                  AppLanguage.system => s.languageFollowSystem,
                },
                showChevron: true,
                onTap: () async {
                  final i = await showPlainPickerSheet<int>(
                    context: context,
                    title: s.languageLabel,
                    selected: languagePrefs.language.index,
                    options: [
                      (AppLanguage.system.index, s.languageFollowSystem),
                      (AppLanguage.zh.index, s.languageChinese),
                      (AppLanguage.en.index, s.languageEnglish),
                    ],
                  );
                  if (i == null) return;
                  ref
                      .read(languagePrefsProvider.notifier)
                      .set(AppLanguage.values[i]);
                },
              ),
              PlainRow(
                title: s.fontSize,
                value: [
                  s.fontScaleSmall,
                  s.fontScaleStandard,
                  s.fontScaleLarge,
                ][display.fontScaleIndex],
                showChevron: true,
                onTap: () async {
                  final i = await showPlainPickerSheet<int>(
                    context: context,
                    title: s.fontSize,
                    selected: display.fontScaleIndex,
                    options: [
                      for (var j = 0; j < 3; j++)
                        (
                          j,
                          [s.fontScaleSmall, s.fontScaleStandard, s.fontScaleLarge][j]
                        ),
                    ],
                  );
                  if (i == null) return;
                  ref.read(displayPrefsProvider.notifier).setFontScaleIndex(i);
                },
              ),
            ]),

            // ── 安全 ──
            PlainEyebrow(s.security),
            PlainPanel(children: [
              PlainRow(
                title: s.appLock,
                trailing: PlainSwitch(
                  value: appLockEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await showAppLockSetupDialog(context);
                      if (!ok || !context.mounted) return;
                      ref.read(appLockEnabledProvider.notifier).set(true);
                      ref.read(appLockControllerProvider.notifier).lock();
                    } else {
                      await AppLockPrefs.disable();
                      if (!context.mounted) return;
                      ref.read(appLockEnabledProvider.notifier).set(false);
                      ref.read(appLockControllerProvider.notifier).unlock();
                    }
                  },
                ),
              ),
              PlainRow(
                title: s.hideAmounts,
                trailing: PlainSwitch(
                  value: hideAmounts,
                  onChanged: (v) =>
                      ref.read(hideAmountsProvider.notifier).toggle(v),
                ),
              ),
            ]),

            const SizedBox(height: Spacing.md),
            PlainPanel(children: [
              PlainRow(
                title: s.moreSettings,
                subtitle: s.moreSettingsSubtitle,
                showChevron: true,
                onTap: () => _open(context, const MoreSettingsPage()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 顶部隐私条：压成一行，不再占两行高度。
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.income.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            PlainIcon(PlainIconData.shield, color: colors.income, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${s.privacyPledge} · ${s.privacyPledgeDesc}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.income,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.label, this.onTap);
  final PlainIconData icon;
  final String label;
  final VoidCallback onTap;
}

/// 常用功能宫格：4 列，两行放满 8 个入口。
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});
  final List<_Feature> items;

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += _columns) {
      final slice = items.skip(start).take(_columns).toList();
      rows.add(
        Row(
          children: [
            for (final f in slice)
              Expanded(child: _FeatureTile(feature: f)),
            // 最后一行不满 4 个时补空位，保证列宽一致
            for (var i = slice.length; i < _columns; i++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: feature.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlainIcon(feature.icon, size: 22, color: colors.inkSecondary),
            const SizedBox(height: 6),
            Text(
              feature.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
