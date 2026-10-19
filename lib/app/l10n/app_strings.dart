/// Localization delegates and strings. See 06-C1, 04-9.
///
/// 2026-10-19 起双语（zh-CN / en）：英文分支早随 `isZh ? :` 写在各 strings
/// 文件里；`supportedLocales` 放开 en，用户可在设置-外观里切换或跟随系统。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App localization strings.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? AppStrings(const Locale('zh', 'CN'));
  }

  static AppStrings? maybeOf(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en'),
  ];

  bool get isZh => locale.languageCode == 'zh';

  // ── Common ──
  String get appTitle => isZh ? '素记' : 'SuJi';
  String get save => isZh ? '保存' : 'Save';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get delete => isZh ? '删除' : 'Delete';
  String get edit => isZh ? '编辑' : 'Edit';
  String get ok => isZh ? '确定' : 'OK';
  String get confirm => isZh ? '确认' : 'Confirm';
  String get done => isZh ? '完成' : 'Done';
  String get close => isZh ? '关闭' : 'Close';
  String get retry => isZh ? '重试' : 'Retry';
  String get today => isZh ? '今天' : 'Today';
  String get yesterday => isZh ? '昨天' : 'Yesterday';
  String get error => isZh ? '出错了' : 'Something went wrong';
  String get loadingError => isZh ? '加载失败' : 'Loading failed';
  String get loadingErrorSubtitle => isZh ? '数据还在本机，重试一下就好。' : 'Data is still on this device. Please retry.';
  String get pleaseSelect => isZh ? '请选择' : 'Please select';
  String get noOptionsAvailable => isZh ? '暂无可选项' : 'No options available';

  // ── Entry ──
  String get recordEntry => isZh ? '记一笔' : 'Record';
  String get editEntry => isZh ? '编辑账单' : 'Edit Entry';
  String get expense => isZh ? '支出' : 'Expense';
  String get income => isZh ? '收入' : 'Income';
  String get transfer => isZh ? '转账' : 'Transfer';
  String get note => isZh ? '备注' : 'Note';
  String get noteHint => isZh ? '写点什么...' : 'Write something...';
  String get date => isZh ? '日期' : 'Date';
  String get account => isZh ? '账户' : 'Account';
  String get defaultAccount => isZh ? '默认账户' : 'Default';
  String get category => isZh ? '分类' : 'Category';
  String get more => isZh ? '更多' : 'More';
  String get saved => isZh ? '已记' : 'Saved';
  String get amountOverLimit => isZh ? '金额超出上限' : 'Amount over limit';
  String get enterAmount => isZh ? '请输入金额' : 'Enter amount';
  String get selectCategory => isZh ? '请选择分类' : 'Select category';
  String get incompleteExpr => isZh ? '表达式未闭合' : 'Incomplete expression';

  // ── Flow list ──
  String get flow => isZh ? '流水' : 'Flow';
  String get noEntries => isZh ? '还没有记录' : 'No entries yet';
  String get tapToRecord => isZh ? '点击下方按钮记一笔' : 'Tap the button to record one';
  String get deleted => isZh ? '已删除' : 'Deleted';
  String get undo => isZh ? '撤销' : 'Undo';
  String get uncategorized => isZh ? '未分类' : 'Uncategorized';

  // ── Detail ──
  String get detail => isZh ? '详情' : 'Detail';
  String get deleteEntry => isZh ? '删除账单' : 'Delete Entry';
  String get deleteConfirm => isZh
      ? '删除后可在回收站恢复（保留 30 天）。确定删除？'
      : 'Moved to Trash — restorable for 30 days. Delete?';
  String get entryNotFound => isZh ? '账单不存在' : 'Entry not found';
  String get source => isZh ? '来源' : 'Source';
  String get created => isZh ? '创建时间' : 'Created';
  String get updated => isZh ? '更新时间' : 'Updated';

  // ── Reports ──
  String get reports => isZh ? '报表' : 'Reports';
  String get noRecords => isZh ? '本月还没有记录' : 'No records this month';
  String get expenseByCategory => isZh ? '分类支出占比' : 'Expense by Category';
  String get vsLastMonth => isZh ? '与上月对比' : 'vs Last Month';
  String get balance => isZh ? '结余' : 'Balance';
  String get collapse => isZh ? '收起' : 'Collapse';
  String expandRemaining(int count) => isZh ? '展开其余 $count 类' : 'Expand remaining $count';

  // ── Accounts ──
  String get accounts => isZh ? '资产' : 'Assets';
  String get netAssets => isZh ? '净资产' : 'Net Assets';
  String get noAccounts => isZh ? '还没有账户' : 'No accounts yet';
  String get addCashOrCard => isZh ? '添加现金或银行卡' : 'Add cash or bank card';
  String get addAccount => isZh ? '添加账户' : 'Add Account';
  String get accountName => isZh ? '账户名称' : 'Account Name';
  String get openingBalance => isZh ? '期初余额' : 'Opening Balance';
  String get cash => isZh ? '现金' : 'Cash';
  String get debitCard => isZh ? '储蓄卡' : 'Debit Card';
  String get reconcile => isZh ? '对账' : 'Reconcile';
  String get actualBalance => isZh ? '实际余额' : 'Actual balance';
  String get currentBalance => isZh ? '当前余额' : 'Current balance';

  // ── Categories ──
  String get categories => isZh ? '分类管理' : 'Categories';
  String get addCategory => isZh ? '添加分类' : 'Add Category';
  String get renameCategory => isZh ? '重命名分类' : 'Rename Category';
  String get editCategoryInfo => isZh ? '编辑分类信息' : 'Edit Category';
  String get categoryNote => isZh ? '备注' : 'Note';
  String get categoryNoteHint => isZh ? '界定分类边界，最多 30 字' : 'Boundary hint, max 30 chars';
  String get hide => isZh ? '隐藏' : 'Hide';
  String get show => isZh ? '显示' : 'Show';
  String get preset => isZh ? '预置' : 'Preset';
  String get newRootCategory => isZh ? '新建一级分类' : 'New top-level category';
  String get rootCategoryHint => isZh ? '一级分类仅作分组，记账时请选择二级条目' : 'Top-level categories are groups; pick a leaf when recording.';
  String categoryKindLabel(String kindLabel) => isZh ? '类别：$kindLabel' : 'Kind: $kindLabel';
  String get rootCategoryNameLabel => isZh ? '一级分类名称' : 'Category name';
  String get rootCategoryNameHint => isZh ? '如：宠物' : 'e.g. Pets';
  String get rootNoteLabel => isZh ? '一级备注（可选）' : 'Note (optional)';
  String get firstSubEntryTitle => isZh ? '首个二级条目' : 'First subcategory';
  String get subCategoryNameLabel => isZh ? '二级名称（必填）' : 'Subcategory name (required)';
  String get subCategoryNameHint => isZh ? '如：猫粮' : 'e.g. Cat food';
  String get subNoteLabel => isZh ? '二级备注（可选）' : 'Subcategory note (optional)';
  String get fillRootAndFirstSubError => isZh ? '请填写一级名称和首个二级条目' : 'Please fill in both names.';

  // ── Settings ──
  String get settings => isZh ? '设置' : 'Settings';
  String get version => isZh ? '版本' : 'Version';
  String get about => isZh ? '关于' : 'About';
  String get data => isZh ? '数据' : 'Data';
  String get security => isZh ? '安全' : 'Security';
  String get display => isZh ? '显示' : 'Display';
  String get backup => isZh ? '备份' : 'Backup';
  String get restore => isZh ? '恢复' : 'Restore';
  String get appLock => isZh ? '应用锁' : 'App Lock';
  String get hideAmounts => isZh ? '隐藏金额' : 'Hide Amounts';
  String get hideAmountsDesc => isZh ? '以 **** 显示金额' : 'Show **** instead of amounts';
  String get theme => isZh ? '主题' : 'Theme';
  String get themeSystem => isZh ? '跟随系统' : 'System';
  String get themeLight => isZh ? '浅色' : 'Light';
  String get themeDark => isZh ? '深色' : 'Dark';
  String get openSource => isZh ? '开源许可' : 'Open Source Licenses';
  String get privacyPolicy => isZh ? '隐私政策' : 'Privacy Policy';

  // ── Security ──
  String get locked => isZh ? '素记已锁定' : 'SuJi Locked';
  String get useBiometric => isZh ? '使用生物识别' : 'Use Biometric';
  String get enterPin => isZh ? '输入 PIN' : 'Enter PIN';
  String get failedAttempts => isZh ? '失败次数' : 'Failed attempts';

  // ── Backup ──
  String get exportData => isZh ? '导出数据' : 'Export Data';
  String get exportDesc => isZh ? '创建包含所有记账数据的备份文件' : 'Create a backup file of all your data';
  String get exportBackup => isZh ? '导出备份' : 'Export Backup';
  String get exporting => isZh ? '导出中...' : 'Exporting...';
  String get importData => isZh ? '导入数据' : 'Import Data';
  String get importDesc => isZh ? '从备份文件恢复数据' : 'Restore from a backup file';
  String get importBackup => isZh ? '导入备份' : 'Import Backup';
  String get exportFailed => isZh ? '导出失败' : 'Export failed';

  // ── Date / Calendar ──
  List<String> get calendarWeekdayLabels => isZh ? const ['一', '二', '三', '四', '五', '六', '日'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  List<String> get weekdayLabels => isZh ? const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'] : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String yearMonth(DateTime d) => isZh ? '${d.year}年${d.month}月' : '${d.year}/${d.month.toString().padLeft(2, '0')}';
  String dateWithWeekday(DateTime d, String weekday) => isZh ? '${d.year}年${d.month}月${d.day}日 $weekday' : '$weekday, ${d.month}/${d.day}/${d.year}';

  // ── Currency picker ──
  String get selectCurrency => isZh ? '选择币种' : 'Select currency';
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture(AppStrings(locale));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
