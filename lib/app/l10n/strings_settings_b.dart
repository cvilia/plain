/// 设置模块 B 组文案。
///
/// 归属文件（lib/features/settings/）：
///   backup_page / budget_page / settings_page / import_page / sync_page /
///   reminders_page / trash_page / currency_rate_page /
///   reimburse_center_page / achievements_page
///
/// 通用文案（保存 / 取消 / 删除 / 完成 / 关于 …）一律复用 [AppStrings]；
/// 枚举文案由 `strings_domain.dart` 提供，本文件不重复定义。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension SettingsBStrings on AppStrings {
  // ─────────────────────── settings_page.dart ───────────────────────
  String get myTab => isZh ? '我的' : 'Me';
  String get privacyPledge => isZh ? '隐私承诺' : 'Privacy promise';
  String get privacyPledgeDesc => isZh ? '无广告、无外联、无埋点上报' : 'No ads, no tracking, no telemetry';
  String get secLedger => isZh ? '记账' : 'Ledger';
  String get monthStartDay => isZh ? '月起始日' : 'Month start day';
  String monthStartDayValue(int n) => isZh ? '$n 日' : 'Day $n';
  String monthStartOption(int n) => isZh ? '每月 $n 日' : 'Day $n each month';
  String get fontSize => isZh ? '字体大小' : 'Font size';
  String get soundOnSave => isZh ? '记账确认音效' : 'Confirm sound';
  String get stayAfterSave => isZh ? '保存后停留在记账页' : 'Stay on the entry page after saving';
  String get appearance => isZh ? '外观' : 'Appearance';
  String get appearanceMode => isZh ? '外观模式' : 'Appearance mode';
  String get homeCards => isZh ? '首页卡片' : 'Home cards';
  String get recurringEntry => isZh ? '周期记账' : 'Recurring entries';
  String get backupRestore => isZh ? '备份与恢复' : 'Backup & Restore';
  String get bulkImport => isZh ? '批量导入' : 'Bulk import';
  String get goalSystem => isZh ? '目标体系' : 'Goals';
  String get reimburseCenter => isZh ? '报销中心' : 'Reimbursement';
  String get remindersEntry => isZh ? '提醒' : 'Reminders';
  String get automationRules => isZh ? '自动化规则' : 'Automation rules';
  String get familyMembers => isZh ? '家庭与成员' : 'Family & Members';
  String get actionLog => isZh ? '操作日志' : 'Activity log';
  String get otherSection => isZh ? '其它' : 'More';
  String get emotionFeedback => isZh ? '情绪反馈' : 'Emotion feedback';
  String get weeklyReport => isZh ? '消费周报' : 'Weekly report';

  // ─────────────────────── achievements_page.dart ───────────────────────
  String get myAchievements => isZh ? '我的成就' : 'My Achievements';
  String get streakTracking => isZh ? '连续记账' : 'Streak';
  String get streakBroken => isZh ? '已断签' : 'Broken';
  String daysCount(int n) => isZh ? '$n 天' : '$n days';
  String bestStreakDays(int n) => isZh ? '历史最长 $n 天' : 'Best: $n days';
  String get myRewards => isZh ? '我的奖励' : 'My rewards';
  String get voucher => isZh ? '权益券' : 'Voucher';
  String get voucherActivate => isZh ? 'V4.0 起生效' : 'Effective from V4.0';
  String voucherDialogBody(String activate) => isZh
      ? '将在 $activate 自动激活，可抵扣订阅时长。\n\n当前版本暂不可使用。'
      : 'Activates automatically on $activate, deductible against the subscription.\n\nNot usable in the current version.';
  String get gotIt => isZh ? '知道了' : 'Got it';
  String get badgeWall => isZh ? '徽章墙' : 'Badges';
  String get badgeFooter => isZh
      ? '记账是私事，这里不做排行榜和积分商城。\n坚持本身就是最好的奖励。'
      : 'Tracking is personal — no leaderboards, no points shop.\nConsistency is its own reward.';
  String get badgeStreak7 => isZh ? '连续 7 天' : '7-day streak';
  String get badgeStreak30 => isZh ? '连续 30 天' : '30-day streak';
  String get badgeStreak100 => isZh ? '连续 100 天' : '100-day streak';
  String get badgeFirstBudget => isZh ? '首次设预算' : 'First budget';
  String get badgeFirstRule => isZh ? '首次用规则' : 'First rule';
  String get badgeFirstExport => isZh ? '首次用导出' : 'First export';
  String get badgeMonthNoOverspend => isZh ? '月度不超支' : 'No overspend this month';
  String get badgeAccum100 => isZh ? '累计 100 笔' : '100 entries';
  String get badgeAccum500 => isZh ? '累计 500 笔' : '500 entries';
  String get badgeAccum1000 => isZh ? '累计 1000 笔' : '1000 entries';
  String get badgeGoalSavings => isZh ? '达成储蓄目标' : 'Savings goal reached';
  String get badgeDebtClear => isZh ? '还清债务' : 'Debt cleared';

  // ─────────────────────── currency_rate_page.dart ───────────────────────
  String get currencyRateTitle => isZh ? '汇率锁定' : 'Locked Rates';
  String get addRate => isZh ? '新增汇率' : 'Add rate';
  String get noLockedRate => isZh ? '还没有锁定汇率' : 'No locked rates yet';
  String noLockedRateHint(String base) => isZh
      ? '给外币账户设定「1 单位外币 = 多少 $base」后，用该账户记账时会自动折算成本位币'
      : 'Set "1 foreign unit = how much $base" for a foreign-currency account; entries using it will be converted to the base currency automatically';
  String get rateLocked => isZh ? '已锁定汇率' : 'Rate locked';
  String get unlockRate => isZh ? '解除锁定' : 'Unlock rate';
  String unlockRateConfirm(String pairKey) =>
      isZh ? '解除 $pairKey 的锁定？已记的账单不受影响。' : 'Unlock $pairKey? Existing entries are unaffected.';
  String get unlockRelation => isZh ? '解除' : 'Unlock';
  String get selectForeignCurrency => isZh ? '选择外币' : 'Select foreign currency';
  String get rateMustBePositive => isZh ? '请输入大于 0 的汇率' : 'Enter a rate greater than 0';
  String saveFailedDetail(String detail) => isZh ? '保存失败：$detail' : 'Save failed: $detail';
  String get addLockedRateTitle => isZh ? '新增锁定汇率' : 'Add locked rate';
  String get editLockedRateTitle => isZh ? '修改锁定汇率' : 'Edit locked rate';
  String get foreignCurrency => isZh ? '外币' : 'Foreign currency';
  String rateFieldLabel(String from, String base) => '1 $from = ? $base';
  String get savingEllipsis => isZh ? '保存中…' : 'Saving…';
  String get rateLockedBadge => isZh ? '已锁定' : 'Locked';
  String get deleteLockedRate => isZh ? '删除锁定汇率' : 'Delete locked rate';
  String get rateNoteSource => isZh
      ? '汇率只有这一个来源：你手动设定的值。本项目不接外部行情，不会发起任何网络请求。'
      : 'The exchange rate has exactly one source: the value you set manually. This app never fetches market data and makes no network requests.';
  String rateNoteConvert(String base) => isZh
      ? '锁定后，用该外币账户记账时按此汇率折成本位币 $base；本位币金额用于所有统计，原币金额单独保留并双显示。'
      : 'Once locked, entries using that foreign-currency account are converted to the base currency $base at this rate; the base-currency amount drives all statistics, while the original amount is kept and shown alongside.';
  String get rateNotePerEntry => isZh
      ? '某笔账单也可以带自己的汇率（记在账单上），它优先于这里的锁定值。'
      : 'An individual entry may carry its own rate (stored on the entry), which takes precedence over the locked value here.';

  // ─────────────────────── trash_page.dart ───────────────────────
  String get trashTitle => isZh ? '回收站' : 'Trash';
  String get restored => isZh ? '已恢复' : 'Restored';
  String restoreFailed(String detail) => isZh ? '恢复失败: $detail' : 'Restore failed: $detail';
  String get restoreAll => isZh ? '全部恢复' : 'Restore all';
  String restoreAllConfirm(int n) =>
      isZh ? '将恢复回收站中的 $n 笔账单？' : 'Restore $n entries from Trash?';
  String restoredCount(int n) => isZh ? '已恢复 $n 笔账单' : 'Restored $n entries';
  String get purgeForever => isZh ? '彻底删除' : 'Delete permanently';
  String get purgeForeverConfirm =>
      isZh ? '彻底删除后无法恢复，确定继续？' : 'Permanent deletion cannot be undone. Continue?';
  String get purgedForever => isZh ? '已彻底删除' : 'Permanently deleted';
  String deleteFailedDetail(String detail) => isZh ? '删除失败: $detail' : 'Delete failed: $detail';
  String get emptyTrashTitle => isZh ? '清空回收站' : 'Empty Trash';
  String emptyTrashConfirm(int n) => isZh
      ? '将彻底删除 $n 笔账单，删除后无法恢复。确定继续？'
      : '$n entries will be permanently deleted and cannot be recovered. Continue?';
  String get emptyAction => isZh ? '清空' : 'Empty';
  String get trashEmptied => isZh ? '回收站已清空' : 'Trash emptied';
  String emptyFailed(String detail) => isZh ? '清空失败: $detail' : 'Empty failed: $detail';
  String get trashRetentionHint =>
      isZh ? '删除的账单保留 30 天，到期自动清除' : 'Deleted entries are kept for 30 days, then purged automatically';
  String get trashEmptyTitle => isZh ? '回收站是空的' : 'Trash is empty';
  String get trashEmptySubtitle =>
      isZh ? '删除的账单会暂时存放在这里' : 'Deleted entries are kept here temporarily';
  String daysRemaining(int n) => isZh ? '剩余 $n 天' : '$n days left';
  String recordedSuffix(String ts) => isZh ? '$ts 记账' : 'Recorded $ts';

  // ─────────────────────── reminders_page.dart ───────────────────────
  String get remindersTitle => isZh ? '提醒中心' : 'Reminder Center';
  String get markedRead => isZh ? '已标记为已读' : 'Marked as read';
  String get recurringRuleGone => isZh ? '这条周期规则已经不在了' : 'This recurring rule no longer exists';
  String get recurringRuleDisabled => isZh
      ? '已关掉这条周期规则；别忘了到原扣款渠道取消自动续费'
      : 'Recurring rule disabled; remember to cancel auto-renew at the original channel';
  String get segAll => isZh ? '全部' : 'All';
  String get segBudget => isZh ? '预算' : 'Budget';
  String get segEntries => isZh ? '账单' : 'Entries';
  String get segRecurring => isZh ? '周期' : 'Recurring';
  String get muteAll => isZh ? '全部静音' : 'Mute all';
  String get muteAllBody => isZh ? '不推系统通知，仅进提醒中心' : 'No system notifications — shown in Reminder Center only';
  String get noReminders => isZh ? '暂无提醒' : 'No reminders';
  String get tieredTitle => isZh ? '分级通知（G-3）：' : 'Tiered notifications (G-3): ';
  String get silent => isZh ? '静默' : 'Silent';
  String get silentExplained => isZh ? '只进提醒中心、不响铃；' : 'shown in Reminder Center only, no ring; ';
  String get ring => isZh ? '响铃' : 'Ring';
  String get ringExplained => isZh ? '同时走系统通知。' : 'also delivered via system notification.';
  String get budgetTieredPrefix =>
      isZh ? '预算 90% 静默、100% 响铃 —— 但两者都' : 'Budget at 90% is silent, at 100% it rings — but both still ';
  String get notBlocking => isZh ? '不阻挡你继续记账' : "don't stop you from tracking";
  String get fullStop => isZh ? '。' : '.';
  String get historyRetention => isZh ? '提醒历史保留近 90 天' : 'Reminder history is kept for the last 90 days';
  String get reminderTypes => isZh ? '提醒类型' : 'Reminder types';
  String get muteAllSwitchSubtitle =>
      isZh ? '开启后不推系统通知，仅进提醒中心' : 'When on, no system notifications — shown in Reminder Center only';
  String get quietHoursHint => isZh
      ? '夜间 23:00–07:00 响铃自动降为静默，次日 08:00 汇总（G-3）'
      : 'Rings become silent during 23:00–07:00 and are summarized at 08:00 the next day (G-3)';
  String get later => isZh ? '稍后' : 'Later';
  String get snoozed => isZh ? '已稍后提醒' : 'Snoozed';
  String get read => isZh ? '已读' : 'Read';
  String get unread => isZh ? '未读' : 'Unread';
  String reminderMetaLine(String md, String hm, String read) => '$md $hm · $read';

  // ─────────────────────── sync_page.dart ───────────────────────
  String get webdavSync => isZh ? 'WebDAV 同步' : 'WebDAV Sync';
  String get saveServerFirst => isZh ? '请先保存服务器配置' : 'Save the server configuration first';
  String incrSyncSuccess(int pushed, int pulled, int conflicts) => isZh
      ? '增量同步成功：上传 $pushed 条 · 应用 $pulled 条${conflicts > 0 ? ' · 新冲突 $conflicts 条' : ''}'
      : 'Incremental sync succeeded: $pushed uploaded · $pulled applied${conflicts > 0 ? ' · $conflicts new conflicts' : ''}';
  String incrSyncFailed(String message) => isZh ? '增量同步失败：$message' : 'Incremental sync failed: $message';
  String get unknownError => isZh ? '未知错误' : 'Unknown error';
  String get configSaved => isZh ? '配置已保存' : 'Configuration saved';
  String get connectOk => isZh ? '连接成功' : 'Connected';
  String get connectFail => isZh ? '连接失败，请检查地址和凭据' : 'Connection failed — check the address and credentials';
  String uploadedWithSize(String message, String sizeKb) => '$message ($sizeKb KB)';
  String get restoreFromCloudTitle => isZh ? '从云端恢复' : 'Restore from cloud';
  String get restoreFromCloudConfirm => isZh
      ? '将用云端备份替换本地数据，当前数据会被覆盖。确定继续？'
      : 'The cloud backup will replace your local data, overwriting the current data. Continue?';
  String get confirmRestore => isZh ? '确定恢复' : 'Restore';
  String get serverConfig => isZh ? '服务器配置' : 'Server configuration';
  String get serverConfigDesc => isZh
      ? '支持坚果云、NextCloud 等 WebDAV 服务。数据仅在你自己的服务器上，不经过第三方。'
      : 'Supports WebDAV services such as Nutstore and NextCloud. Your data stays on your own server and never passes through a third party.';
  String get serverUrl => isZh ? '服务器地址' : 'Server URL';
  String get username => isZh ? '用户名' : 'Username';
  String get passwordAppPwd => isZh ? '密码 / 应用专用密码' : 'Password / app-specific password';
  String get showPassword => isZh ? '显示密码' : 'Show password';
  String get hidePassword => isZh ? '隐藏密码' : 'Hide password';
  String get remotePath => isZh ? '远程路径' : 'Remote path';
  String get testConnection => isZh ? '测试连接' : 'Test connection';
  String get saveConfig => isZh ? '保存配置' : 'Save configuration';
  String get syncOps => isZh ? '同步操作' : 'Sync actions';
  String get syncOpsDesc => isZh
      ? '上传会将本地数据备份到云端；恢复会用云端备份覆盖本地数据。'
      : 'Upload backs up your local data to the cloud; restore overwrites local data with the cloud backup.';
  String get syncingEllipsis => isZh ? '同步中...' : 'Syncing...';
  String get uploadToCloud => isZh ? '上传备份到云端' : 'Upload backup to cloud';
  String get restoreFromCloud => isZh ? '从云端恢复' : 'Restore from cloud';
  String get incrementalSync => isZh ? '增量同步' : 'Incremental sync';
  String get incrementalSyncDesc => isZh
      ? '按账单级变更同步：本机写入后立刻推送，前台每 10 秒拉取一次。'
      : 'Syncs entry-level changes: pushed immediately after local writes, pulled every 10 seconds while in the foreground.';
  String get incrementalSyncAttachmentNote => isZh
      ? '附件只同步「哪笔账单挂了附件」，图片本身不出设备。'
      : 'For attachments only the link is synced; images never leave the device.';
  String get autoSync => isZh ? '自动同步' : 'Auto sync';
  String get syncOn => isZh ? '已开启' : 'On';
  String get syncOff => isZh ? '已关闭（手动同步仍可用）' : 'Off (manual sync still available)';
  String get syncNow => isZh ? '立即增量同步' : 'Sync now';
  String get conflictCenter => isZh ? '冲突中心' : 'Conflict Center';
  String get noConflicts => isZh ? '没有待裁决的冲突' : 'No conflicts to resolve';
  String conflictsPending(int n) => isZh ? '$n 条待裁决' : '$n to resolve';
  String get notesSection => isZh ? '说明' : 'Notes';
  String get syncNotesBody => isZh
      ? '• 同步基于整库备份文件，适合个人多设备使用\n'
          '• 恢复后需重启应用生效\n'
          '• 密码仅存储在本地设备，不会上传到任何第三方服务器\n'
          '• 坚果云用户请在「安全设置」中生成应用专用密码'
      : '• Sync is based on a full-database backup file, suited for personal multi-device use\n'
          '• Restart the app after restoring for it to take effect\n'
          '• The password is stored only on this device and never uploaded to any third-party server\n'
          '• Nutstore users: generate an app-specific password in "Security settings"';

  // ─────────────────────── import_page.dart ───────────────────────
  String get importTitle => isZh ? '数据导入' : 'Import Data';
  String get csvTooShort =>
      isZh ? 'CSV 内容不足，至少需要表头和一行数据' : 'Not enough CSV content — a header and at least one data row are required';
  String get pasteCsv => isZh ? '粘贴 CSV 内容' : 'Paste CSV content';
  String get pasteCsvDesc => isZh
      ? '从竞品 App 导出 CSV 后，将内容粘贴到下方。支持钱迹、随手记、挖财等主流格式。'
      : 'Export a CSV from another app and paste the content below. Popular formats such as Qianji, Suishouji and Wacai are supported.';
  String get csvSampleHint => isZh
      ? '日期,金额,分类,备注\n2024-01-15,25.00,餐饮,午餐\n...'
      : 'date,amount,category,note\n2024-01-15,25.00,Dining,Lunch\n...';
  String get nextMapColumns => isZh ? '下一步：映射列' : 'Next: map columns';
  String get mapColumns => isZh ? '映射列' : 'Map columns';
  String mapColumnsDesc(int n) => isZh ? '共 $n 行数据，请指定各列含义' : '$n data rows — specify what each column means';
  String get colDate => isZh ? '日期列 *' : 'Date column *';
  String get colAmount => isZh ? '金额列 *' : 'Amount column *';
  String get colCategory => isZh ? '分类列' : 'Category column';
  String get colNote => isZh ? '备注列' : 'Note column';
  String get colMerchant => isZh ? '商家列' : 'Merchant column';
  String get back => isZh ? '返回' : 'Back';
  String get preview => isZh ? '预览' : 'Preview';
  String get none => isZh ? '（无）' : '(None)';
  String previewSummary(int canImport, int skipped) =>
      isZh ? '可导入 $canImport 条，跳过 $skipped 条异常' : '$canImport importable, $skipped skipped as invalid';
  String get errorRows => isZh ? '异常行' : 'Invalid rows';
  String moreCount(int n) => isZh ? '... 共 $n 条' : '... $n total';
  String importCount(int n) => isZh ? '导入 $n 条' : 'Import $n';
  String get importDone => isZh ? '导入完成' : 'Import complete';
  String get resultSuccess => isZh ? '成功导入' : 'Imported';
  String get resultDeduped => isZh ? '去重跳过' : 'Skipped (duplicate)';
  String get resultFailed => isZh ? '失败/异常' : 'Failed/invalid';
  String get errorDetails => isZh ? '异常详情' : 'Error details';
  String get stepPaste => isZh ? '粘贴' : 'Paste';
  String get stepMap => isZh ? '映射' : 'Map';
  String get stepPreview => isZh ? '预览' : 'Preview';

  // ─────────────────────── backup_page.dart ───────────────────────
  String get createBackup => isZh ? '生成备份' : 'Create backup';
  String get noteBackupIs => isZh ? '备份为' : 'The backup is ';
  String get noteWholeEncrypted => isZh ? '整库加密文件' : 'a whole-database encrypted file';
  String get noteBackupRest =>
      isZh ? '，包含全部账单、分类、账户与设置。通过系统分享保存到网盘或电脑。' : ' containing all entries, categories, accounts and settings. Save it to the cloud or a computer via the system share sheet.';
  String get noteUninstallPrefix => isZh ? '卸载应用会清除本地数据，' : 'Uninstalling the app clears local data — ';
  String get noteBackupEarly => isZh ? '请提前备份' : 'back up in advance';
  String lastExportOk(String suffix) => isZh ? '上次导出成功$suffix' : 'Last export succeeded$suffix';
  String get historyBackups => isZh ? '历史备份' : 'Backup history';
  String get noBackups => isZh ? '还没有备份' : 'No backups yet';
  String get noBackupsHint =>
      isZh ? '点击右上角「生成备份」创建第一份' : 'Tap "Create backup" in the top-right to make your first one';
  String preRestoreBackup(String name) =>
      isZh ? '恢复前自动备份 · $name' : 'Pre-restore backup · $name';
  String get fromFileImport => isZh ? '从文件导入' : 'Import from file';
  String get restoreFlow => isZh ? '恢复流程' : 'Restore flow';
  String get restoreFlowSteps => isZh
      ? '选择备份 → 校验密码与版本 → 预览（笔数 / 时间范围）→ 确认。'
      : 'Choose a backup → verify password and version → preview (count / date range) → confirm.';
  String get restoreWillPrefix => isZh ? '恢复前系统会' : 'Before restoring, the app will ';
  String get restoreAutoBackup => isZh ? '自动生成一份「恢复前备份」' : 'automatically create a "pre-restore backup"';
  String get restoreRevertSuffix => isZh ? '，操作可反悔。' : ', so the operation can be undone.';
  String get setBackupPassword => isZh ? '设置备份密码' : 'Set backup password';
  String get exportAction => isZh ? '导出' : 'Export';
  String get passwordMin4 => isZh ? '密码至少 4 位' : 'Password must be at least 4 characters';
  String get backupFileNotCreated => isZh ? '备份文件未生成' : 'Backup file was not created';
  String exportOkEncrypted(String sizeKb) => isZh ? '导出成功（已加密）· $sizeKb KB' : 'Export succeeded (encrypted) · $sizeKb KB';
  String exportOkPassword(String sizeKb) =>
      isZh ? '导出成功（口令保护）· $sizeKb KB' : 'Export succeeded (password-protected) · $sizeKb KB';
  String get shareBackupText => isZh ? '素记备份（需密码）' : 'SuJi backup (password required)';
  String get savedToDocsShareUnavailable => isZh
      ? '文件已保存到应用文档目录（系统分享不可用）'
      : 'File saved to the app documents folder (system share unavailable)';
  String exportFailedDetail(String detail) => isZh ? '导出失败: $detail' : 'Export failed: $detail';
  String get encryptFailedRekey => isZh
      ? '加密失败：无法用密码改写备份（请重试或重启应用）'
      : 'Encryption failed: cannot rewrite the backup with the password (retry or restart the app)';
  String get password => isZh ? '密码' : 'Password';
  String get passwordMin4Hint => isZh ? '至少 4 位' : 'At least 4 characters';
  String get forgotPasswordHint =>
      isZh ? '忘记密码将无法恢复备份' : 'A forgotten password means the backup cannot be restored';
  String get deleteBackupTitle => isZh ? '删除备份' : 'Delete backup';
  String deleteBackupConfirm(String name) => isZh
      ? '确定删除「$name」？删除后无法恢复该备份。'
      : 'Delete "$name"? This backup cannot be recovered after deletion.';
  String get deletedBackup => isZh ? '已删除备份' : 'Backup deleted';
  String get enterBackupPassword => isZh ? '输入备份密码' : 'Enter backup password';
  String get verify => isZh ? '验证' : 'Verify';
  String get wrongPassword => isZh ? '密码错误' : 'Incorrect password';
  String backupUnreadable(String detail) => isZh ? '备份无法读取: $detail' : 'Backup unreadable: $detail';
  String get previewUnavailable => isZh
      ? '⚠️ 无法读取备份摘要，文件可能已损坏或不完整'
      : '⚠️ Cannot read the backup summary; the file may be corrupt or incomplete';
  String backupSummary(String preview) => isZh ? '备份摘要：$preview' : 'Backup summary: $preview';
  String get importBackupTitle => isZh ? '导入备份' : 'Import backup';
  String importReplaceConfirm(String preview) => isZh
      ? '$preview\n\n导入将替换当前所有数据，此操作不可恢复。确定继续？'
      : '$preview\n\nImporting will replace all current data and cannot be undone. Continue?';
  String get confirmImport => isZh ? '确定导入' : 'Import';
  String get preRestoreGenerated => isZh ? '已生成「恢复前自动备份」' : 'Pre-restore backup created';
  String get importDoneBare => isZh ? '导入完成' : 'Import complete';

  // ─────────────────────── reimburse_center_page.dart ───────────────────────
  String get noReimburseEntries => isZh ? '还没有报销账单' : 'No reimbursable entries yet';
  String get noReimburseEntriesHint =>
      isZh ? '在账单详情里把一笔支出标为「待报销」' : 'Mark an expense as "Pending" in its detail page';
  String reimburseGroupPending(int n) => isZh ? '待报销 · $n 笔' : 'Pending · $n';
  String reimburseGroupSubmitted(int n) => isZh ? '已提交 · $n 笔' : 'Submitted · $n';
  String reimburseGroupArrived(int n) => isZh ? '已到账 · $n 笔' : 'Reimbursed · $n';
  String get pendingRecoverAmount => isZh ? '待收回金额' : 'Amount to recover';
  String entriesCountText(int n) => isZh ? '$n 笔' : '$n';
  String get markSubmitted => isZh ? '标记已提交' : 'Mark as submitted';
  String get markArrived => isZh ? '标记已到账' : 'Mark as reimbursed';
  String get abandonReimburse => isZh ? '放弃报销' : 'Abandon';
  String get reimburseAbandonedToast => isZh ? '已放弃报销' : 'Reimbursement abandoned';
  String get updatedToast => isZh ? '已更新' : 'Updated';
  String get actionFailed => isZh ? '操作失败' : 'Action failed';
  String get reimburseNote1Plain => isZh
      ? '报销到账时系统自动生成一笔等额收入并 —— 净效果为 0， 不会把报销算成额外收入。'
      : 'When a reimbursement arrives, the app automatically creates an equal income entry and ';
  String get reimburseNote1A => isZh ? '报销到账时系统自动生成一笔等额收入并' : 'When a reimbursement arrives, the app automatically creates an equal income entry and ';
  String get reimburseNote1B => isZh ? '冲销原支出' : 'offsets the original expense';
  String get reimburseNote1C =>
      isZh ? ' —— 净效果为 0， 不会把报销算成额外收入。' : ' — a net effect of 0, so reimbursements are never counted as extra income.';
  String get reimburseNote2Plain => isZh
      ? '支出统计中该笔（体现真实消费）， 到账收入标记为「报销回款」，不计入收入口径。'
      : 'In expense statistics that entry ';
  String get reimburseNote2A => isZh ? '支出统计中该笔' : 'In expense statistics that entry ';
  String get reimburseNote2B => isZh ? '始终保留' : 'is always kept';
  String get reimburseNote2C => isZh
      ? '（体现真实消费）， 到账收入标记为「报销回款」，不计入收入口径。'
      : ' (reflecting real spending); the incoming reimbursement is labeled "reimbursement" and excluded from income totals.';

  // ─────────────────────── budget_page.dart ───────────────────────
  String switchTo(String label) => isZh ? '切换到$label' : 'Switch to $label';
  String get switchAction => isZh ? '切换' : 'Switch';
  String get noCategoryLimits => isZh ? '还没有分类限额' : 'No category limits yet';
  String get noCategoryLimitsHint =>
      isZh ? '给常超支的分类设一个上限' : 'Set a cap for categories you often overspend on';
  String get addLimit => isZh ? '添加限额' : 'Add limit';
  String categoryLimitsEyebrow(int n) => isZh ? '分类限额 · $n 类' : 'Category limits · $n';
  String envelopeEyebrow(int n, int overs) => isZh
      ? '信封 · $n 个${overs > 0 ? ' · $overs 个超支' : ''}'
      : 'Envelopes · $n${overs > 0 ? ' · $overs over' : ''}';
  String envelopeRemaining(String amount) => isZh ? '余 $amount' : 'Left $amount';
  String envelopeOver(String amount) =>
      isZh ? '已超支 $amount，不可跨类挪用' : 'Over by $amount — no cross-category borrowing';
  String envelopeSpent(String amount) => isZh ? '已花 $amount' : 'Spent $amount';
  String get envelopeNote => isZh
      ? '信封法下每个信封独立滚存；某个信封超支时，不能把别类的额度挪过来。'
      : 'Under the envelope method each envelope rolls over independently; when one is over budget you cannot borrow from another category.';
  String unallocated(String amount) => isZh ? '待分配 $amount' : 'Unallocated $amount';
  String overAllocated(String amount) => isZh ? '已超分配 $amount' : 'Over-allocated $amount';
  String get allocationDetail => isZh ? '分配明细' : 'Allocation detail';
  String get currentIncome => isZh ? '当期收入' : 'Current income';
  String get allocatedToCategories => isZh ? '已分配到分类' : 'Allocated to categories';
  String get unallocatedLabel => isZh ? '待分配' : 'Unallocated';
  String get zeroBasedNote => isZh
      ? '零基预算要求把收入分配干净（待分配为 0）。分配用的是同一批分类预算，不影响账单。'
      : 'Zero-based budgeting requires allocating the income in full (unallocated = 0). It reuses the same category budgets and does not affect entries.';
  String get ratioBucketsEyebrow => isZh ? '三档占比' : 'Three buckets';
  String ratioTargetLine(String actual, String target) =>
      isZh ? '$actual% / 目标 $target%' : '$actual% / target $target%';
  String ratioActualLine(String actual, String target, String delta) =>
      isZh ? '$actual · 目标 $target$delta' : '$actual · target $target$delta';
  String ratioOver(String amount) => isZh ? ' · 超出 $amount' : ' · over by $amount';
  String ratioUnder(String amount) => isZh ? ' · 低于 $amount' : ' · under by $amount';
  String ratioNote(int rigidCount) => isZh
      ? '「需要」取分类的刚性支出标记（$rigidCount 条已标记），其余算「想要」，'
          '「储蓄」= 收入 − 总支出。可在分类管理里调整刚性标记。'
      : '"Needs" uses a category\'s rigid-expense flag ($rigidCount marked); the rest counts as "Wants", and "Savings" = income − total spending. Adjust the rigid flag in category management.';
  String get totalBudgetLabel => isZh ? '总预算' : 'Total budget';
  String get deleteBudgetTitle => isZh ? '删除预算' : 'Delete budget';
  String get deleteBudgetConfirm => isZh
      ? '删除后不可恢复，确定删除这笔预算？'
      : 'This cannot be undone. Delete this budget?';
  String get budgetAmountTitle => isZh ? '预算金额' : 'Budget amount';
  String get rolloverLabel => isZh ? '结余滚存' : 'Roll over leftover';
  String get rolloverSubtitle =>
      isZh ? '上期未用完的额度计入本期' : 'Unused limit from the previous period carries into this one';
  String get budgetUsedThisMonth => isZh ? '本月预算已用' : 'This month\'s budget used';
  String get spentLabel => isZh ? '已花' : 'Spent';
  String get remainingLabel => isZh ? '剩余' : 'Remaining';
  String overSpent(String amount) => isZh ? '已超支 $amount' : 'Over by $amount';
  String remainingAmount(String amount) => isZh ? '剩余 $amount' : '$amount left';
  String get editAction => isZh ? '修改' : 'Edit';
  String get pickCategory => isZh ? '选择分类' : 'Select category';
  String get budgetNote1Body => isZh
      ? '信封（每类一个信封，花完即止） / 零基（收入全部预先分配，余额为 0） / 50-30-20（必要 50 · 想要 30 · 储蓄 20） / 分类限额（最轻量）。'
      : 'Envelope (one per category, stop when empty) / Zero-based (allocate all income, balance 0) / 50-30-20 (needs 50 · wants 30 · savings 20) / Category limits (lightest).';
  String get budgetNote1Title => isZh ? '四套方法论：' : 'Four methodologies: ';
  String get budgetNote2Plain => isZh
      ? '进度条三级着色与「是否响铃通知」绑定（G-3）： ，但两者都不阻挡你继续记账。'
      : 'The progress bar\'s three-level coloring is tied to "whether it rings" (G-3): ';
  String get budgetNote2A => isZh ? '进度条三级着色与「是否响铃通知」绑定（G-3）： ' : 'The progress bar\'s three-level coloring is tied to "whether it rings" (G-3): ';
  String get budgetNote2B => isZh ? '90% 静默提醒、100% 响铃通知' : 'silent at 90%, rings at 100%';
  String get budgetNote2C => isZh ? '，但两者都不阻挡你继续记账。' : ', but neither stops you from tracking.';
}
