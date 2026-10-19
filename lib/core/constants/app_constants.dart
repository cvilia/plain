/// Product constants. See 05-C3.
library;

class MoneyRules {
  MoneyRules._();
  static const int maxAmountCents = 9999999999;
  static const int decimalDigits = 2;
  static const String defaultCurrency = 'CNY';
}

/// STORY-9.3 多币种。
class CurrencyRules {
  CurrencyRules._();
  /// 常用币种符号（16 个：本位币 CNY + 15 个常用外币）。
  ///
  /// ⚠️ 加币种前**必须先验 MiSans 字形覆盖**（venv `fontTools` 查 cmap），
  /// 别凭常识填：`ł`(PLN)、`د.إ`(AED)、`﷼`(SAR)、`₪`、`₴` 均缺字形，
  /// 直接写会渲染成豆腐块。CHF 无广泛通用符号，按惯例直接用代码
  /// （`symbolOf` 的回退逻辑天然支持，UI 会跳过重复的符号列）。
  ///
  /// ⚠️ 顺序即选择器顺序（按常用度排列），不要随手打乱。
  /// ⚠️ key 必须与 [names] 完全一致（有回归测试钉死）。
  static const Map<String, String> symbols = {
    // 本位币
    'CNY': '¥',
    // 最常用
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    // 亚太（出境高频）
    'JPY': 'JP¥',
    'HKD': r'HK$',
    'MOP': r'MOP$',
    'TWD': r'NT$',
    'KRW': '₩',
    'SGD': r'S$',
    'THB': '฿',
    'MYR': 'RM',
    'AUD': r'A$',
    'NZD': r'NZ$',
    // 欧美
    'CAD': r'C$',
    'CHF': 'CHF',
  };

  static String symbolOf(String code) => symbols[code] ?? code;

  /// 币种中文名。选择器与「1 USD = 7.20 CNY」这类展示都用它，
  /// 避免用户只看到 `USD` / `TWD` 这类代码而不知道是哪个币种。
  /// key 必须与 [symbols] 完全一致。
  static const Map<String, String> names = {
    'CNY': '人民币',
    'USD': '美元',
    'EUR': '欧元',
    'GBP': '英镑',
    'JPY': '日元',
    'HKD': '港元',
    'MOP': '澳门元',
    'TWD': '新台币',
    'KRW': '韩元',
    'SGD': '新加坡元',
    'THB': '泰铢',
    'MYR': '马来西亚林吉特',
    'AUD': '澳大利亚元',
    'NZD': '新西兰元',
    'CAD': '加拿大元',
    'CHF': '瑞士法郎',
  };

  /// 未知代码回退为代码本身，不抛错。
  static String nameOf(String code) => names[code] ?? code;

  /// 汇率在库里存**整数微单位**（rate × 1e6），避免浮点进业务数据。
  /// 6 位小数对汇率足够（7.203456）。
  static const int rateMicroScale = 1000000;

  static int rateToMicro(double rate) => (rate * rateMicroScale).round();

  static double rateFromMicro(int micro) => micro / rateMicroScale;
}

class CategoryRules {
  CategoryRules._();
  static const int maxNameLength = 6;
  static const int maxHierarchyDepth = 2;
  static const int gridPageSize = 8;
  static const int sortOrderStep = 10;
}

class PagingRules {
  PagingRules._();
  static const int pageSize = 50;
  static const int prefetchThreshold = 10;
}

class DraftRules {
  DraftRules._();
  static const Duration draftTtl = Duration(hours: 24);
}

class UiDurations {
  UiDurations._();
  static const Duration saveToast = Duration(milliseconds: 1500);
  static const Duration undoWindow = Duration(seconds: 5);
  static const Duration revealBalance = Duration(seconds: 5);
  static const Duration shortAnim = Duration(milliseconds: 160);
}

class TrashRules {
  TrashRules._();
  /// Soft-deleted rows are physically purged after this window.
  /// Matches the recycle-bin retention period (PRD F7.7).
  static const Duration trashTtl = Duration(days: 30);
}

/// STORY-6.2 分割交易。
class SplitRules {
  SplitRules._();
  /// 一笔最多拆成多少子笔（PRD STORY-6.2）。
  static const int maxChildren = 10;
  static const int minChildren = 2;
  /// 未分类占位分类 id（合并回父笔时使用）。
  static const String uncategorizedId = 'other';
}

/// STORY-6.3 提醒中心。
class ReminderRules {
  ReminderRules._();
  /// 夜间免打扰（G-3）：响铃降级为静默。
  static const int quietStartHour = 23;
  static const int quietEndHour = 7;
  /// 汇总推送时刻（次日）。
  static const int summaryHour = 8;
  /// 夜间汇总的回看窗口：覆盖 23:00–08:00 的整段夜间。
  static const int quietLookbackHours = 12;
  /// 提醒历史保留天数。
  static const Duration historyTtl = Duration(days: 90);
  /// 信用卡还款提醒提前天数。
  static const int creditDueAheadDays = 3;
  /// 订阅到期提前提醒天数（与信用卡是两个独立触发源，故各留一个常量）。
  static const int subscriptionAheadDays = 3;
  /// 判定「连续扣款的订阅」所需的最小已扣款次数。
  static const int subscriptionMinCharges = 2;
  /// 异常支出：单笔 > 近 90 天 P90 的倍数。
  static const double anomalyP90Factor = 2.0;
  /// 异常支出：当日合计 > 近 N 日均值的倍数。
  static const double anomalyDailyFactor = 3.0;
  static const int anomalyDailyWindowDays = 30;

  /// 单笔异常的**扫描回看天数**（含今天）。
  ///
  /// PRD 只规定判据（P90×2），没规定扫描窗口；离线 App 不常驻后台，只看今天的话
  /// 某天没打开就永远漏报。放宽到近几天 + 按账单 id 去重，重复扫描不会重复提醒。
  static const int anomalyScanLookbackDays = 3;
  /// 备份提醒间隔。
  static const Duration backupRemindInterval = Duration(days: 30);
  /// 默认预算预警阈值。
  static const double budgetWarnRatio = 0.8;
  static const double budgetOverRatio = 1.0;
  /// 提醒列表的系统通知 id 基址（同一 id 重复推送会覆盖，不轰炸）。
  static const int notificationIdBase = 1000;
  /// 夜间汇总摘要的通知 id。
  static const int digestNotificationId = 9900;
  /// 提醒开关的本地偏好键。
  ///
  /// 与 `sync_scope.dart` 的 `kSyncedSettingKeys` 中同名键一致——
  /// PRD 8.1 把「提醒开关」列为可同步设置。
  static const String kPrefReminder = 'pref.reminder';

  /// 是否落在夜间免打扰时段（G-3）。
  static bool isQuietHour(int hour) =>
      hour >= quietStartHour || hour < quietEndHour;
}

/// STORY-7.1 沉淀基金 / 储蓄目标。
class SavingsRules {
  SavingsRules._();
  /// 每月需存 =（目标 − 已存）÷ 剩余月数；剩余月数至少按 1 算，避免除零。
  static const int minRemainingMonths = 1;
}

/// STORY-11.1 预算方法论：50/30/20 三档目标比例（基点）。
///
/// 方法论名即比例，属**固定预设**（非用户可调项）；放在这里是为了不让
/// 50/30/20 变成算式里的裸数字。储蓄取余下部分。
class BudgetRatioRules {
  BudgetRatioRules._();
  static const int needsBp = 5000;
  static const int wantsBp = 3000;
  static const int savingsBp = 10000 - needsBp - wantsBp;
}

/// STORY-11.3 交叉分析：金额区间的分档边界（分）。
///
/// 分档为「< 上界」的累计口径：`<100 / 100–500 / 500–1000 / 1000–5000 / ≥5000`。
/// 档位**文案**已收口到 `AppStrings`（`crossAmountUnderLabel` / `crossAmountOverLabel`，
/// 见 `app/l10n/strings_core.dart`），本类只保留纯数值边界。
class CrossAnalysisRules {
  CrossAnalysisRules._();
  static const List<int> boundsCents = [10000, 50000, 100000, 500000];
}

/// STORY-2.2 信用卡。
class CreditCardRules {
  CreditCardRules._();
  /// 账单日 / 还款日取值范围（PRD：1–28）。
  static const int minDay = 1;
  static const int maxDay = 28;
  /// 未配置还款日时的默认免息宽限天数。
  static const int defaultGraceDays = 20;
}

/// STORY-5.4 情绪反馈 + STORY-6.3 异常提醒共同统计口径。
class StatsWindowRules {
  StatsWindowRules._();
  /// 统计窗口：该分类近 N 天已入账支出账单。
  static const int windowDays = 90;
  /// 最小样本量：不足此数不触发任何阈值反馈。
  static const int minSamples = 5;
  /// 高额阈值：单笔金额 > 该分类 P90 的 N 倍。
  static const double highAmountMultiplier = 2.0;
}

/// STORY-5.4 情绪反馈。
class EmotionFeedbackRules {
  EmotionFeedbackRules._();
  /// 每周最多触发次数（防轰炸）。
  static const int weeklyMaxCount = 3;
  /// 每周计数的本地键。
  static const String kPrefEnabled = 'pref.emotion.enabled';
  static const String kPrefWeekCount = 'pref.emotion.week_count';
  static const String kPrefWeekKey = 'pref.emotion.week_key';
  /// 反馈卡片自动消失时长。
  static const Duration cardDuration = Duration(seconds: 4);
}

/// STORY-5.5 游戏化留存：连续记账 + 成就徽章 + 权益券。
class GamificationRules {
  GamificationRules._();
  /// 连续记账里程碑：达到该天数发放权益券。
  static const Map<int, int> streakVoucherMilestones = {
    7: 1,   // 连续 7 天 → 权益券 ×1
    30: 3,  // 连续 30 天 → 权益券 ×3
    100: 0, // 连续 100 天 → 终身卡抽奖资格（券数 0 表示特殊奖励）
  };
  /// 累计记账笔数徽章阈值。
  static const List<int> entryCountMilestones = [100, 500, 1000, 5000, 10000];

  /// 坚持类徽章阈值（与 `streakVoucherMilestones` 同一批天数，但**徽章与券是两件事**：
  /// 原先只发了券没点亮徽章，成就页三个坚持徽章永远灰着）。
  static const List<int> streakBadgeMilestones = [7, 30, 100];
  /// 权益券生效版本标注。
  static const String voucherActivateLabel = 'V4.0 起生效';
  /// 本地存储键。
  static const String kPrefStreakDays = 'pref.game.streak_days';
  static const String kPrefStreakBest = 'pref.game.streak_best';
  static const String kPrefLastEntryDay = 'pref.game.last_entry_day';
  static const String kPrefVouchers = 'pref.game.vouchers';
  static const String kPrefBadges = 'pref.game.badges';
  static const String kPrefTotalEntries = 'pref.game.total_entries';
}

/// 成就徽章类别。
enum BadgeCategory {
  persistence('persistence', '坚持'),
  exploration('exploration', '探索'),
  discipline('discipline', '节制'),
  accumulation('accumulation', '积累'),
  goal('goal', '目标');

  const BadgeCategory(this.id, this.label);
  final String id;
  final String label;
}

/// STORY-8.2 家庭共享（基础）。
class MemberRules {
  MemberRules._();

  /// 邀请制人数上限：**只计活跃成员**，已退出成员不占名额（AC1/AC4）。
  static const int maxActiveMembers = 6;

  /// 邀请码长度。
  static const int inviteCodeLength = 6;

  /// 邀请码的本地键（本机账本的邀请码，跨重启保留）。
  static const String kPrefInviteCode = 'pref.family.invite_code';

  /// 默认「我」的显示名。仅作初始值，用户可改。
  static const String defaultMyName = '我';
}

/// STORY-8.1 增量同步。
class SyncRules {
  SyncRules._();

  /// 同账号活跃端的目标延迟（AC1：≤ 10 秒）。
  ///
  /// 实现方式：**写后立即推送**（本地变更触发一次 push）+ **前台每 10 秒轮询**
  /// 拉取其它设备的日志。素记没有服务端推送通道，WebDAV 只能轮询；
  /// 真正的「服务端推给你」需要官方云，届时换传输层即可，合并逻辑不用动。
  static const Duration pollInterval = Duration(seconds: 10);

  /// 每台设备在远端占一个日志文件（按 deviceId 命名，便于 discovery）。
  ///
  /// [generation] > 0 时带上「世代」后缀：**备份还原后必须换世代** ——
  /// 还原会把本机 change_log 换成备份里的旧行，而各端记的位点还在高位，
  /// 于是「被还原掉的变更」永远推不出去。换一个文件名等于告诉对端
  /// 「这台设备的日志是新的」，对端位点归零、全量重放。
  static String logFileNameOf(String deviceId, {int generation = 0}) =>
      generation <= 0 ? 'log_$deviceId.jsonl' : 'log_${deviceId}_g$generation.jsonl';

  /// 从远端文件名里取「设备 + 世代」标识（同时用作位点 key）。
  /// 不是日志文件、或本机自己的文件时返回 null。
  static String? generationKeyOf(String fileName, String myDeviceId) {
    if (!fileName.startsWith('log_') || !fileName.endsWith('.jsonl')) return null;
    final key = fileName.substring(4, fileName.length - '.jsonl'.length);
    if (key.isEmpty) return null;
    if (key == myDeviceId || key.startsWith('${myDeviceId}_')) return null;
    return key;
  }

  /// 单次推送的记录上限（GC 已把 change_log 控制在 5 万行内，这里再兜一层）。
  static const int maxRecordsPerPush = 20000;
}

/// STORY-9.4 AI 识别记账：额度制。
class AiRecognitionRules {
  AiRecognitionRules._();
  /// 每记账月免费额度（次）。
  static const int monthlyQuota = 10;
  /// 额度计数的本地键。
  static const String kPrefMonthKey = 'pref.ai.month_key';
  static const String kPrefMonthCount = 'pref.ai.month_count';
  /// 识别结果预填超时。
  static const Duration parseTimeout = Duration(seconds: 5);
}

/// STORY-9.5 AI 消费周报。
class WeeklyReportRules {
  WeeklyReportRules._();
  /// 推送时间：周日 20:00。
  static const int pushWeekday = DateTime.sunday;
  static const int pushHour = 20;

  /// 「本周」的起点是周一（PRD 未规定周首日，取国内习惯的自然周，全产品唯一口径）。
  static const int weekStartWeekday = DateTime.monday;

  /// 周报系统通知 id（固定值：同 id 覆盖，不轰炸通知中心）。
  static const int notificationId = 2001;

  /// 分类占比变化的**陈述阈值**（百分点）。低于它不写进周报，
  /// 避免把正常波动说成结论。口径由 9.5 的「只陈述」基调决定，非业务数据。
  static const int shareShiftPoints = 10;

  /// 本地键。
  static const String kPrefEnabled = 'pref.weekly_report.enabled';
  static const String kPrefLastPush = 'pref.weekly_report.last_push';
  /// 提醒方式：'ring' 响铃 / 'silent' 静默（AC1「按用户设置」）。
  static const String kPrefLevel = 'pref.weekly_report.level';
}
