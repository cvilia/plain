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

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final prefs = ref.watch(themePrefsProvider);
    final monthStartDay = ref.watch(monthStartDayProvider);
    final display = ref.watch(displayPrefsProvider);
    final colors = context.colors;

    return Scaffold(
      // Tab 页是导航终点：无返回箭头（标题居中走 PlainTopBar 默认行为）
      appBar: const PlainTopBar(title: '我的'),
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
                            '隐私承诺',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.income,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '无广告、无外联、无埋点上报',
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
            PlainEyebrow('记账'),
            PlainPanel(children: [
              PlainRow(
                title: '月起始日',
                value: '$monthStartDay 日',
                showChevron: true,
                onTap: () async {
                  final d = await showPlainPickerSheet<int>(
                    context: context,
                    title: '月起始日',
                    selected: monthStartDay,
                    options: [
                      for (var i = 1; i <= 28; i++) (i, '每月 $i 日'),
                    ],
                  );
                  if (d == null) return;
                  ref.read(ledgerSettingsProvider.notifier).setMonthStartDay(d);
                },
              ),
              PlainRow(
                title: '字体大小',
                value: kFontScaleLabels[display.fontScaleIndex],
                showChevron: true,
                onTap: () async {
                  final i = await showPlainPickerSheet<int>(
                    context: context,
                    title: '字体大小',
                    selected: display.fontScaleIndex,
                    options: [
                      for (var j = 0; j < kFontScaleLabels.length; j++)
                        (j, kFontScaleLabels[j]),
                    ],
                  );
                  if (i == null) return;
                  ref.read(displayPrefsProvider.notifier).setFontScaleIndex(i);
                },
              ),
              PlainRow(
                title: '记账确认音效',
                trailing: PlainSwitch(
                  value: display.soundEnabled,
                  onChanged: (v) =>
                      ref.read(displayPrefsProvider.notifier).setSoundEnabled(v),
                ),
              ),
              PlainRow(
                title: '保存后停留在记账页',
                trailing: PlainSwitch(
                  value: display.stayAfterSave,
                  onChanged: (v) => ref
                      .read(displayPrefsProvider.notifier)
                      .setStayAfterSave(v),
                ),
              ),
              // STORY-9.3：外币账户记账用的锁定汇率
              PlainRow(
                title: '汇率锁定',
                showChevron: true,
                onTap: () => _open(context, const CurrencyRatePage()),
              ),
            ]),

            // 安全
            PlainEyebrow('安全'),
            PlainPanel(children: [
              PlainRow(
                title: '应用锁',
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
                title: '隐藏金额',
                trailing: PlainSwitch(
                  value: hideAmounts,
                  onChanged: (v) =>
                      ref.read(hideAmountsProvider.notifier).toggle(v),
                ),
              ),
            ]),

            // 外观
            PlainEyebrow('外观'),
            PlainPanel(children: [
              PlainRow(
                title: '主题',
                value: prefs.themeId.name,
                showChevron: true,
                onTap: () => _open(context, const ThemePage()),
              ),
              PlainRow(
                title: '外观模式',
                value: '跟随系统',
                showChevron: true,
                onTap: () => _open(context, const ThemePage()),
              ),
              PlainRow(
                title: '首页卡片',
                value: '',
                showChevron: true,
                onTap: () => _open(context, const HomeLayoutPage()),
              ),
            ]),

            // 数据
            PlainEyebrow('数据'),
            PlainPanel(children: [
              PlainRow(
                title: '分类管理',
                showChevron: true,
                onTap: () => _open(context, const CategoryManagePage()),
              ),
              PlainRow(
                title: '预算',
                showChevron: true,
                onTap: () => _open(context, const BudgetPage()),
              ),
              PlainRow(
                title: '周期记账',
                showChevron: true,
                onTap: () => _open(context, const RecurringPage()),
              ),
              PlainRow(
                title: '备份与恢复',
                showChevron: true,
                onTap: () => _open(context, const BackupPage()),
              ),
              PlainRow(
                title: '批量导入',
                showChevron: true,
                onTap: () => _open(context, const ImportPage()),
              ),
              PlainRow(
                // STORY-7.2：目标体系 = 储蓄 / 还债 / 限额（限额复用分类预算）
                title: '目标体系',
                showChevron: true,
                onTap: () => _open(context, const SavingsGoalsPage()),
              ),
              PlainRow(
                title: '报销中心',
                showChevron: true,
                onTap: () => _open(context, const ReimburseCenterPage()),
              ),
              PlainRow(
                title: '提醒',
                showChevron: true,
                onTap: () => _open(context, const RemindersPage()),
              ),
              PlainRow(
                title: '自动化规则',
                showChevron: true,
                onTap: () => _open(context, const AutomationRulesPage()),
              ),
              PlainRow(
                title: 'WebDAV 同步',
                showChevron: true,
                onTap: () => _open(context, const SyncPage()),
              ),
              PlainRow(
                // STORY-8.2：成员管理在本机可用；跨设备加入等云同步
                title: '家庭与成员',
                showChevron: true,
                onTap: () => _open(context, const FamilyPage()),
              ),
              PlainRow(
                title: '回收站',
                showChevron: true,
                onTap: () => _open(context, const TrashPage()),
              ),
              PlainRow(
                title: '操作日志',
                showChevron: true,
                onTap: () => _open(context, const ActionLogPage()),
              ),
              PlainRow(
                title: '我的成就',
                showChevron: true,
                onTap: () => _open(context, const AchievementsPage()),
              ),
            ]),

            // 其它
            PlainEyebrow('其它'),
            PlainPanel(children: [
              PlainRow(
                title: '情绪反馈',
                trailing: PlainSwitch(
                  value: ref.watch(emotionEnabledProvider),
                  onChanged: (v) =>
                      ref.read(emotionEnabledProvider.notifier).toggle(v),
                ),
              ),
              PlainRow(
                title: '消费周报',
                trailing: PlainSwitch(
                  value: ref.watch(weeklyReportEnabledProvider),
                  onChanged: (v) =>
                      ref.read(weeklyReportEnabledProvider.notifier).toggle(v),
                ),
              ),
            ]),

            // 关于
            PlainEyebrow('关于'),
            PlainPanel(children: [
              PlainRow(
                title: '隐私承诺',
                showChevron: true,
                onTap: () => _open(context, const PrivacyPolicyPage()),
              ),
              const PlainRow(title: '版本', value: 'V1.0.0'),
              PlainRow(
                title: '开源许可',
                showChevron: true,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '素记',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
