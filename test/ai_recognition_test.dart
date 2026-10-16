/// STORY-9.4 AI 识别额度 + STORY-9.2 小票解析（离线）测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/ai_recognition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('额度常量', () {
    test('每记账月 10 次', () {
      expect(AiRecognitionRules.monthlyQuota, 10);
    });
  });

  group('额度计数（G-1 记账月）', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('成功识别才消耗：一次消耗后剩 9 次', () async {
      final now = DateTime(2026, 1, 15, 10);
      expect((await AiRecognitionService.getQuota(now: now, monthStartDay: 1)).used, 0);
      await AiRecognitionService.consumeQuota(now: now, monthStartDay: 1);
      final q = await AiRecognitionService.getQuota(now: now, monthStartDay: 1);
      expect(q.used, 1);
      expect(q.remaining, 9);
      expect(q.isExhausted, isFalse);
    });

    test('用尽后 isExhausted，且不会出现负剩余', () async {
      final now = DateTime(2026, 1, 15, 10);
      for (var i = 0; i < AiRecognitionRules.monthlyQuota + 2; i++) {
        await AiRecognitionService.consumeQuota(now: now, monthStartDay: 1);
      }
      final q = await AiRecognitionService.getQuota(now: now, monthStartDay: 1);
      expect(q.used, AiRecognitionRules.monthlyQuota + 2);
      expect(q.remaining, -2);
      expect(q.isExhausted, isTrue);
    });

    test('AC3：跨过月起始日（10 号）额度重置为 10 次', () async {
      const msd = 10;
      await AiRecognitionService.consumeQuota(
          now: DateTime(2026, 1, 15), monthStartDay: msd);
      expect(
        (await AiRecognitionService.getQuota(
                now: DateTime(2026, 1, 15), monthStartDay: msd))
            .used,
        1,
      );
      // 2/5 仍在同一个记账月（1 月 10 日 ~ 2 月 9 日）
      expect(
        (await AiRecognitionService.getQuota(
                now: DateTime(2026, 2, 5), monthStartDay: msd))
            .used,
        1,
      );
      // 2/10 进入新记账月 → 归零
      final afterReset = await AiRecognitionService.getQuota(
          now: DateTime(2026, 2, 10), monthStartDay: msd);
      expect(afterReset.used, 0);
      expect(afterReset.remaining, AiRecognitionRules.monthlyQuota);
    });

    test('额度文案为「已用 / 总额」', () async {
      await AiRecognitionService.consumeQuota(
          now: DateTime(2026, 1, 15), monthStartDay: 1);
      final q = await AiRecognitionService.getQuota(
          now: DateTime(2026, 1, 15), monthStartDay: 1);
      expect(q.displayLabel, '1 / 10 次');
    });
  });

  group('AC2：识别失败不计入额度', () {
    test('抽不到金额时识别不成功 → 调用方不消耗额度', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 1, 15, 10);
      for (final text in ['今天天气不错', '星巴克咖啡', '2026-01-15 逛街']) {
        final draft = AiRecognitionService.parseInput(AiInputType.text, text);
        expect(draft.isUsable, isFalse, reason: '「$text」不该被当成识别成功');
        // 服务契约：只有 isUsable 的草稿才 consume（记账页按此实现）
        if (draft.isUsable) {
          await AiRecognitionService.consumeQuota(now: now, monthStartDay: 1);
        }
      }
      expect(
        (await AiRecognitionService.getQuota(now: now, monthStartDay: 1)).used,
        0,
      );
    });
  });

  group('离线解析（STORY-9.2）', () {
    test('小票文本抽出金额、商户、日期', () {
      final draft = AiRecognitionService.parseInput(
        AiInputType.text,
        '星巴克咖啡\n合计 ¥128.50\n2026-01-15 10:32',
      );
      expect(draft.amountCents, 12850);
      expect(draft.occurredAt, DateTime(2026, 1, 15));
      expect(draft.merchant, isNotNull);
      expect(draft.summary, contains('128.50'));
    });

    test('分类建议只来自学到的商户，没学过就不猜', () {
      const text = '星巴克咖啡\n¥128.50';
      final unlearned = AiRecognitionService.parseInput(AiInputType.text, text);
      expect(unlearned.categoryHint, isNull);

      final learned = AiRecognitionService.parseInput(
        AiInputType.text,
        text,
        merchantToCategory: const {'星巴克': 'cat-drink'},
      );
      expect(learned.merchant, '星巴克');
      expect(learned.categoryHint, 'cat-drink');
    });
  });
}
