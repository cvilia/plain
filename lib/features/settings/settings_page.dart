/// Settings page. See PRD STORY-5.1, M9.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/brand_mark.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/features/security/app_lock_prefs.dart';
import 'package:plain/features/security/app_lock_screen.dart';
import 'package:plain/features/settings/action_log_page.dart';
import 'package:plain/features/settings/automation_rules_page.dart';
import 'package:plain/features/settings/backup_page.dart';
import 'package:plain/features/settings/budget_page.dart';
import 'package:plain/features/settings/category_manage_page.dart';
import 'package:plain/features/settings/import_page.dart';
import 'package:plain/features/settings/reimburse_center_page.dart';
import 'package:plain/features/settings/privacy_policy_page.dart';
import 'package:plain/features/settings/recurring_page.dart';
import 'package:plain/features/settings/reminders_page.dart';
import 'package:plain/features/settings/savings_goals_page.dart';
import 'package:plain/features/settings/sync_page.dart';
import 'package:plain/features/settings/theme_page.dart';
import 'package:plain/features/settings/home_layout_page.dart';
import 'package:plain/features/settings/achievements_page.dart';
import 'package:plain/domain/services/emotion_feedback_service.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:plain/features/settings/trash_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Push on the root navigator so the page covers the shell FAB / bottom nav.
  void _openDetail(BuildContext context, Widget page) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            _SectionHeader(title: '数据'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('分类管理'),
                  subtitle: const Text('管理支出与收入分类'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const CategoryManagePage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('预算'),
                  subtitle: const Text('总预算与分类预算'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const BudgetPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: const Text('周期记账'),
                  subtitle: const Text('房租、订阅等自动入账'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const RecurringPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('备份与恢复'),
                  subtitle: const Text('导出加密备份 / 从备份恢复'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const BackupPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('数据导入'),
                  subtitle: const Text('从竞品 App 导入 CSV 数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const ImportPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('储蓄目标'),
                  subtitle: const Text('沉淀基金与专项预留'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const SavingsGoalsPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('报销中心'),
                  subtitle: const Text('垫付归集与回款追踪'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const ReimburseCenterPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('提醒'),
                  subtitle: const Text('预算、周期等待办提醒'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const RemindersPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('自动化规则'),
                  subtitle: const Text('按规则自动分类等'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const AutomationRulesPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('WebDAV 同步'),
                  subtitle: const Text('备份到自建云，多设备同步'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const SyncPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('回收站'),
                  subtitle: const Text('查看和恢复已删除的账单'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const TrashPage()),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('操作日志'),
                  subtitle: const Text('查看最近的记账与设置变更'),
                  onTap: () => _openDetail(context, const ActionLogPage()),
                ),
              ]),
            ),
            const SizedBox(height: Spacing.lg),

            _SectionHeader(title: '安全'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('应用锁'),
                  subtitle: const Text('需要生物识别或 PIN 码'),
                  value: appLockEnabled,
                  onChanged: (v) async {
                    if (v) {
                      // Must set PIN first — never lock without credentials.
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
                if (appLockEnabled)
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('重置应用锁'),
                    subtitle: const Text('清除 PIN 与生物识别；记账数据不受影响'),
                    onTap: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: '重置应用锁',
                        message: '将清除 PIN 与生物识别绑定，记账数据保持加密、不会被删除。',
                        confirmLabel: '重置',
                        destructive: true,
                      );
                      if (ok != true || !context.mounted) return;
                      await AppLockPrefs.disable();
                      if (!context.mounted) return;
                      ref.read(appLockEnabledProvider.notifier).set(false);
                      ref.read(appLockControllerProvider.notifier).unlock();
                      showAppToast(context, '应用锁已重置');
                    },
                  ),
              ]),
            ),
            const SizedBox(height: Spacing.lg),

            _SectionHeader(title: '显示'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('月起始日'),
                  subtitle: Text(monthStartDay == 1 ? '自然月（每月 1 日起）' : '每月从 $monthStartDay 日开始计算'),
                  trailing: DropdownButton<int>(
                    value: monthStartDay,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('$d 日')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(ledgerSettingsProvider.notifier).setMonthStartDay(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('字体大小'),
                  trailing: DropdownButton<int>(
                    value: display.fontScaleIndex,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var i = 0; i < kFontScaleLabels.length; i++)
                        DropdownMenuItem(value: i, child: Text(kFontScaleLabels[i])),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(displayPrefsProvider.notifier).setFontScaleIndex(v);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('记账确认音效'),
                  subtitle: const Text('保存时播放提示音'),
                  value: display.soundEnabled,
                  onChanged: (v) => ref.read(displayPrefsProvider.notifier).setSoundEnabled(v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.pause_circle_outline),
                  title: const Text('保存后停留'),
                  subtitle: const Text('关闭后保存即退出输入页'),
                  value: display.stayAfterSave,
                  onChanged: (v) => ref.read(displayPrefsProvider.notifier).setStayAfterSave(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('主题'),
                  subtitle: Text(prefs.themeId.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const ThemePage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('首页卡片'),
                  subtitle: const Text('排序、显示/隐藏、预设布局'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const HomeLayoutPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text('我的成就'),
                  subtitle: const Text('连续记账、徽章、权益券'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const AchievementsPage()),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: const Text('隐藏金额'),
                  subtitle: const Text('以 **** 显示金额'),
                  value: hideAmounts,
                  onChanged: (v) => ref.read(hideAmountsProvider.notifier).toggle(v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.sentiment_satisfied_alt_outlined),
                  title: const Text('情绪反馈'),
                  subtitle: const Text('记账后显示轻量反馈卡片'),
                  value: ref.watch(emotionEnabledProvider),
                  onChanged: (v) => ref.read(emotionEnabledProvider.notifier).toggle(v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.bar_chart_outlined),
                  title: const Text('消费周报'),
                  subtitle: const Text('每周日推送消费画像'),
                  value: ref.watch(weeklyReportEnabledProvider),
                  onChanged: (v) => ref.read(weeklyReportEnabledProvider.notifier).toggle(v),
                ),
              ]),
            ),
            const SizedBox(height: Spacing.lg),

            _SectionHeader(title: '关于'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本'),
                  trailing: Text('1.0.2', style: TextStyle(color: context.colors.inkTertiary)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(context, const PrivacyPolicyPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_outlined),
                  title: const Text('开源许可'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(context: context, applicationName: '素记'),
                ),
              ]),
            ),
            const SizedBox(height: Spacing.xxl),

            Center(
              child: Column(children: [
                // 与启动/引导页同一品牌标（savings_outlined 小猪）
                const BrandMark(size: 64, showLabel: false),
                const SizedBox(height: Spacing.md),
                Text('素记', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.ink)),
                const SizedBox(height: Spacing.xs),
                Text('本地优先的极简记账', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.lg, Spacing.sm),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.inkSecondary)),
    );
  }
}

