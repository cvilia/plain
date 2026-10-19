/// Settings / 我的 — Quiet Ledger.
/// Layout: privacy-strip + grp(eyebrow + panel rows). See 单独确认.html SP-5-03.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/services/emotion_feedback_service.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:plain/features/security/app_lock_prefs.dart';
import 'package:plain/features/security/app_lock_screen.dart';
import 'package:plain/features/settings/achievements_page.dart';
import 'package:plain/features/settings/action_log_page.dart';
import 'package:plain/features/settings/automation_rules_page.dart';
import 'package:plain/features/settings/backup_page.dart';
import 'package:plain/features/settings/budget_page.dart';
import 'package:plain/features/settings/category_manage_page.dart';
import 'package:plain/features/settings/currency_rate_page.dart';
import 'package:plain/features/family/family_page.dart';
import 'package:plain/features/settings/home_layout_page.dart';
import 'package:plain/features/settings/import_page.dart';
import 'package:plain/features/settings/privacy_policy_page.dart';
import 'package:plain/features/settings/recurring_page.dart';
import 'package:plain/features/settings/reimburse_center_page.dart';
import 'package:plain/features/settings/reminders_page.dart';
import 'package:plain/features/settings/savings_goals_page.dart';
import 'package:plain/features/settings/sync_page.dart';
import 'package:plain/features/settings/theme_page.dart';
import 'package:plain/features/settings/trash_page.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/l10n/strings_ledger.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
    final monthStartDay = ref.watch(monthStartDayProvider);
    final display = ref.watch(displayPrefsProvider);
    final colors = context.colors;

    return Scaffold(
      // Tab 页是导航终点：无返回箭头（标题居中走 PlainTopBar 默认行为）
      appBar: PlainTopBar(title: s.navMine),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // privacy-strip
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.income.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    PlainIcon(PlainIconData.shield, color: colors.income, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.privacyPledge,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.income,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.privacyPledgeDesc,
                            style: TextStyle(fontSize: 14, color: colors.income),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 记账
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
                      for (var i = 1; i <= 28; i++) (i, s.recurringMonthlyOnDay(i)),
                    ],
                  );
                  if (d == null) return;
                  ref.read(ledgerSettingsProvider.notifier).setMonthStartDay(d);
                },
              ),
              PlainRow(
                title: s.fontSize,
                value: [s.fontScaleSmall, s.fontScaleStandard, s.fontScaleLarge][display.fontScaleIndex],
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
                          [
                            s.fontScaleSmall,
                            s.fontScaleStandard,
                            s.fontScaleLarge
                          ][j]
                        ),
                    ],
                  );
                  if (i == null) return;
                  ref.read(displayPrefsProvider.notifier).setFontScaleIndex(i);
                },
              ),
              PlainRow(
                title: s.soundOnSave,
                trailing: PlainSwitch(
                  value: display.soundEnabled,
                  onChanged: (v) =>
                      ref.read(displayPrefsProvider.notifier).setSoundEnabled(v),
                ),
              ),
              PlainRow(
                title: s.stayAfterSave,
                trailing: PlainSwitch(
                  value: display.stayAfterSave,
                  onChanged: (v) => ref
                      .read(displayPrefsProvider.notifier)
                      .setStayAfterSave(v),
                ),
              ),
              // STORY-9.3：外币账户记账用的锁定汇率
              PlainRow(
                title: s.currencyRateTitle,
                showChevron: true,
                onTap: () => _open(context, const CurrencyRatePage()),
              ),
            ]),

            // 安全
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

            // 外观
            PlainEyebrow(s.appearance),
            PlainPanel(children: [
              PlainRow(
                title: s.theme,
                value: prefs.themeId.name,
                showChevron: true,
                onTap: () => _open(context, const ThemePage()),
              ),
              PlainRow(
                title: s.appearanceMode,
                value: s.themeSystem,
                showChevron: true,
                onTap: () => _open(context, const ThemePage()),
              ),
              PlainRow(
                title: s.homeCards,
                value: '',
                showChevron: true,
                onTap: () => _open(context, const HomeLayoutPage()),
              ),
            ]),

            // 数据
            PlainEyebrow(s.data),
            PlainPanel(children: [
              PlainRow(
                title: s.categories,
                showChevron: true,
                onTap: () => _open(context, const CategoryManagePage()),
              ),
              PlainRow(
                title: s.entityBudget,
                showChevron: true,
                onTap: () => _open(context, const BudgetPage()),
              ),
              PlainRow(
                title: s.actionLogEntityRecurring,
                showChevron: true,
                onTap: () => _open(context, const RecurringPage()),
              ),
              PlainRow(
                title: s.backupRestore,
                showChevron: true,
                onTap: () => _open(context, const BackupPage()),
              ),
              PlainRow(
                title: s.bulkImport,
                showChevron: true,
                onTap: () => _open(context, const ImportPage()),
              ),
              PlainRow(
                // STORY-7.2：目标体系 = 储蓄 / 还债 / 限额（限额复用分类预算）
                title: s.goalSystemTitle,
                showChevron: true,
                onTap: () => _open(context, const SavingsGoalsPage()),
              ),
              PlainRow(
                title: s.reimburseCenter,
                showChevron: true,
                onTap: () => _open(context, const ReimburseCenterPage()),
              ),
              PlainRow(
                title: s.remindersEntry,
                showChevron: true,
                onTap: () => _open(context, const RemindersPage()),
              ),
              PlainRow(
                title: s.automationRules,
                showChevron: true,
                onTap: () => _open(context, const AutomationRulesPage()),
              ),
              PlainRow(
                title: s.webdavSync,
                showChevron: true,
                onTap: () => _open(context, const SyncPage()),
              ),
              PlainRow(
                // STORY-8.2：成员管理在本机可用；跨设备加入等云同步
                title: s.familyTitle,
                showChevron: true,
                onTap: () => _open(context, const FamilyPage()),
              ),
              PlainRow(
                title: s.trashTitle,
                showChevron: true,
                onTap: () => _open(context, const TrashPage()),
              ),
              PlainRow(
                title: s.actionLogTitle,
                showChevron: true,
                onTap: () => _open(context, const ActionLogPage()),
              ),
              PlainRow(
                title: s.myAchievements,
                showChevron: true,
                onTap: () => _open(context, const AchievementsPage()),
              ),
            ]),

            // 其它
            PlainEyebrow(s.otherSection),
            PlainPanel(children: [
              PlainRow(
                title: s.emotionFeedback,
                trailing: PlainSwitch(
                  value: ref.watch(emotionEnabledProvider),
                  onChanged: (v) =>
                      ref.read(emotionEnabledProvider.notifier).toggle(v),
                ),
              ),
              PlainRow(
                title: s.weeklyReport,
                trailing: PlainSwitch(
                  value: ref.watch(weeklyReportEnabledProvider),
                  onChanged: (v) =>
                      ref.read(weeklyReportEnabledProvider.notifier).toggle(v),
                ),
              ),
            ]),

            // 关于
            PlainEyebrow(s.about),
            PlainPanel(children: [
              PlainRow(
                title: s.privacyPledge,
                showChevron: true,
                onTap: () => _open(context, const PrivacyPolicyPage()),
              ),
              PlainRow(title: s.version, value: 'V1.0.0'),
              PlainRow(
                title: s.openSource,
                showChevron: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: s.appTitle,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
