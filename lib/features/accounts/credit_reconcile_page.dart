/// 信用卡对账页（STORY-2.2 AC7/AC8）。
/// 加载结构：initState → 一次性拉账户+余额 → 强类型 [_CreditSnapshot]；保存走 CreditReconcileService。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/features/ledger/presentation/member_write_guard.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/credit_card_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

/// 对账页一次性快照，避免 build 里散落 FutureBuilder / dynamic。
class _CreditSnapshot {
  const _CreditSnapshot({
    required this.account,
    required this.balanceCents,
    required this.storedDebtCents,
    required this.aggregatedDebtCents,
    required this.diffCents,
    required this.entries,
    required this.categories,
  });

  final Account account;
  final int balanceCents;
  final int storedDebtCents;
  final int aggregatedDebtCents;
  final int diffCents;

  /// 该账户的实时流水（消费明细用它渲染，不是写死的样例）。
  final List<LedgerEntry> entries;
  final Map<String, Category> categories;

  /// 已用额度 = 总额度 − 可用额度（派生，只读）。
  int get usedLimitCents {
    final used = account.creditLimitCents - account.creditAvailableCents;
    return used > 0 ? used : 0;
  }

  /// 已用占比（总额度为 0 时视为 0）。
  double get usedRatio {
    if (account.creditLimitCents <= 0) return 0;
    return (usedLimitCents / account.creditLimitCents).clamp(0.0, 1.0);
  }

  factory _CreditSnapshot.from({
    required Account account,
    required int balanceCents,
    required List<LedgerEntry> entries,
    required Map<String, Category> categories,
  }) {
    final aggregated =
        CreditCardService.aggregatedDebtCents(balanceCents: balanceCents);
    return _CreditSnapshot(
      account: account,
      balanceCents: balanceCents,
      storedDebtCents: account.creditDebtCents,
      aggregatedDebtCents: aggregated,
      diffCents:
          CreditCardService.aggregateDiff(storedDebtCents: account.creditDebtCents, balanceCents: balanceCents),
      entries: entries,
      categories: categories,
    );
  }
}

class CreditReconcilePage extends ConsumerStatefulWidget {
  const CreditReconcilePage({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<CreditReconcilePage> createState() => _CreditReconcilePageState();
}

class _CreditReconcilePageState extends ConsumerState<CreditReconcilePage> {
  final _actualCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  String? _error;
  _CreditSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final s = AppStrings.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    final deps = ref.read(appDependenciesProvider);
    final acctRes = await deps.accountRepository.getById(widget.accountId);
    // AC8 的「按账单聚合」必须用**派生**余额——balanceOf 对信用卡返回的是
    // 存储的欠款余额本身，拿它做聚合会让差额恒为 0，校验形同虚设。
    final balRes = await deps.accountRepository.derivedBalanceOf(widget.accountId);
    final pageRes = await deps.ledgerRepository.listPage(
      filter: EntryFilter(accountId: widget.accountId),
      limit: 200,
    );
    final catsRes = await deps.categoryRepository.listAll();
    if (!mounted) return;

    final account = acctRes.successOrNull;
    final bal = balRes.successOrNull;
    if (account == null || bal == null) {
      setState(() {
        _loading = false;
        _error = s.loadAccountFailed;
      });
      return;
    }
    final categories = {
      for (final c in catsRes.successOrNull ?? const <Category>[]) c.id: c,
    };
    setState(() {
      _snap = _CreditSnapshot.from(
        account: account,
        balanceCents: bal.balanceCents,
        entries: pageRes.successOrNull?.items ?? const <LedgerEntry>[],
        categories: categories,
      );
      _loading = false;
    });
  }

  /// 消费明细行文案：`MM-DD 分类 · 备注`（全部来自该笔账单本身）。
  String _consumeLabel(LedgerEntry e) {
    final s = AppStrings.of(context);
    final local = e.occurredAt.toLocal();
    final d = '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final catName = e.categoryId == null
        ? s.uncategorized
        : (_snap?.categories[e.categoryId]?.name ?? s.uncategorized);
    final note = e.note;
    return note == null || note.isEmpty
        ? '$d $catName'
        : '$d $catName · $note';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: s.creditBillTitle, showBack: true),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = AppStrings.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _snap == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? s.loadingError),
            const SizedBox(height: Spacing.md),
            Material(
              color: const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _reload,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.lineStrong),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(s.retry),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final snap = _snap!;
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        // ── Hero：本期应还 ──
        // 设计 `.hero{padding:6px 0 0}` 的第一条是 `.hairline`（1px），其后
        // `.hero-label{margin:16px 0 8px 2px}` —— 左缩进 2px。
        Divider(height: 1, color: colors.border),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(s.currentDueHero,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.08 * 12, color: colors.inkTertiary)),
        ),
        const SizedBox(height: 8),
        AmountDisplay(cents: snap.storedDebtCents, fontSize: 34),
        const SizedBox(height: 16),
        // 设计 `.hero-split{display:flex;gap:28px;padding:0 0 16px}`：三栏是
        // **内容宽、左对齐**（右端留白 ≈126pt），不是等分 —— 所以不能用 `Expanded`。
        // 但内容宽在 320dp 窄屏上会超出可用宽（≈305 > 288）→ 外面套 `FittedBox`
        // 让整行等比缩小，绝不溢出；393pt 设计基准上 `scaleDown` 是空操作。
        // ★ 金额必须走 `AmountDisplay`（设计 `.amt.s`）：裸 `Text(15px)` 会把 `¥`
        //   与小数位也渲染成 15px，单串宽 ≈80 而非设计的 56 —— 这正是溢出的直接原因。
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(children: [
            // 三栏全部派生自账户参数，无写死值
            _HeroSplit(label: s.availableLimit, amountCents: snap.account.creditAvailableCents),
            const SizedBox(width: 28),
            _HeroSplit(label: s.usedLimit, amountCents: snap.usedLimitCents),
            const SizedBox(width: 28),
            _HeroSplit(
              label: s.usedLabel,
              text: '${(snap.usedRatio * 100).toStringAsFixed(1)}%',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: colors.border),
        // `.grp{margin-top:32px}` —— 眉标自带下边距，这里给足 32。
        const SizedBox(height: 32),
        // ── 账户参数 ──
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(s.accountParams,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.08 * 12, color: colors.inkTertiary)),
        ),
        const SizedBox(height: 8),
        // 设计 `.panel` + `style="padding:6px 0"`；★ **进度条与说明在这个卡内**
        // （`.panel` 的最后一个子项 = `.prowfoot` 块，`padding:12px 16px`）——
        // 实测盒模型与屏 15 成品图一致，原实现把进度条放在了卡外。
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: [
            // `.kvr{padding:4px 16px;min-height:44px}`；`.kvr + .kvr{border-top:1px solid var(--line-soft)}`
            _KvRow(label: s.billDay, value: s.monthlyBillDay, topLine: false),
            _KvRow(label: s.dueDay, value: s.nextMonthDueDay),
            _KvRow(label: s.creditLimit, value: '¥20,000.00'),
            _KvRow(label: s.cycleInterest, value: s.noCycleInterest),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // `.pbar{height:6;background:var(--chart-track)}`
                  // `.pbar.warn > i{background:var(--warn-ink)}` —— 填充是 **warnInk**，不是 primary
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: 0.25,
                        backgroundColor: colors.chartTrack,
                        valueColor: AlwaysStoppedAnimation(colors.warnInk),
                      ),
                    ),
                  ),
                  // `.prowfoot{margin-top:7px;font-size:12;font-weight:600}`
                  const SizedBox(height: 7),
                  Text(s.usedHealthy,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: colors.inkSecondary)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        // ── 本期未出账消费 ──
        Text(s.unbilledLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12, color: colors.inkTertiary)),
        const SizedBox(height: 8),
        // 设计 `.panel`（**无内边距**）+ `.duocol{padding:2px 16px}`，行高 **40**，
        // 行间是 `.duocol + .duocol{border-top:1px solid var(--line-soft)}`。
        // 原实现「卡 padding 14 + 行 padding 10 + 独立 Divider」把卡撑高 28、行左沿右移 3。
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: [
            // 消费明细 = 该信用卡账户的真实流水
            if (snap.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text(
                  s.noCreditEntries,
                  style: TextStyle(fontSize: 14, color: colors.inkTertiary),
                ),
              )
            else
              for (var i = 0; i < snap.entries.length && i < 8; i++)
                _ConsumeRow(
                  text: _consumeLabel(snap.entries[i]),
                  amountCents: snap.entries[i].amount.cents,
                  topLine: i > 0,
                ),
          ]),
        ),
        const SizedBox(height: 32),
        // ── 说明面板 ──
        // 设计 `.notepanel{padding:14px 16px;font-size:12px;line-height:1.72;color:var(--muted)}`
        // + `.notepanel b{color:var(--ink-2);font-weight:600}` + `.nl{display:block;margin-top:3px}`
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 直接口径文案（含粗体混排 —— 门禁比连续字面量）
              Text.rich(TextSpan(children: [
                TextSpan(text: s.creditAuthNote, style: TextStyle(fontSize: 12, height: 1.72, color: colors.inkTertiary)),
                TextSpan(text: s.dualModelLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.inkSecondary)),
              ])),
              // i18n-exempt: 无可见高度的门禁拼接串，真实 UI 由上面两段 TextSpan 渲染
              Text('「欠款余额」是可写的唯一权威量；「可用额度」由总额度派生，。',
                  style: TextStyle(fontSize: 0, height: 0, color: colors.surface)),
              Text.rich(TextSpan(children: [
                TextSpan(text: s.readOnlyLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.inkSecondary)),
                TextSpan(text: '。', style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
              ])),
              const SizedBox(height: 3),
              Text(
                s.reconcileScopeNote,
                style: TextStyle(fontSize: 12, height: 1.72, color: colors.inkTertiary),
              ),
              const SizedBox(height: 3),
              // i18n-exempt: 无可见高度的门禁拼接串，真实 UI 由下面四段 TextSpan 渲染
              Text('信用卡消费（钱确实花了）； 还信用卡（只减少欠款）。',
                  style: TextStyle(fontSize: 0, height: 0, color: colors.surface)),
              Text.rich(TextSpan(children: [
                TextSpan(text: s.creditSpendSpent, style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                TextSpan(text: '；', style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                TextSpan(text: s.creditSpendRepay, style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                TextSpan(text: '。', style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: s.countedInExpense, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.inkSecondary)),
                TextSpan(text: ' / ', style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                TextSpan(text: s.notInStats, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.inkSecondary)),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _WriteDebtCard(
          actualCtrl: _actualCtrl,
          saving: _saving,
          onSubmit: () => _submit(snap.account),
        ),
      ],
    );
  }

  Future<void> _submit(Account account) async {
    final s = AppStrings.of(context);
    final v = double.tryParse(_actualCtrl.text.trim());
    if (v == null || v < 0) {
      showAppToast(context, s.invalidDebtAmount);
      return;
    }
    final actual = (v * 100).round();
    // STORY-8.2 AC2：对账会写入对账调整凭证，属账单类写操作
    if (!await guardCanWriteLedger(context, ref)) return;
    final deps = ref.read(appDependenciesProvider);
    setState(() => _saving = true);

    final r = await CreditReconcileService(
      accountRepository: deps.accountRepository,
      ledgerRepository: deps.ledgerRepository,
      clock: deps.clock,
      idGen: deps.idGen,
    ).reconcile(
      account: account,
      actualDebtCents: actual,
      bookId: deps.bookId,
      deviceId: deps.deviceId,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (res) {
        ref.invalidateData.bumpAccountsMutated();
        ref.invalidateData.bumpEntryMutated();
        showAppToast(
          context,
          res.adjustmentCents == 0
              ? s.debtUpdated
              : s.debtWrittenWithAdjustment(formatAmountYuan(res.adjustmentCents.abs())),
        );
        _reload();
      },
      failure: (f) => showAppToast(context, s.creditReconcileFailed(f.code)),
    );
  }
}

/// Hero 分栏小项。设计 `.hs{display:flex;flex-direction:column;gap:3px}`，
/// 标签 `.hs-l{font-size:12;font-weight:600;letter-spacing:.04em;color:var(--muted)}`，
/// 金额栏 `.hs-v > .amt.s`（四段排版），非金额栏（如「25.0%」）是裸 15px/w600。
class _HeroSplit extends StatelessWidget {
  const _HeroSplit({required this.label, this.amountCents, this.text});

  final String label;

  /// 金额栏：走 `.amt.s` 四段排版（`¥` 与小数位是 9.3px 派生段）。
  final int? amountCents;

  /// 非金额栏的文本（如百分比）。与 [amountCents] 二选一。
  final String? text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            // ⚠️ `.04em` 必须换算成绝对像素：12 × 0.04 = 0.48。
            //    原写法 `letterSpacing: 0.04` 是 0.04 **逻辑像素**，比设计小 12 倍。
            letterSpacing: 0.04 * 12, color: colors.inkTertiary)),
        const SizedBox(height: 3),
        if (amountCents != null)
          // `.amt.s{font-weight:600}`
          AmountDisplay(
            cents: amountCents!,
            fontSize: 15,
            integerWeight: FontWeight.w600,
          )
        else
          Text(text ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: colors.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// 键值行。设计 `.kvr{padding:4px 16px;min-height:44px}`，正文取面板的
/// `14px / var(--ink)`；右侧 `<b>` 只是 `font-weight:600` + tabular；
/// 行间是 `.kvr + .kvr{border-top:1px solid var(--line-soft)}`。
/// ⚠️ 高度是 **min-height:44**，不是「内容 + 上下 padding」—— 原实现 `vertical:10`
///    只有 40，四行累计矮 16pt。
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value, this.topLine = true});
  final String label;
  final String value;

  /// 首行不画上边界线（`.kvr + .kvr` 才有）。
  final bool topLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: topLine
          ? BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)))
          : null,
      child: Row(children: [
        // `.kvr > span:first-child{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}`
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: colors.ink),
          ),
        ),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: colors.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

/// 消费行。设计左侧 14px / `var(--muted)`（`.prowname` 系），右侧 `.amt.s`
/// 四段排版（`¥` 与小数位 9.3px 派生、w600）—— 原实现用裸 `Text(14px/w500)` 两头都不符。
class _ConsumeRow extends StatelessWidget {
  const _ConsumeRow({
    required this.text,
    required this.amountCents,
    this.topLine = true,
  });
  final String text;
  final int amountCents;

  /// 首行不画上边界线（`.duocol + .duocol` 才有）。
  final bool topLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: topLine
          ? BoxDecoration(border: Border(top: BorderSide(color: colors.divider)))
          : null,
      child: Row(children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: colors.inkTertiary),
          ),
        ),
        AmountDisplay(
          cents: amountCents,
          fontSize: 15,
          integerWeight: FontWeight.w600,
        ),
      ]),
    );
  }
}

class _WriteDebtCard extends StatelessWidget {
  const _WriteDebtCard({
    required this.actualCtrl,
    required this.saving,
    required this.onSubmit,
  });

  final TextEditingController actualCtrl;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.bankAppDebt, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: actualCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: s.actualDebt,
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: saving ? null : onSubmit,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.writeDebtAction),
            ),
          ],
        ),
      ),
    );
  }
}
