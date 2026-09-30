/// Settings page. See PRD STORY-5.1, M9.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/features/security/app_lock_screen.dart';
import 'package:plain/features/settings/backup_page.dart';
import 'package:plain/features/settings/budget_page.dart';
import 'package:plain/features/settings/category_manage_page.dart';
import 'package:plain/features/settings/import_page.dart';
import 'package:plain/features/settings/recurring_page.dart';
import 'package:plain/features/settings/sync_page.dart';
import 'package:plain/features/settings/theme_page.dart';
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
    watchBrandTheme(ref);
    final prefs = ref.watch(themePrefsProvider);

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
                  title: const Text('备份'),
                  subtitle: const Text('导出数据到文件'),
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
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('恢复'),
                  subtitle: const Text('从文件导入数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
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
              ]),
            ),
            const SizedBox(height: Spacing.lg),

            _SectionHeader(title: '安全'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('应用锁'),
                subtitle: const Text('需要生物识别或 PIN 码'),
                value: appLockEnabled,
                onChanged: (v) {
                  ref.read(appLockEnabledProvider.notifier).toggle(v);
                  ref.read(appLockControllerProvider.notifier).lock();
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),

            _SectionHeader(title: '显示'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('月起始日'),
                  subtitle: const Text('每月从第几天开始计算'),
                  trailing: DropdownButton<int>(
                    value: 1,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1日')),
                      DropdownMenuItem(value: 5, child: Text('5日')),
                      DropdownMenuItem(value: 10, child: Text('10日')),
                      DropdownMenuItem(value: 15, child: Text('15日')),
                      DropdownMenuItem(value: 20, child: Text('20日')),
                      DropdownMenuItem(value: 25, child: Text('25日')),
                    ],
                    onChanged: (v) {},
                  ),
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
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: const Text('隐藏金额'),
                  subtitle: const Text('以 **** 显示金额'),
                  value: hideAmounts,
                  onChanged: (v) => ref.read(hideAmountsProvider.notifier).toggle(v),
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
                  trailing: Text('1.0.0', style: TextStyle(color: BrandColors.inkTertiary)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: BrandColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Icon(Icons.savings_outlined, size: 32, color: BrandColors.primary),
                ),
                const SizedBox(height: Spacing.md),
                Text('素记', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: BrandColors.ink)),
                const SizedBox(height: Spacing.xs),
                Text('本地优先的极简记账', style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary)),
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
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BrandColors.inkSecondary)),
    );
  }
}

