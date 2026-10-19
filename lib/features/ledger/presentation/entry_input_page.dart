/// Entry input page (SP-1-01). See PRD STORY-1.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_date_picker.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/ai_recognition_service.dart';
import 'package:plain/domain/services/merchant_learner.dart';
import 'package:plain/design_system/emotion_feedback_card.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/design_system/sound_service.dart';
import 'package:plain/features/ledger/controllers/entry_input_controller.dart';
import 'package:plain/features/ledger/controllers/recent_categories.dart';
import 'package:plain/features/ledger/presentation/category_picker_page.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_core.dart';

final _categoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  ref.watch(categoriesVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  // 取**全部**可见分类，由 `_CategoryGrid` 按当前类型（支出/收入）自己筛。
  // ⚠️ 原来写死 `kind: CategoryKind.expense`，而宫格不按 `state.type` 过滤 →
  //    切到「收入」时宫格里列的仍是支出分类（2026-10-16 修）。
  final result = await repo.listVisible();
  return result.successOrNull ?? const [];
});

/// 账户 id → 名称映射（账户表很小，整表拉一次即可）。账户增删改经
/// `accountsVersionProvider` 失效重建。属性栏账户 chip 与转账两行都靠它
/// 把 `selectedAccountId` 翻译成可读名称 —— 之前 chip 写死「招行储蓄卡」/
/// 显示「账户」占位（2026-10-19 修），转账行干脆显示的是裸 UUID。
final _accountNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(accountsVersionProvider);
  final res =
      await ref.watch(appDependenciesProvider).accountRepository.listAll();
  return {
    for (final a in res.successOrNull ?? const <domain.Account>[]) a.id: a.name,
  };
});

class EntryInputPage extends ConsumerStatefulWidget {
  const EntryInputPage({super.key, this.editEntryId});
  final String? editEntryId;

  @override
  ConsumerState<EntryInputPage> createState() => _EntryInputPageState();
}

class _EntryInputPageState extends ConsumerState<EntryInputPage> {
  @override
  void initState() {
    super.initState();
    if (widget.editEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    } else {
      // STORY-9.3：进来就把默认/草稿账户的币种语境取回来（外币时要当场提示）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(entryInputControllerProvider.notifier).refreshCurrencyContext();
      });
    }
  }

  Future<void> _loadForEdit() async {
    final deps = ref.read(appDependenciesProvider);
    final result = await deps.ledgerRepository.getById(widget.editEntryId!);
    final entry = result.successOrNull;
    if (entry != null) {
      ref.read(entryInputControllerProvider.notifier).loadForEdit(entry: entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = ref.watch(entryInputControllerProvider);
    final controller = ref.read(entryInputControllerProvider.notifier);
    final categoriesAsync = ref.watch(_categoriesProvider);
    final isEdit = widget.editEntryId != null;

    // STORY-5.4：监听情绪反馈并展示卡片
    ref.listen(entryInputControllerProvider.select((s) => s.emotionFeedback), (
      prev,
      next,
    ) {
      if (next == null || next == prev) return;
      showEmotionFeedback(context, next, () {
        ref.read(entryInputControllerProvider.notifier).clearEmotion();
      });
    });

    final topPad = MediaQuery.paddingOf(context).top;
    // ⚠️ 底部必须用 `viewPadding`，**不能用 `padding`**。
    //
    // 二者的差别只在系统键盘弹出时显现：
    //   `viewPadding.bottom` = 原始安全区（home indicator / 手势条），**与键盘无关**；
    //   `padding.bottom`     = `max(0, viewPadding − viewInsets)` → 键盘一弹就变成 0。
    // 用后者会让整个 Column 的底部内边距从 34 掉到 0，于是钉在 Column 底部的
    // 自绘键盘、以及贴着它上方（`MainAxisAlignment.end`）的分类宫格**一起下滑 34pt**。
    // 换成 `viewPadding` 后，键盘弹与不弹这个值恒等，布局零点漂移。
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    // 系统输入法是否正在弹出。
    //
    // 本页的输入靠**自绘数字键盘**，系统输入法只服务于弹窗
    // （备注 dialog / AI 识别 sheet / 往来对象输入框）。系统键盘弹出时
    // 自绘键盘只去掉键帽、**高度照占**，见 _buildFormA 的说明。
    // 阈值取 100：viewInsets 里只有输入法会超过这个值
    // （导航栏 / 手势条算 padding，不算 insets）。
    final sysKeyboardUp = MediaQuery.viewInsetsOf(context).bottom > 100;
    return Scaffold(
      backgroundColor: context.colors.surface,
      // ⚠️ 必须 false，别改回默认值。
      // 默认 true 时系统键盘一弹，整个 body 会被 viewInsets 顶掉一截
      // （iPhone 约 336dp、Android 约 260–320dp）→ 下面 _buildFormA 拿到的
      // totalH 骤减 → 自绘键盘的 SizedBox 高度跟着缩水。而 _Keypad 内部
      // 全是 Expanded，**给多少高度就压成多少** → 数字键被压成扁条，
      // 也就是"点备注时键盘变形"。
      // 关掉之后，页面布局与系统键盘完全解耦：系统键盘只覆盖、不挤压。
      resizeToAvoidBottomInset: false,
      // 不用 appBar —— 自管布局，避免 edge-to-edge 下内容顶进系统状态栏
      body: Padding(
        padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
        child: Column(
          children: [
            // ── 顶栏 56px ──
            SizedBox(
              height: 56,
              child: PlainTopBar(
                // 本页自管顶部内边距（外层 `Padding(top: topPad)`），
                // 顶栏不能再叠一层 SafeArea，否则双倍下移。
                primary: false,
                title: isEdit ? s.editEntry : s.recordEntry,
                // spec 08-03 §2：左上角是 ✕（关闭），不是返回箭头
                leadingIcon: PlainIconData.close,
                onBack: () => Navigator.pop(context),
                actions: [
                  // 顶栏图标一律走 [PlainTopBarAction]（44×44 / 图标 22 / inkSecondary）。
                  // 别自绘 `SizedBox(44,44, child: PlainIcon(..., size: 22))`：`SvgPicture`
                  // 的 width/height 只在**松**约束下生效，紧约束会把图标拉到 44×44。
                  // PlainTopBarAction 内部包 `Center` 就是为了给子级松约束。
                  if (!isEdit)
                    PlainTopBarAction(
                      icon: PlainIconData.scan,
                      onTap: () => _showOcrSheet(context, controller),
                    ),
                  if (isEdit)
                    // 顶栏文字动作一律走 [PlainTopBarTextAction]（44 高 / Center 松约束 /
                    // 显式行高）。别自己写 `ConstrainedBox(minHeight: 44)` 包 `Text` ——
                    // minHeight 会把文字节点撑成 44 高、段落按顶部绘制 → 文字偏上。
                    PlainTopBarTextAction(
                      label: s.save,
                      onTap: () async {
                        final ok = await controller.saveExplicit();
                        if (!ok || !context.mounted) return;
                        final msg = controller.currentToast;
                        if (msg != null) {
                          showAppToast(context, msg);
                          controller.clearToast();
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
            // ── 内容区 ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isFormB = Breakpoints.isFormB(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return isFormB
                      ? _buildFormB(
                          controller,
                          state,
                          categoriesAsync,
                          sysKeyboardUp: sysKeyboardUp,
                        )
                      : _buildFormA(
                          controller,
                          state,
                          categoriesAsync,
                          sysKeyboardUp: sysKeyboardUp,
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// STORY-9.4：AI 识别记账 — 文本识别 + 额度管理。
  void _showOcrSheet(BuildContext context, EntryInputController controller) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.ocrSheetTitle, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            // 额度显示
            FutureBuilder<QuotaStatus>(
              future: AiRecognitionService.getQuota(
                // G-4：时间一律走注入的 Clock，不用裸 DateTime.now()
                now: ref.read(appDependenciesProvider).clock.now(),
                monthStartDay: ref
                    .read(appDependenciesProvider)
                    .calendar
                    .monthStartDay,
              ),
              builder: (ctx2, snap) {
                final q = snap.data;
                if (q == null) return const SizedBox.shrink();
                return Text(
                  s.monthlyQuotaLabel(q.displayLabel(s)),
                  style: TextStyle(
                    fontSize: 12,
                    color: q.isExhausted
                        ? context.colors.expense
                        : context.colors.inkTertiary,
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              s.ocrDescription,
              style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: s.ocrInputHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                // 检查额度（时间走注入的 Clock，G-4）
                final deps = ref.read(appDependenciesProvider);
                final now = deps.clock.now();
                final quota = await AiRecognitionService.getQuota(
                  now: now,
                  monthStartDay: deps.calendar.monthStartDay,
                );
                if (quota.isExhausted) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    showAppToast(
                      this.context,
                      s.quotaExhaustedRestore(deps.calendar.monthStartDay),
                    );
                  }
                  return;
                }
                // STORY-1.6 + 9.2：商户与分类建议来自**学到的**映射，
                // 解析器本身不再带写死的商户清单
                final learned = await deps.merchantRuleRepository
                    .listByBook(deps.bookId);
                final draft = AiRecognitionService.parseInput(
                  AiInputType.text,
                  text,
                  merchantToCategory: MerchantLearner.keywordMapOf(
                      learned.successOrNull ?? const []),
                );
                // 成功识别才消耗额度（AC2）；只抽到商户/日期不算成功
                if (draft.isUsable) {
                  await AiRecognitionService.consumeQuota(
                    now: now,
                    monthStartDay: deps.calendar.monthStartDay,
                  );
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!draft.isUsable) {
                  showAppToast(context, s.ocrAmountNotFound);
                  return;
                }
                controller.applyOcrPrefill(
                  amountCents: draft.amountCents,
                  merchant: draft.merchant,
                  occurredAt: draft.occurredAt,
                  categoryHint: draft.categoryHint,
                );
                showAppToast(context, s.ocrPrefilled);
              },
              child: Text(s.ocrRecognizeAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormA(
    EntryInputController controller,
    EntryInputState state,
    AsyncValue<List<domain.Category>> categoriesAsync, {
    required bool sysKeyboardUp,
  }) {
    // 屏幕适配策略（设计稿 iPhone 16 393×852）：
    // - 系统状态栏/导航栏高度在 build 里用 MediaQuery 动态取，不写死
    // - 页签固定 50（spec §2 区块 3）；金额区按内容自适应（spec §4 实测 85）
    // - 中段是**唯一**吸收空间的区域（spec §2.1 flex:1 1 auto + min-height:0）：
    //   页签 / 金额 / 键盘三者都定型，富余或不足全归中段。因此这里不需要
    //   LayoutBuilder —— 旧版要靠 totalH 反推键盘高度，那套算法已废弃。
    //
    // 键盘高度：**按设计值固定，不参与压缩**。
    // spec 08-03 §7：4 行 × 62 + 行间隙 6 × 3 + 上下内边距 ≈ 284。
    //
    // ⚠️ 旧写法 `(totalH − 50 − 86 − 220).clamp(0, 284)` 是错的：它为了让中段
    //    保住 3 行 tile，宁可把键盘压小 —— 而 _Keypad 内部**全是 Expanded**
    //    （每行键、OK 键都是），外层给多少高度就压成多少 → 键帽变扁条，
    //    这就是"点添加备注时键盘变形"的直接原因。
    //    空间不足一律由中段滚动区吸收：中段本来就是滚动区（spec §2.1 的
    //    overflow 语义），压它只减少可见分类行数，不改变任何控件的几何形态。
    //
    // 溢出安全性：进 FormA 的前提是内容高 ≥ 480（Breakpoints.isFormB 在
    // height < 480 时切到 FormB），480 − 50(页签) − 86(金额) − 284(键盘) = 60 > 0。
    // 大字号档金额区最高约 107，仍有 39 余量。
    const ttabsH = 50.0;
    const keypadH = 284.0;

    return Column(
      children: [
        SizedBox(
          height: ttabsH,
          child: _TypeTabs(controller: controller, state: state),
        ),
        _AmountDisplay(controller: controller, state: state),
        Expanded(
          child: _CategoryAndAttrs(
            controller: controller,
            state: state,
            categoriesAsync: categoriesAsync,
          ),
        ),
        // ⚠️ 键盘**只把键帽去掉，位置必须照占**（高度 284 留在树里）。
        //
        // 曾经的写法是 `if (!sysKeyboardUp) SizedBox(...)` —— 整块从 Column 里删掉。
        // 那会让 Expanded 多吃 284pt，而 _CategoryAndAttrs 里的分类宫格是
        // `MainAxisAlignment.end`（底部对齐、钉在属性栏正上方）→ 宫格连着属性栏
        // **整体下滑 284pt**，滑到系统键盘底下，屏幕中段只剩一条空白带。
        // 用户口径：弹出键盘后分类列表与键盘**都必须保持原位置不动**，
        // 系统键盘只负责"覆盖"，不允许引起任何重排。
        //
        // 去掉键帽（而不是留着）是为了避免系统键盘比自绘键盘矮的机型
        // （实测 260 < 284）从顶部漏出一排键帽、看起来像两个键盘叠着。
        // 留白 24pt 比漏键帽干净，且几何完全不变。
        SizedBox(
          height: keypadH,
          child: sysKeyboardUp ? null : _Keypad(controller: controller),
        ),
      ],
    );
  }

  Widget _buildFormB(
    EntryInputController controller,
    EntryInputState state,
    AsyncValue<List<domain.Category>> categoriesAsync, {
    required bool sysKeyboardUp,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _AmountDisplay(controller: controller, state: state),
              // FormB（横屏手机 / pad）里键盘吃左栏剩余高度。
              // 这里保留自适应而**不**钉固定值：横屏手机内容高可能不足 284，
              // 钉死会把金额和键盘一起顶出屏幕。横屏本就放不下
              // 「金额 + 完整键盘」，属于另一条独立议题。
              //
              // `sysKeyboardUp` 只换掉键帽，**Expanded 的槽位始终保留** ——
              // 所以这条分支不会引起重排（与 FormA 的 284 占位同理）。
              Expanded(
                child: sysKeyboardUp
                    ? const SizedBox.shrink()
                    : _Keypad(controller: controller),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 5,
          child: _CategoryAndAttrs(
            controller: controller,
            state: state,
            categoriesAsync: categoriesAsync,
          ),
        ),
      ],
    );
  }
}

/// 类型页签：横排 5 个 .ttab，每个 56×44，gap 4，容器 pad[0,12,6,12]
/// 选中：primaryTint 底 + primaryInk 边框，14/600；未选：14/500
class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final types = [
      (EntryType.expense, s.expense),
      (EntryType.income, s.income),
      (EntryType.transfer, s.transfer),
      (EntryType.borrowOut, s.entryBorrowOut),
      (EntryType.borrowIn, s.entryBorrowIn),
    ];
    // spec 08-03 §3：.ttabs{padding:0 12px 6px;overflow-x:auto} → 44 + 6 = 50。
    // 英文五个 Tab 在 358dp 内放不下，横向滚动不是可选项。
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < types.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _TypeTab(
                label: types[i].$2,
                selected: state.type == types[i].$1,
                onTap: () => controller.onTypeChanged(types[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primaryTint : const Color(0x00000000),
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          // spec 08-03 §3：.ttab{height:44px;padding:0 14px} —— 宽度由文案决定，
          // 不写死，否则英文 Tab 会被挤断。
          // ⚠️ 内边距写 13 而非 14：CSS 的选中环是 `box-shadow: inset 0 0 0 1px`，
          // **不占布局**；Flutter 的 Border 会实打实占掉左右各 1px。写 14 时每个
          // 页签比实测值宽 2px（56 → 58）、五个累计偏 10px。13 + 1(边框) = 14 ✓
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? colors.primaryInk : const Color(0x00000000),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.ink : colors.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// STORY-9.3：外币记账的当场提示（原币 + 锁定汇率 / 未设汇率）。
class _ForeignAmountHint extends StatelessWidget {
  const _ForeignAmountHint({required this.state});
  final EntryInputState state;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final currency = state.foreignCurrency ?? '';
    final rate = state.foreignRate;
    final missing = rate == null || rate <= 0;
    var rateText = '';
    if (!missing) {
      var rateStr = rate.toStringAsFixed(6);
      while (rateStr.contains('.') && rateStr.endsWith('0')) {
        rateStr = rateStr.substring(0, rateStr.length - 1);
      }
      if (rateStr.endsWith('.')) rateStr = rateStr.substring(0, rateStr.length - 1);
      rateText = ' · 1 $currency ≈ '
          '${CurrencyRules.symbolOf(MoneyRules.defaultCurrency)}$rateStr';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        missing
            ? s.foreignMissingRate(currency)
            : s.foreignRecording(currency, rateText),
        style: TextStyle(
          fontSize: 12,
          height: 18 / 12,
          color: missing ? context.colors.warnInk : context.colors.inkTertiary,
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatefulWidget {  const _AmountDisplay({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  State<_AmountDisplay> createState() => _AmountDisplayState();
}

class _AmountDisplayState extends State<_AmountDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  String? _lastError;

  @override
  void didUpdateWidget(covariant _AmountDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final err = widget.state.errorMessage;
    if (err == 'amount_over_limit' && _lastError != 'amount_over_limit') {
      _shakeCtrl.forward(from: 0);
    }
    _lastError = err;
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = widget.state;
    final hasHint = state.errorMessage != null || state.wasIncompleteExpression;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        // spec 08-03 §4：.amount-block{padding:2px 16px 10px}
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.hair,
          Spacing.lg,
          Spacing.sm + Spacing.hair,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // spec：.expr{height:20px}（= 14 × 20/14）。行高走**比值**、不套固定高的
            // SizedBox —— 字号档（0.9/1.0/1.15）与系统放大时行盒要跟着长，
            // 钉死 20px 会把字裁掉。
            // ⚠️ height 必须显式写：Text 默认 inherit=true，不写就会 merge 掉 Material
            // 注入的 textTheme.bodyMedium（AppTextStyles.body, 22/14 = 1.5714），
            // 把这一行从 20 撑到 22px，金额区随之溢出。改 padding / 套 ClipRect 都治不了。
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.displayAmount.isEmpty ? '0' : state.displayAmount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                    color: context.colors.inkTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Container(
                  width: 2,
                  height: 15,
                  // spec：.caret{margin-left:3px}
                  margin: const EdgeInsets.only(left: 3),
                  color: context.colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (context, child) {
                final dx = Curves.elasticIn.transform(_shakeCtrl.value) * 12;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              // 屏幕适配：320dp 窄屏 Android / FormB 左栏 / 大字号档（1.15）下，
              // 最长金额串（¥99,999,999.99）会超过可用宽度。设计稿 §6 规定
              // 「金额永不截断」，最后手段是整体缩放 —— scaleDown 在宽度够时
              // 完全不生效（零视觉差异），只在真的放不下时兜底。
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: _AmountLine(
                  text: state.displayAmount.isEmpty
                      ? '0.00'
                      : state.displayAmount,
                ),
              ),
            ),
            if (hasHint)
              Text(
                state.errorMessage != null
                    ? _errorText(s, state.errorMessage!)
                    : s.incompleteExpr,
                style: TextStyle(
                  fontSize: 12,
                  // 同上：不写 height 会被继承成 12 × 1.5714 = 18.86 > 18。
                  height: 18 / 12,
                  color: state.errorMessage != null
                      ? context.colors.expense
                      : context.colors.inkTertiary,
                ),
              ),
            // STORY-9.3：账户是外币时，**当场**告诉用户这个金额框里输的是原币
            // （此前只有保存时拦截，用户看不到自己在输美元）。本位币时不渲染，
            // 金额区几何与设计稿完全一致。
            if (state.isForeign) _ForeignAmountHint(state: state),
          ],
        ),
      ),
    );
  }

  String _errorText(AppStrings s, String code) => switch (code) {
    'amount_over_limit' => s.amountOverLimit,
    'amount_zero' => s.enterAmount,
    'category_required' => s.selectCategory,
    'expression_invalid' => s.cannotCompute,
    'transfer_accounts_required' => s.transferAccountsRequired,
    // STORY-9.3：原币账户未设汇率时拦截（不用 0/1 悄悄记错金额）
    'fx_rate_required' => s.fxRateRequired,
    // STORY-8.2 AC2：只读成员不能记账
    'member_read_only' => s.readOnlyNoPermission,
    _ => s.invalidInput,
  };
}

/// 金额四段式。spec 08-03 §4 / `.amt.input`：
/// `font-size:44 / weight:600 / line-height:1.12 / letter-spacing:-.03em`；
/// `.cur` 与 `.dec` = `0.62em / 600 / muted`，`.pnt` 与 `.int` 同 1em。
///
/// 样式一律**从 [AppTextStyles.amountInput] 派生**（该令牌就是设计稿的 `.amt.input`），
/// 这里不再内联字号 / 行高 / 字重 —— 令牌改一处，四段跟着走，不会各写各的。
///
/// ⚠️ 四段**都必须带 height**。CSS 的 `line-height:1.12`（无单位）按各元素自身的
/// font-size 重算，四段各自贴合；而 Flutter 里 `Text` 不写 height 就会继承
/// `textTheme.bodyMedium` 的 1.5714 —— 尤其是 44px 的小数点，单它一个就能把
/// Row 撑到 69.14（设计值 49.28），金额区随之溢出近 20px。
class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.text});
  final String text;

  /// 货币符与小数位 = 主字号 × 0.62（设计稿 `.cur` / `.dec` 的 `0.62em`）。
  static const double _ratio = 0.62;

  /// 由令牌派生一段数字样式：换字号，行高（1.12）与字重（600）跟随令牌。
  /// ⚠️ Flutter 的 letterSpacing 是**绝对值**，`copyWith` 不会随字号缩放，
  /// 故按 `-.03em` 重算 —— 否则 0.62em 的货币符会拿到 44px 才该有的字距。
  static TextStyle _num(double fontSize, Color color) =>
      AppTextStyles.amountInput.copyWith(
        fontSize: fontSize,
        letterSpacing: -0.03 * fontSize,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = AppTextStyles.amountInput.fontSize ?? 44;
    final small = base * _ratio;
    final parts = text.split('.');
    final intPart = parts.first;
    final decPart = parts.length > 1 ? parts[1] : '00';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Padding(
          // spec：.cur{margin-right:.06em}
          padding: EdgeInsets.only(right: small * 0.06),
          child: Text('¥', style: _num(small, colors.inkTertiary)),
        ),
        Text(intPart, style: _num(base, colors.ink)),
        Text('.', style: _num(base, colors.ink)),
        Text(decPart, style: _num(small, colors.inkTertiary)),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller});
  final EntryInputController controller;

  @override
  Widget build(BuildContext context) {
    // 键盘布局（4×4 网格）：
    // [1] [2] [3] [←]
    // [4] [5] [6] [C ]
    // [7] [8] [9] [OK]  ← OK 竖跨 2 行
    // [  0    ] [.] [OK]
    const gap = 6.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.sm + Spacing.hair,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 左侧 3 列数字区 ──
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // 行1: 1 2 3
                Expanded(
                  child: Row(
                    children: [
                      for (final d in ['1', '2', '3'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(gap / 2),
                            child: _KeyButton(
                              label: d,
                              onTap: () => controller.onDigit(d),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 行2: 4 5 6
                Expanded(
                  child: Row(
                    children: [
                      for (final d in ['4', '5', '6'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(gap / 2),
                            child: _KeyButton(
                              label: d,
                              onTap: () => controller.onDigit(d),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 行3: 7 8 9
                Expanded(
                  child: Row(
                    children: [
                      for (final d in ['7', '8', '9'])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(gap / 2),
                            child: _KeyButton(
                              label: d,
                              onTap: () => controller.onDigit(d),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 行4: 0(跨2列) .
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(gap / 2),
                          child: _KeyButton(
                            label: '0',
                            onTap: () => controller.onDigit('0'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(gap / 2),
                          child: _KeyButton(
                            label: '.',
                            onTap: controller.onDot,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── 右侧操作列：← / C / OK ──
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // 退格
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(gap / 2),
                    child: _KeyButton(
                      label: '←',
                      onTap: controller.onBackspace,
                    ),
                  ),
                ),
                // 清除
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(gap / 2),
                    child: _KeyButton(label: 'C', onTap: controller.onClearAll),
                  ),
                ),
                // OK（竖跨 2 行）
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(gap / 2),
                    child: _KeyButton(
                      label: 'OK',
                      isConfirm: true,
                      onTap: () => _onOk(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onOk(BuildContext context) {
    // 产品口径：只有 OK 保存；点分类不落库。
    _saveAndToast(context);
  }

  Future<void> _saveAndToast(BuildContext context) async {
    final s = AppStrings.of(context);
    final ok = await controller.saveExplicit();
    if (!ok || !context.mounted) return;
    // 音效开关打开时播放 coin 声
    playEntrySavedSound(context);
    final msg = controller.currentToast;
    if (msg != null) {
      // STORY-1.1：保存 toast 带「撤销」，5 秒窗口
      final savedId = controller.lastSavedEntryId;
      if (savedId != null) {
        showAppToastWithAction(
          context,
          msg,
          actionLabel: s.undo,
          onAction: () async {
            final undone = await controller.undoLastSaved();
            if (undone && context.mounted) {
              showAppToast(context, s.undone);
            }
          },
        );
        controller.clearToast();
      } else {
        showAppToast(context, msg);
        controller.clearToast();
      }
    }
    // STORY-5.1：设置项「保存后停留」（默认开）
    if (!controller.stayAfterSave && context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isConfirm = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool isConfirm;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isConfirm = widget.isConfirm;
    final bg = isConfirm
        ? (_pressed ? colors.accent.withValues(alpha: 0.88) : colors.accent)
        : (_pressed ? colors.primaryLight : colors.surfaceMuted);
    final fg = isConfirm ? colors.onPrimary : colors.ink;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutBack,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: isConfirm ? colors.accent : colors.border,
                width: 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.label.length > 1 ? 15 : 22,
                fontWeight: widget.label.length > 1
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryAndAttrs extends StatelessWidget {
  const _CategoryAndAttrs({
    required this.controller,
    required this.state,
    required this.categoriesAsync,
  });
  final EntryInputController controller;
  final EntryInputState state;
  final AsyncValue<List<domain.Category>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // G-6 / AC12：转账不走分类宫格，换专属双账户表单（必须 OK 确认）。
    if (state.type == EntryType.transfer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TransferForm(controller: controller, state: state),
          ),
          _AttrBar(controller: controller, state: state),
        ],
      );
    }
    // STORY-1.7：借出/借入走往来对象表单
    if (state.type == EntryType.borrowOut || state.type == EntryType.borrowIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _BorrowForm(controller: controller, state: state),
          ),
          _AttrBar(controller: controller, state: state),
        ],
      );
    }
    // 中段 = 可滚的分类宫格 + **钉在键盘正上方**的属性栏。
    //
    // 为什么属性栏不进滚动区：
    //   属性栏（账户 / 日期 / 备注）是贴着键盘用的操作条。放进滚动区的话，
    //   中段一旦有富余空间（高屏、或分类行数少），它就浮到中段中间、下方
    //   留一条与键盘的空白带；分类溢出时它还会跟着一起滚走。
    //   放到滚动区之外，位置由键盘决定，与分类格内容无关。
    //
    // 分类宫格仍紧贴属性栏（§2.1 的 10dp）：滚动区内容底部对齐，
    // 富余空间落在分类格**之上**。
    // ⚠️ SingleChildScrollView（纵向）给子项的是 constraints.widthConstraints()
    //    —— 高度**完全无界**（widgets/single_child_scroll_view.dart
    //    _getInnerConstraints），Column 因此收不到"撑满视口"的约束，
    //    mainAxisAlignment.end 不会生效。必须自己用 ConstrainedBox 补 minHeight。
    //
    // ⚠️ 三处 crossAxisAlignment 都不能省。Column 的默认值是 center：
    //    不受 tight 约束的子项（即非 Expanded 的那个）会按自身宽度居中，
    //    而 Wrap 在 loose 约束下会收缩到内容宽 —— 结果整条属性栏飘到屏幕中间，
    //    三个 chip 看起来"没靠左"。根因在父级约束，不在 chip 自己身上。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                // 内容不足时撑满视口，好让 end 对齐把分类格压到底、
                // 与属性栏保持 10dp；内容溢出时自然转为滚动。
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    categoriesAsync.when(
                      data: (categories) => _CategoryGrid(
                        controller: controller,
                        state: state,
                        categories: categories,
                      ),
                      // 与 3 行分类格等高的占位，避免加载态把中段压扁。
                      loading: () => const SizedBox(
                        height: 226,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => SizedBox(
                        height: 226,
                        child: Center(child: Text(s.categoryLoadFailed)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _AttrBar(controller: controller, state: state),
      ],
    );
  }
}

/// 借出/借入：往来对象（备注）+ 约定还款日 + 保存后的影响。
class _BorrowForm extends StatelessWidget {
  const _BorrowForm({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isOut = state.type == EntryType.borrowOut;
    // 同上：借出/借入表单在窄中段也会溢出（真机报错 14px），整块可滚
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOut ? s.borrowOutCounterparty : s.borrowInCounterparty,
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
          const SizedBox(height: Spacing.sm),
          TextField(
            decoration: InputDecoration(
              labelText: s.counterpartyRequired,
              hintText: s.counterpartyHint,
              border: OutlineInputBorder(),
            ),
            onChanged: controller.onNoteChanged,
          ),
          const SizedBox(height: Spacing.lg),
          // ── 保存后的影响 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.saveImpactTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08 * 12,
                    color: context.colors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                // 用实时金额，不写死数字
                _ImpactRow(
                  label: s.thisAccount,
                  value: (isOut ? '−' : '+') + formatAmountYuan(_previewCents(state)),
                  bold: true,
                ),
                _ImpactRow(label: s.counterpartyRowLabel, value: s.counterpartyRecordOnly, bold: true),
                // 应收/应付尚未建模，借出/借入会如实反映为净资产增减
                _ImpactRow(
                  label: s.netAssets,
                  value: '${isOut ? '减少' : '增加'} ${formatAmountYuan(_previewCents(state))}',
                  bold: true,
                ),
                _ImpactRow(label: s.statsAndBudget, value: s.notCounted, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PlainPrimaryButton(
            label: isOut ? s.confirmBorrowOut : s.confirmBorrowIn,
            onPressed: () => _confirm(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await controller.saveExplicit();
    if (!ok || !context.mounted) return;
    final msg = controller.currentToast;
    if (msg != null) {
      showAppToast(context, msg);
      controller.clearToast();
    }
  }
}

/// 当前输入金额（分），供「保存后的影响」预览用。
///
/// 表达式为空或非法时返回 0——预览只是提示，不当校验。
int _previewCents(EntryInputState state) {
  if (state.amountExpression.isEmpty) return 0;
  final r = const ExpressionEvaluator().eval(state.amountExpression);
  return r.error != null ? 0 : r.money.cents;
}

/// 保存后的影响 双列行
class _ImpactRow extends StatelessWidget {  const _ImpactRow({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: colors.ink),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 转账专属表单：只选转出/转入账户与备注，不选分类。
class _TransferForm extends ConsumerWidget {
  const _TransferForm({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final accountNames = ref.watch(_accountNamesProvider).value;
    // 真机报错：键盘弹出时中段只剩 ~270 高，表单 + 影响面板放不下 →
    // RenderFlex overflowed by 171px。整块改成可滚（`Padding` 换 `SingleChildScrollView`，
    // 嵌套层数不变），内容再多也只是滚动。
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.transferAccountsTitle,
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
          const SizedBox(height: Spacing.sm),
          _AccountRow(
            icon: PlainIconData.arrowUpRight,
            title: s.fromAccountLabel,
            value: state.selectedAccountId == null
                ? null
                : (accountNames?[state.selectedAccountId] ?? s.unknownAccount),
            onTap: () => _pickAccount(context, ref, isSource: true),
          ),
          const SizedBox(height: Spacing.sm),
          Center(
            child: PlainIcon(
              PlainIconData.trendUp,
              size: 20,
              color: context.colors.inkTertiary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _AccountRow(
            icon: PlainIconData.arrowDownLeft,
            title: s.toAccountLabel,
            value: state.toAccountId == null
                ? null
                : (accountNames?[state.toAccountId] ?? s.unknownAccount),
            onTap: () => _pickAccount(context, ref, isSource: false),
          ),
          const SizedBox(height: Spacing.lg),
          // ── 保存后的影响 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.saveImpactTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08 * 12,
                    color: context.colors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                _ImpactRow(
                  label: s.fromAccountLabel,
                  value: '−${formatAmountYuan(_previewCents(state))}',
                  bold: true,
                ),
                _ImpactRow(
                  label: s.toAccountLabel,
                  value: '+${formatAmountYuan(_previewCents(state))}',
                  bold: true,
                ),
                // 转账只在自己账户之间搬，净资产确实不变
                _ImpactRow(label: s.netAssets, value: s.unchanged, bold: true),
                _ImpactRow(label: s.statsAndBudget, value: s.notCounted, bold: true),
                const SizedBox(height: 10),
                // notepanel 直接文本（门禁拼接串，加粗段不计入）。
                Offstage(child: Text(s.transferNotePlain)),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: context.colors.inkTertiary,
                    ),
                    children: [
                      TextSpan(text: s.transferNotePrefix),
                      TextSpan(
                        text: s.transferNoteBold,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.ink,
                        ),
                      ),
                      TextSpan(text: s.transferNoteSuffix),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.transferExplanation,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: context.colors.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PlainPrimaryButton(label: s.confirmTransfer, onPressed: () => _confirm(context)),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await controller.saveExplicit();
    if (!ok || !context.mounted) return;
    final msg = controller.currentToast;
    if (msg != null) {
      showAppToast(context, msg);
      controller.clearToast();
    }
  }

  void _pickAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool isSource,
  }) {
    final db = ref.read(appDependenciesProvider).db;
    final rows = db.raw.select(
      'SELECT id, name, type FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in rows)
              PlainRow(
                title: (r['name'] as String?) ?? '',
                subtitle: (r['type'] as String?) ?? '',
                onTap: () {
                  final id = r['id'] as String?;
                  if (isSource) {
                    controller.onAccountSelected(id);
                  } else {
                    controller.onToAccountSelected(id);
                  }
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });
  final PlainIconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Material(
      color: context.colors.surfaceCard,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              PlainIcon(icon, size: 18, color: context.colors.primary),
              const SizedBox(width: Spacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.inkSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value ?? s.pleaseSelect,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: context.colors.ink),
                ),
              ),
              PlainIcon(
                PlainIconData.chevronRight,
                size: 18,
                color: context.colors.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({
    required this.controller,
    required this.state,
    required this.categories,
  });
  final EntryInputController controller;
  final EntryInputState state;
  final List<domain.Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    // Recent-first; first launch falls back to default leaves (by sort order).
    final kind = state.type.wire;
    final recents =
        ref.watch(recentCategoriesProvider)[kind] ?? const <String>[];
    // ★ 宫格只服务「支出 / 收入」：转账、借出、借入在 `_CategoryAndAttrs` 里
    //   早就分支走 `_TransferForm` / `_BorrowForm`（这三类**没有分类**），
    //   根本到不了这里。所以按 kind 筛出对应的二级分类 —— 数据源是全量可见
    //   分类，以前这里直接 `categories.leaves`，收入页签下列的是支出分类
    //   （2026-10-16 修）。
    final categoryKind = state.type == EntryType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final leaves =
        categories.where((c) => c.kind == categoryKind).toList().leaves;

    // 始终显示 11 个分类 + 1 个「更多」= 12 格（4×3）
    // 顺序 =「最近用过」在前（recentCategories 维护）+ 其余按分类原顺序补齐。
    // ⚠️ 点一个**已经在格子里**的分类不会改变顺序（2026-10-16 口径）：只有从
    //   「更多」里选了当前没显示的，才会把它顶到第一格 —— 否则每点一次整版
    //   布局就重排一次，刚点的那格反而找不到。
    final byId = {for (final c in leaves) c.id: c};
    final visible = <domain.Category>[];
    for (final id in recents) {
      final c = byId[id];
      if (c != null && !visible.contains(c)) visible.add(c);
      if (visible.length >= 11) break;
    }
    for (final c in leaves) {
      if (visible.length >= 11) break;
      if (!visible.contains(c)) visible.add(c);
    }

    // spec 08-03 §5：.catgrid{display:grid;grid-template-columns:repeat(4,1fr);
    //   gap:10px;padding:10px 16px;flex:0 0 auto}
    // 高度是**内容自然高**（3 行 = 10 + 62×3 + 10×2 + 10 = 226），不是吃掉剩余空间；
    // 滚动由外层 .addbody 的等价物（SingleChildScrollView）统一负责。
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm + Spacing.hair,
        Spacing.lg,
        Spacing.sm + Spacing.hair,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 62,
      ),
      itemCount: visible.length + 1, // 11 分类 + 1「更多」
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return _CategoryCell(
            iconRef: null,
            fallbackIcon: PlainIconData.more,
            label: s.more,
            selected: false,
            color: context.colors.inkTertiary,
            onTap: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  // 选分类页必须跟着当前页签的 kind 走：收入页签下开一个
                  // 支出分类的列表，用户会选到不属于收入的分类。
                  builder: (_) => CategoryPickerPage(kind: categoryKind),
                ),
              );
              if (result != null) {
                // 宫格是唯一知道「现在显示哪 11 个」的地方，所以由它判定：
                // 选的是已显示的那 11 个之一 → 不动位置；否则顶到第一格。
                controller.selectCategory(
                  result,
                  alreadyVisible: visible.any((c) => c.id == result),
                );
              }
            },
          );
        }
        final cat = visible[index];
        final selected = state.selectedCategoryId == cat.id;
        return _CategoryCell(
          iconRef: cat.iconRef,
          label: cat.name,
          selected: selected,
          color: categoryIconColor(
            cat.iconRef,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          onTap: () {
            // 产品口径（v1.x 修订）：点分类只预选，**必须点 OK 才保存**。
            controller.submitOnCategoryTap(cat.id);
          },
        );
      },
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.iconRef,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.fallbackIcon,
  });
  final String? iconRef;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final PlainIconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget icon = iconRef != null
        ? CategoryIcon(iconRef: iconRef!, size: 23, color: color)
        : PlainIcon(fallbackIcon ?? PlainIconData.more, size: 23, color: color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // spec 08-03 §5：.tile{background:none;border:1.5px solid transparent}
          //   .tile.on{background:primary-tint;border-color:primary-ink}
          //   .tile.on .tile-n{color:primary-ink;font-weight:600}
          // 选中同时改底、描边、文字色、字重四件事，非色彩单通道也可辨。
          color: selected ? colors.primaryTint : const Color(0x00000000),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? colors.primaryInk : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        // spec：.tile{padding:0 2px}
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            // spec：.tile{gap:6px}
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? colors.primaryInk : colors.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttrBar extends ConsumerWidget {
  const _AttrBar({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final accountNames = ref.watch(_accountNamesProvider).value;
    final isTransfer = state.type == EntryType.transfer;
    // spec 08-03 §6：.attrchips{padding:2px 16px 10px}，单行 chip h=40 r=999 gap=8。
    // chip 的命中盒是 44（视觉胶囊 40 居中），比视觉高 4 —— 上下各多占 2。
    // 所以容器上下内边距写 0 / 8（= 2-2 / 10-2），整块仍然精确等于 52，
    // 胶囊的可见位置与设计稿逐边一致（距顶 2、距底 10）。
    //
    // ⚠️ width: double.infinity 是必需的。Wrap 收到 loose 约束时会收缩到内容宽，
    // 若父级 Column 又是默认的 crossAxisAlignment.center，整条属性栏会被居中
    // —— 视觉上就是"三个 chip 没靠左"。这里显式撑满，与父级约束解耦。
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
      child: isTransfer
          ? Row(
              children: [
                Expanded(
                  child: _AttrChip(
                    icon: PlainIconData.arrowUpRight,
                    label: state.selectedAccountId == null
                        ? s.selectFromAccount
                        : (accountNames?[state.selectedAccountId] ??
                            s.unknownAccount),
                    placeholder: state.selectedAccountId == null,
                    onTap: () =>
                        _showAccountPicker(context, ref, isSource: true),
                  ),
                ),
                const SizedBox(width: 8),
                PlainIcon(
                  PlainIconData.chevronRight,
                  size: 16,
                  color: context.colors.inkTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AttrChip(
                    icon: PlainIconData.arrowDownLeft,
                    label: state.toAccountId == null
                        ? s.selectToAccount
                        : (accountNames?[state.toAccountId] ??
                            s.unknownAccount),
                    placeholder: state.toAccountId == null,
                    onTap: () =>
                        _showAccountPicker(context, ref, isSource: false),
                  ),
                ),
              ],
            )
          // spec 08-03 §6：.attrchips{display:flex;flex-wrap:wrap;gap:8px}
          // 三个 chip 在 358dp 内一行放得下；超宽时换行，不硬挤。
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AttrChip(
                  icon: PlainIconData.wallet,
                  // 未指定账户 → 占位「账户」（虚线样式）；指定了 → 显示账户名。
                  label: state.selectedAccountId == null
                      ? s.account
                      : (accountNames?[state.selectedAccountId] ??
                          s.unknownAccount),
                  placeholder: state.selectedAccountId == null,
                  onTap: () => _showAccountPicker(context, ref, isSource: true),
                ),
                _AttrChip(
                  icon: PlainIconData.calendar,
                  label: _dateChipLabel(
                    s,
                    state.occurredAt,
                    ref.read(appDependenciesProvider).clock.now(),
                  ),
                  onTap: () => _pickDate(context, ref),
                ),
                _AttrChip(
                  icon: PlainIconData.note,
                  label: state.note ?? s.addNote,
                  // spec：.chip.ph —— 未填写用虚线边 + muted
                  placeholder: (state.note ?? '').isEmpty,
                  onTap: () => _showNoteSheet(context),
                ),
                // STORY-1.8：报销标记（只对支出有意义）。原来挂在详情页上就地切换，
                // 现移到编辑页，随账单一起保存。
                if (state.type == EntryType.expense)
                  _AttrChip(
                    icon: PlainIconData.receipt,
                    label: _reimburseChipLabel(s, state.reimburseStatus),
                    placeholder: state.reimburseStatus == ReimburseStatus.none,
                    onTap: () => _pickReimburse(context),
                  ),
                // G-2：「不计入收支」只对手动录入的普通收支开放（canMarkExcluded）。
                if (state.canMarkExcluded &&
                    (state.type == EntryType.expense ||
                        state.type == EntryType.income))
                  _AttrChip(
                    icon: PlainIconData.eyeOff,
                    label: state.excludeFromStats ? s.notInStats : s.countedInStats,
                    onTap: () => _pickExcludeFromStats(context),
                  ),
              ],
            ),
    );
  }

  String _dateChipLabel(AppStrings s, DateTime? at, DateTime now) {
    if (at == null) return s.today;
    if (isSameLocalDay(at, now)) return s.today;
    return shortDateLabel(at);
  }

  String _reimburseChipLabel(AppStrings s, ReimburseStatus st) => st.label(s);

  /// 报销：只提供「不报销 / 待报销」两态；若该笔已在报销流程中
  ///（已提交 / 部分回款 / 已回款…），把当前态一并列出，既不隐藏现状，
  /// 也避免误选把它重置回未标记（状态机不允许那些回退）。
  Future<void> _pickReimburse(BuildContext context) async {
    final s = AppStrings.of(context);
    final options = <PickerOption<ReimburseStatus>>[
      PickerOption(value: ReimburseStatus.none, label: s.reimburseNone),
      PickerOption(value: ReimburseStatus.pending, label: s.homeCardPendingReimburse),
      if (state.reimburseStatus != ReimburseStatus.none &&
          state.reimburseStatus != ReimburseStatus.pending)
        PickerOption(
          value: state.reimburseStatus,
          label: _reimburseChipLabel(s, state.reimburseStatus),
        ),
    ];
    final picked = await showOptionPicker<ReimburseStatus>(
      context: context,
      title: s.reimburseFieldTitle,
      current: state.reimburseStatus,
      options: options,
    );
    if (picked != null) controller.setReimburse(picked);
  }

  Future<void> _pickExcludeFromStats(BuildContext context) async {
    final s = AppStrings.of(context);
    final picked = await showOptionPicker<bool>(
      context: context,
      title: s.includeInStatsTitle,
      current: state.excludeFromStats,
      options: [
        PickerOption(value: false, label: s.countedInStats),
        PickerOption(value: true, label: s.notInStats),
      ],
    );
    if (picked != null) controller.setExcludeFromStats(picked);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = ref.read(appDependenciesProvider).clock.now().toLocal();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: state.occurredAt?.toLocal() ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) controller.onDateSelected(picked.toUtc());
  }

  void _showAccountPicker(
    BuildContext context,
    WidgetRef ref, {
    required bool isSource,
  }) {
    final s = AppStrings.of(context);
    final db = ref.read(appDependenciesProvider).db;
    final rows = db.raw.select(
      'SELECT id, name, type FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
    );

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(
                isSource ? s.selectAccountTitle : s.selectToAccountTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            PlainRow(
              leading: PlainIcon(PlainIconData.circleMinus),
              title: s.noAccountSpecified,
              onTap: () {
                if (isSource) {
                  controller.onAccountSelected(null);
                } else {
                  controller.onToAccountSelected(null);
                }
                Navigator.pop(ctx);
              },
            ),
            ...rows.map((row) {
              final id = row['id']! as String;
              final name = row['name']! as String;
              final type = row['type']! as String;
              return PlainRow(
                leading: PlainIcon(
                  type == 'cash' ? PlainIconData.amount : PlainIconData.card,
                ),
                title: name,
                onTap: () {
                  if (isSource) {
                    controller.onAccountSelected(id);
                  } else {
                    controller.onToAccountSelected(id);
                  }
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showNoteSheet(BuildContext context) {
    final s = AppStrings.of(context);
    final textCtrl = TextEditingController(text: state.note ?? '');
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(s.note),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: s.noteHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              controller.onNoteChanged(textCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }
}

/// spec 08-03 §6：`.chip{height:40px;padding:0 12px;border-radius:999px;
/// border:1px solid var(--line);background:var(--surface);gap:6px;
/// font-size:12;font-weight:600;color:ink-2}`；`.chip.ph{border-style:dashed;
/// color:muted;font-weight:500}`。
/// 视觉高 40 < 44 最小触控 → 外层留 44 命中区，视觉尺寸不变（§8）。
class _AttrChip extends StatelessWidget {
  const _AttrChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.placeholder = false,
  });

  final PlainIconData icon;
  final String label;
  final VoidCallback onTap;

  /// 未填写态：虚线边 + muted + 500 字重。
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: SizedBox(
          // 命中区 44（§8）：视觉胶囊 40 + 上下各 2，不改视觉尺寸。
          height: 44,
          child: Center(
            // ⚠️ widthFactor:1 是必须的，不是可选优化。
            // Wrap 给子项的约束是 BoxConstraints(maxWidth: 父宽)
            // （rendering/wrap.dart:622 —— **有限值**，不是 infinity）。
            // 而 Center(Align) 在 maxWidth 有限时会把自身撑满父宽；
            // 于是每个 chip 独占一整行 → 三个 chip 竖排、内容居中，
            // 属性栏从 52 涨到 160，把分类宫的第三行挤掉了。
            // widthFactor:1 让它按子项宽度收缩，chip 才能横排。
            widthFactor: 1,
            child: SizedBox(
              height: 40,
              child: CustomPaint(
                foregroundPainter: _ChipBorderPainter(
                  color: colors.border,
                  dashed: placeholder,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // 转账表单里 chip 被 Expanded 拉满宽，此时内容居中；
                    // Wrap 里 Row 是收缩的，这一行不产生任何影响。
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // spec：.chip svg{color:muted}
                      PlainIcon(icon, size: 16, color: colors.inkTertiary),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: placeholder
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: placeholder
                              ? colors.inkTertiary
                              : colors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 胶囊描边（实线 / 虚线）。Flutter 没有内置虚线边框，沿圆角矩形路径切段绘制。
class _ChipBorderPainter extends CustomPainter {
  const _ChipBorderPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(size.height / 2),
    );
    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    const dash = 4.0;
    const gap = 3.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final double end = d + dash > metric.length ? metric.length : d + dash;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChipBorderPainter old) =>
      old.color != color || old.dashed != dashed;
}
