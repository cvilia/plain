/// STORY-9.4 AI 识别记账：额度制管理 + 文本解析预填。
/// 计数口径：仅成功识别计入；网络失败/无法识别/用户取消不计入。
/// 额度按记账月（G-1）重置。
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/receipt_parser.dart';

/// 识别入口类型。
enum AiInputType { screenshot, voice, text }

/// 额度状态。
class QuotaStatus {
  const QuotaStatus({required this.used, required this.total, required this.monthKey});
  final int used;
  final int total;
  final String monthKey;

  int get remaining => total - used;
  bool get isExhausted => remaining <= 0;
  String get displayLabel => '$used / $total 次';
}

/// AI 识别服务：额度管理 + 文本解析。
class AiRecognitionService {
  /// 读取当前记账月额度状态。
  /// [monthStartDay] 月起始日（G-1）。
  static Future<QuotaStatus> getQuota({
    required DateTime now,
    required int monthStartDay,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final monthKey = _monthKey(now, monthStartDay);
      final storedKey = sp.getString(AiRecognitionRules.kPrefMonthKey) ?? '';
      if (storedKey != monthKey) {
        // 新记账月，重置计数
        await sp.setString(AiRecognitionRules.kPrefMonthKey, monthKey);
        await sp.setInt(AiRecognitionRules.kPrefMonthCount, 0);
        return QuotaStatus(used: 0, total: AiRecognitionRules.monthlyQuota, monthKey: monthKey);
      }
      final used = sp.getInt(AiRecognitionRules.kPrefMonthCount) ?? 0;
      return QuotaStatus(used: used, total: AiRecognitionRules.monthlyQuota, monthKey: monthKey);
    } catch (_) {
      return QuotaStatus(used: 0, total: AiRecognitionRules.monthlyQuota, monthKey: '');
    }
  }

  /// 消耗 1 次额度（仅在成功识别后调用）。
  static Future<void> consumeQuota({
    required DateTime now,
    required int monthStartDay,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final monthKey = _monthKey(now, monthStartDay);
      if (sp.getString(AiRecognitionRules.kPrefMonthKey) != monthKey) {
        await sp.setString(AiRecognitionRules.kPrefMonthKey, monthKey);
        await sp.setInt(AiRecognitionRules.kPrefMonthCount, 1);
        return;
      }
      final used = sp.getInt(AiRecognitionRules.kPrefMonthCount) ?? 0;
      await sp.setInt(AiRecognitionRules.kPrefMonthCount, used + 1);
    } catch (_) {}
  }

  /// 解析识别文本 → 预填草稿。不消耗额度（调用方决定）。
  static OcrDraft parseInput(AiInputType type, String rawText) {
    return ReceiptParser.parseText(rawText);
  }

  /// 记账月 key（YYYY-MM，按月起始日偏移）。
  static String _monthKey(DateTime now, int monthStartDay) {
    final t = now.toLocal();
    final adjusted = t.day >= monthStartDay
        ? DateTime(t.year, t.month)
        : DateTime(t.year == 1 ? 12 : t.year - 1, t.month == 1 ? 12 : t.month - 1);
    return '${adjusted.year}-${adjusted.month.toString().padLeft(2, '0')}';
  }
}
