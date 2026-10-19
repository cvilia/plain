/// Core / data-layer i18n keys.
///
/// Key 归属：`core/`、`data/`、`app/settings/`、`design_system/category_icon_picker`。
/// 只放这些层新增的文案；通用文案（保存 / 取消 …）一律复用 [AppStrings]。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/settings/locale_prefs.dart';

/// 无 `BuildContext` 的调用方（后台同步等）使用的兜底文案包。
///
/// 与 [AppStrings.of] 的 fallback 一致（zh-CN）；仅用于 services 这类拿不到 context
/// 的场景，UI 层应始终传 `AppStrings.of(context)`。
const AppStrings kDefaultAppStrings = AppStrings(Locale('zh', 'CN'));

/// 全局文案包：给拿不到 `BuildContext` 的 Notifier / 后台任务取文案用。
///
/// 跟随用户在设置里选的语言；`system`（拿不到系统 locale）回落 zh-CN。
final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(languagePrefsProvider).locale;
  return locale == null ? kDefaultAppStrings : AppStrings(locale);
});

extension CoreStrings on AppStrings {
  // ── Date (core/time/date_format.dart) ──

  /// 群组头日期：`9月28日 周日`（不补零、不带年）。今天/昨天走 [today] / [yesterday]。
  String shortMonthDayWeekday(DateTime d, String weekday) =>
      isZh ? '${d.month}月${d.day}日 $weekday' : '$weekday, ${d.month}/${d.day}';

  // ── Backup (core/backup/backup_container.dart) ──

  String get backupSourceMissing => isZh ? '备份源文件不存在' : 'Backup source file not found';

  // ── Cross analysis amount buckets (core/constants/app_constants.dart) ──

  String get crossAmountUnderLabel => isZh ? '100 元以下' : 'Under ¥100';
  String get crossAmountOverLabel => isZh ? '5000 元及以上' : '¥5000 and above';

  // ── Display prefs (app/settings/display_prefs.dart) ──

  String get fontScaleSmall => isZh ? '小' : 'Small';
  String get fontScaleStandard => isZh ? '标准' : 'Standard';
  String get fontScaleLarge => isZh ? '大' : 'Large';

  // ── Language prefs (app/settings/locale_prefs.dart) ──

  String get languageLabel => isZh ? '语言' : 'Language';
  String get languageFollowSystem => isZh ? '跟随系统' : 'Follow system';
  String get languageChinese => '简体中文';
  String get languageEnglish => 'English';

  // ── Home layout cards (app/settings/home_layout_prefs.dart) ──

  String get homeCardSafeToSpend => isZh ? '安全可花' : 'Safe to Spend';
  String get homeCardMonthlyBalance => isZh ? '本月收支' : 'This Month';
  String get homeCardBudgetProgress => isZh ? '预算进度' : 'Budget Progress';
  String get homeCardNetAssets => isZh ? '资产净值' : 'Net Assets';
  String get homeCardPendingReimburse => isZh ? '待报销' : 'Pending Reimbursement';
  String get homeCardSavingsGoals => isZh ? '储蓄目标' : 'Savings Goals';
  String get homeCardRecentEntries => isZh ? '最近账单' : 'Recent Entries';

  // ── Category icon picker (design_system/category_icon_picker.dart) ──

  // 原「上传/更换自定义图标」两枚文案随自定义图标功能下线一并移除
  // （2026-10-19）：图标库已扩到 100 枚内置分类图标，不再需要本地上传。

  // ── Sync messages (data/sync/webdav_sync_service.dart) ──

  String get remoteDirCreateFailed => isZh ? '无法创建远程目录' : 'Cannot create remote folder';
  String get backupFileGenFailed => isZh ? '备份文件生成失败' : 'Failed to create backup file';
  String get uploadFailed => isZh ? '上传失败' : 'Upload failed';
  String get uploadSuccess => isZh ? '上传成功' : 'Upload succeeded';
  String get downloadSuccessRestart => isZh ? '下载成功，请重启应用' : 'Downloaded — please restart the app';
  String get remoteNoBackup => isZh ? '远程无备份文件或下载失败' : 'No backup on remote, or download failed';
  String get remoteInvalidDb => isZh ? '远程文件不是有效的数据库' : 'Remote file is not a valid database';
  String uploadException(Object e) => isZh ? '上传异常: $e' : 'Upload error: $e';
  String downloadException(Object e) => isZh ? '下载异常: $e' : 'Download error: $e';

  // ── Sync messages (data/sync/incremental_sync_service.dart) ──

  String pushException(Object e) => isZh ? '推送异常: $e' : 'Push error: $e';
  String pullException(Object e) => isZh ? '拉取异常: $e' : 'Pull error: $e';

  // ── design_system/category_create_sheet.dart ──

  String get createCategoryAction => isZh ? '创建' : 'Create';
}
