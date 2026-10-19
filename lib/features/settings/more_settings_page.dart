/// 更多设置 —— 收纳「我的」首页不再直接展示的低频项。
///
/// 拆出来的目的只有一个：主页面不靠滚动找东西。这里的每一项在主页面都
/// 找不到第二个入口，所以不存在「两处都能改」的一致性问题。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/services/emotion_feedback_service.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:plain/features/family/family_page.dart';
import 'package:plain/features/settings/achievements_page.dart';
import 'package:plain/features/settings/action_log_page.dart';
import 'package:plain/features/settings/currency_rate_page.dart';
import 'package:plain/features/settings/debug_log_page.dart';
import 'package:plain/features/settings/home_layout_page.dart';
import 'package:plain/features/settings/privacy_policy_page.dart';

class MoreSettingsPage extends ConsumerWidget {
  const MoreSettingsPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final display = ref.watch(displayPrefsProvider);

    return Scaffold(
      appBar: PlainTopBar(title: s.moreSettings, showBack: true),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, Spacing.xl),
          children: [
            PlainEyebrow(s.entryPrefs),
            PlainPanel(children: [
              PlainRow(
                title: s.homeCards,
                showChevron: true,
                onTap: () => _open(context, const HomeLayoutPage()),
              ),
              PlainRow(
                title: s.currencyRateTitle,
                showChevron: true,
                onTap: () => _open(context, const CurrencyRatePage()),
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
            ]),

            PlainEyebrow(s.recordsAndFamily),
            PlainPanel(children: [
              PlainRow(
                title: s.familyMembers,
                showChevron: true,
                onTap: () => _open(context, const FamilyPage()),
              ),
              PlainRow(
                title: s.myAchievements,
                showChevron: true,
                onTap: () => _open(context, const AchievementsPage()),
              ),
              PlainRow(
                title: s.actionLog,
                showChevron: true,
                onTap: () => _open(context, const ActionLogPage()),
              ),
            ]),

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

            PlainEyebrow(s.about),
            PlainPanel(children: [
              PlainRow(
                title: s.privacyPledge,
                showChevron: true,
                onTap: () => _open(context, const PrivacyPolicyPage()),
              ),
              // 诊断日志：读进程内环形缓冲。放在「关于」是因为它跟版本号一样
              // 属于「出问题时才来看」的信息，不占主流程入口。
              PlainRow(
                title: s.debugLog,
                showChevron: true,
                onTap: () => _open(context, const DebugLogPage()),
              ),
              // 版本号从构建元数据（pubspec `version: 2.0.0+5`）实时读取，
              // 不再硬编码 —— 以前写死 'V1.0.0'，升版后页面不跟着变。
              PlainRow(
                title: s.version,
                trailing: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final info = snap.data;
                    return Text(
                      info == null
                          ? '…'
                          : 'V${info.version} (${info.buildNumber})',
                      style: TextStyle(
                          fontSize: 15, color: context.colors.inkTertiary),
                    );
                  },
                ),
              ),
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
