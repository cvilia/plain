/// Entry input controller. Tap-category-to-save. See PRD STORY-1.1.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/platform/platform_bridge.dart';
import 'package:plain/domain/entities/currency_rate.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/emotion_feedback_service.dart';
import 'package:plain/domain/services/gamification_service.dart';
import 'package:plain/domain/services/merchant_learner.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/controllers/draft_store.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/features/ledger/controllers/recent_categories.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/app_strings.dart';

class EntryInputState {
  const EntryInputState({
    this.amountExpression = '',
    this.displayAmount = '',
    this.selectedCategoryId,
    this.selectedAccountId,
    this.toAccountId,
    this.note,
    this.type = EntryType.expense,
    this.occurredAt,
    this.isEditing = false,
    this.editingId,
    this.toastMessage,
    this.emotionFeedback,
    this.reimburseStatus = ReimburseStatus.none,
    this.excludeFromStats = false,
    this.canMarkExcluded = true,
    this.wasIncompleteExpression = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.occurredAtUserSet = false,
    this.foreignCurrency,
    this.foreignRate,
  });

  final String amountExpression;
  final String displayAmount;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final String? toAccountId;
  final String? note;
  final EntryType type;
  final DateTime? occurredAt;
  final bool isEditing;
  final String? editingId;
  final String? toastMessage;

  /// STORY-5.4：保存后触发的情绪反馈（null = 不给反馈）。
  final EmotionFeedback? emotionFeedback;

  /// STORY-1.8：报销状态。
  final ReimburseStatus reimburseStatus;

  /// G-2：手动标记「不计入收支」（只改统计口径，不改账户余额）。
  final bool excludeFromStats;

  /// 是否允许改「不计入收支」：编辑已有账单时取自 `entry.canMarkExcluded`，
  /// 新建态默认允许（是否显示仍要看类型）。
  final bool canMarkExcluded;
  final bool wasIncompleteExpression;
  final bool isSubmitting;
  final String? errorMessage;

  /// STORY-9.3：当前账户是外币时，这里的金额框输入的是**原币**。
  /// null = 本位币记账（不显示任何提示）。
  final String? foreignCurrency;

  /// 锁定汇率（原币 → 本位币）；null = 用户还没设定（保存会被拦）。
  final double? foreignRate;

  /// 是否在外币语境下（记账页据此显示「你输入的是外币」）。
  bool get isForeign => foreignCurrency != null;

  /// 用户**显式**改过日期（日期选择器 / OCR 带日期）。
  ///
  /// 新建保存时只有它为 true 才用 [occurredAt]，否则取保存那一刻的 now()。
  /// 否则会踩这个坑：记账页的 `occurredAt` 是**页面元素首次创建时**取的
  /// （全局 NotifierProvider，进程不退出就不重建），草稿恢复还会带回更早的
  /// `savedAt` —— 结果「最后记的一笔」带着半小时前的时间戳，流水按
  /// `occurred_at DESC` 一排就沉到别人下面去了（用户实测：最后记美妆，
  /// 首行却是汽车养护）。
  final bool occurredAtUserSet;

  bool get hasAmount => displayAmount.isNotEmpty && displayAmount != '0';

  EntryInputState copyWith({
    String? amountExpression,
    String? displayAmount,
    String? selectedCategoryId,
    String? selectedAccountId,
    String? toAccountId,
    String? note,
    EntryType? type,
    DateTime? occurredAt,
    bool? isEditing,
    String? editingId,
    String? toastMessage,
    EmotionFeedback? emotionFeedback,
    ReimburseStatus? reimburseStatus,
    bool? excludeFromStats,
    bool? canMarkExcluded,
    bool? wasIncompleteExpression,
    bool? isSubmitting,
    String? errorMessage,
    bool? occurredAtUserSet,
    String? foreignCurrency,
    double? foreignRate,
    bool clearCategory = false,
    bool clearAccount = false,
    bool clearNote = false,
    bool clearToast = false,
    bool clearError = false,
    bool clearEmotion = false,
    bool clearForeignCurrency = false,
  }) {
    return EntryInputState(
      amountExpression: amountExpression ?? this.amountExpression,
      displayAmount: displayAmount ?? this.displayAmount,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedAccountId: clearAccount ? null : (selectedAccountId ?? this.selectedAccountId),
      toAccountId: toAccountId ?? this.toAccountId,
      note: clearNote ? null : (note ?? this.note),
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      isEditing: isEditing ?? this.isEditing,
      editingId: editingId ?? this.editingId,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      emotionFeedback: clearEmotion ? null : (emotionFeedback ?? this.emotionFeedback),
      reimburseStatus: reimburseStatus ?? this.reimburseStatus,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
      canMarkExcluded: canMarkExcluded ?? this.canMarkExcluded,
      wasIncompleteExpression: wasIncompleteExpression ?? this.wasIncompleteExpression,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      occurredAtUserSet: occurredAtUserSet ?? this.occurredAtUserSet,
      foreignCurrency:
          clearForeignCurrency ? null : (foreignCurrency ?? this.foreignCurrency),
      foreignRate: clearForeignCurrency ? null : (foreignRate ?? this.foreignRate),
    );
  }
}

class EntryInputController extends Notifier<EntryInputState> {
  final _evaluator = const ExpressionEvaluator();

  @override
  EntryInputState build() {
    // Don't access ref in build() - use post-frame for draft restore
    Future.microtask(_restoreDraftIfAny);
    return EntryInputState(occurredAt: _clock.now());
  }

  void _restoreDraftIfAny() {
    try {
      final draft = draftStore.load(_clock);
      if (draft != null) {
        state = EntryInputState(
          amountExpression: draft.amountExpression,
          displayAmount: draft.amountExpression,
          selectedCategoryId: draft.categoryId,
          selectedAccountId: draft.accountId,
          toAccountId: draft.toAccountId,
          note: draft.note,
          type: draft.type,
          occurredAt: draft.savedAt,
        );
      }
    } catch (e, st) {
      // 草稿恢复失败不该挡住记账，但不能静默——否则「草稿没回来」无从查起
      _log.warn('entry.draft_restore_failed', fields: {'error': '$e', 'stack': '$st'});
    }
  }

  CreateEntryUseCase get _createEntry => ref.read(appDependenciesProvider).createEntry;
  UpdateEntryUseCase get _updateEntry => ref.read(appDependenciesProvider).updateEntry;
  DeleteEntryUseCase get _deleteEntry => ref.read(appDependenciesProvider).deleteEntry;
  Clock get _clock => ref.read(appDependenciesProvider).clock;
  AppLog get _log => ref.read(logProvider);

  AppStrings get _strings => ref.read(appStringsProvider);
  String get _bookId => ref.read(appDependenciesProvider).bookId;
  String get _deviceId => ref.read(appDependenciesProvider).deviceId;

  /// 未选账户时自动落到第一个可用账户（通常是种子的「现金」）。
  Future<String?> _resolveAccountId(String? selected) async {
    if (selected != null) return selected;
    final res = await ref.read(appDependenciesProvider).accountRepository.listAll();
    final list = res.successOrNull;
    return (list != null && list.isNotEmpty) ? list.first.id : null;
  }

  /// STORY-9.3：账户币种上下文。账户就是本位币时返回 null。
  ///
  /// 返回原币代码与「原币 → 本位币」的锁定汇率；汇率为 null 表示用户还没设定，
  /// 此时应当拦截并提示，而不是拿 0 当汇率用。
  Future<({String currency, double? rate})?> foreignCurrencyContext(
    String accountId, {
    String? toAccountId,
  }) async {
    final deps = ref.read(appDependenciesProvider);
    final acc = await deps.accountRepository.getById(accountId);
    final account = acc.successOrNull;
    if (account == null) return null;

    // 转出端与本位币一致时，再看转入端（跨币种转账 AC3）
    var currency = account.currency;
    if (currency == MoneyRules.defaultCurrency && toAccountId != null) {
      final other = await deps.accountRepository.getById(toAccountId);
      final o = other.successOrNull;
      if (o != null && o.currency != MoneyRules.defaultCurrency) {
        currency = o.currency;
      }
    }
    if (currency == MoneyRules.defaultCurrency) return null;

    final rates = await deps.currencyRateRepository.listByBook(_bookId);
    final want = '$currency/${MoneyRules.defaultCurrency}';
    double? rate;
    for (final r in rates.successOrNull ?? const <CurrencyRate>[]) {
      if (r.pairKey == want) rate = r.rate;
    }
    return (currency: currency, rate: rate);
  }

  /// 编辑态时持有原实体，供 update 使用。
  LedgerEntry? _editingEntry;

  /// 最近一次新建成功的账单 id，供保存 toast「撤销」使用。
  String? lastSavedEntryId;

  /// STORY-5.1「保存后停留」设置。
  bool get stayAfterSave => ref.read(displayPrefsProvider).stayAfterSave;

  void onDigit(String d) {
    final expr = state.amountExpression;
    final dot = expr.indexOf('.');
    if (dot >= 0 && expr.length - dot - 1 >= 2 && !_isOperatorPending(expr)) return;
    if (_integerPartLength(expr) >= 10 && !_isOperatorPending(expr)) {
      state = state.copyWith(errorMessage: 'amount_over_limit');
      return;
    }
    _append(d);
  }

  void onDot() {
    final expr = state.amountExpression;
    if (_isOperatorPending(expr)) {
      _append('0.');
      return;
    }
    if (_lastNumber(expr).contains('.')) return;
    _append('.');
  }

  void onOperator(String op) {
    final expr = state.amountExpression;
    if (expr.isEmpty) {
      if (op == '-') _append('-');
      return;
    }
    if (_isOperatorPending(expr)) {
      state = state.copyWith(amountExpression: expr.substring(0, expr.length - 1) + op);
      return;
    }
    _append(op);
  }

  void onBackspace() {
    final expr = state.amountExpression;
    if (expr.isEmpty) return;
    final newExpr = expr.substring(0, expr.length - 1);
    final result = _evaluator.eval(newExpr);
    var display = result.money.toYuanString();
    final lastNum = _lastNumber(newExpr);
    if (lastNum.contains('.') && !_isOperatorPending(newExpr)) display = lastNum;

    state = state.copyWith(
      amountExpression: newExpr,
      displayAmount: display,
      wasIncompleteExpression: result.wasIncomplete,
      clearError: true,
    );
  }

  void onClearAll() {
    _editingEntry = null;
    state = EntryInputState(occurredAt: state.occurredAt);
  }

  void onEquals() {
    final result = _evaluator.eval(state.amountExpression);
    final text = result.money.toYuanString();
    state = state.copyWith(
      amountExpression: text,
      displayAmount: text,
      wasIncompleteExpression: result.wasIncomplete,
      clearError: true,
    );
  }

  void onTypeChanged(EntryType type) {
    state = state.copyWith(type: type, clearCategory: true);
    // 转账/借款的账户组合变了，外币语境可能跟着变
    refreshCurrencyContext();
  }

  /// Select category without saving (for picker page).
  ///
  /// [alreadyVisible]：该分类是否已在宫格展示的 11 格里 —— 由宫格算好传进来
  /// （只有它知道"现在显示哪 11 个"）。在的话不重排宫格顺序（用户口径
  /// 2026-10-16），不在的才顶到第一格，好在返回后能看见它。
  void selectCategory(String categoryId, {bool alreadyVisible = false}) {
    state = state.copyWith(selectedCategoryId: categoryId);
    if (categoryId.isNotEmpty) {
      ref.read(recentCategoriesProvider.notifier).use(
            state.type.wire,
            categoryId,
            alreadyVisible: alreadyVisible,
          );
    }
    _saveDraft();
  }

  void onAccountSelected(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId, clearAccount: accountId == null);
    refreshCurrencyContext();
  }

  void onToAccountSelected(String? accountId) {
    state = state.copyWith(toAccountId: accountId);
    refreshCurrencyContext();
  }

  /// STORY-9.3：把「当前账户是不是外币」放进 state，让记账页当场提示，
  /// 而不是等用户点保存才报错（此前只有保存拦截，用户看不到自己输的是美元）。
  ///
  /// 保存路径（[_save]）仍会独立再算一次：提示只是提示，拦截以保存时为准。
  Future<void> refreshCurrencyContext() async {
    final accountId = await _resolveAccountId(state.selectedAccountId);
    if (accountId == null) {
      if (state.isForeign) {
        state = state.copyWith(clearForeignCurrency: true);
      }
      return;
    }
    final ctx = await foreignCurrencyContext(
      accountId,
      toAccountId: state.type == EntryType.transfer ? state.toAccountId : null,
    );
    if (ctx == null) {
      if (state.isForeign) state = state.copyWith(clearForeignCurrency: true);
      return;
    }
    if (state.foreignCurrency == ctx.currency && state.foreignRate == ctx.rate) return;
    state = state.copyWith(foreignCurrency: ctx.currency, foreignRate: ctx.rate);
  }

  void onNoteChanged(String? note) {
    state = state.copyWith(note: note, clearNote: note == null || note.isEmpty);
    _saveDraft();
    _suggestCategoryFromNote(note);
  }

  /// STORY-1.6：从**已学到的**商户映射推荐分类。
  ///
  /// 这里不再有任何写死的关键词表——映射来自 `merchant_rules` 表，由用户
  /// 每次「给带备注的账单选分类」累积而来。
  Future<void> _suggestCategoryFromNote(String? note) async {
    final text = note?.trim();
    if (text == null || text.isEmpty) return;
    // 已手选分类就别抢用户的选择
    if (state.selectedCategoryId != null) return;

    final deps = ref.read(appDependenciesProvider);
    final res = await deps.merchantRuleRepository.listByBook(_bookId);
    final rules = res.successOrNull ?? const <MerchantRule>[];
    if (rules.isEmpty) return;

    final suggestion = MerchantLearner.suggest(
      merchant: text,
      rulesByMerchant: {for (final r in rules) r.merchant: r},
    );
    if (suggestion == null || suggestion.confidence < 0.3) return;
    // 异步期间用户可能已经选了分类
    if (state.selectedCategoryId != null) return;
    state = state.copyWith(selectedCategoryId: suggestion.categoryId);
  }

  /// STORY-1.6：把用户这次的「备注 → 分类」记住。
  ///
  /// 只在收入/支出类型上学习——转账、借出借入、对账调整都没有分类。
  Future<void> _learnMerchantFrom(LedgerEntry entry) async {
    final note = entry.note?.trim();
    final categoryId = entry.categoryId;
    if (note == null || note.isEmpty) return;
    if (categoryId == null || categoryId.isEmpty) return;
    if (entry.type != EntryType.expense && entry.type != EntryType.income) return;
    await ref.read(appDependenciesProvider).merchantRuleRepository.learn(
          bookId: entry.bookId,
          merchant: note,
          categoryId: categoryId,
          deviceId: entry.deviceId,
        );
  }

  /// 日期变更：若跨出当前记账月，给出「该账单计入 X 月」提示（G-1 / AC11）。
  /// STORY-9.2：OCR 识别结果预填（不直接入库）。
  ///
  /// [categoryHint] 是分类 id；存在时**由这里选中**——此前只传不选，
  /// 提示被静默丢弃了。
  void applyOcrPrefill({int? amountCents, String? merchant, DateTime? occurredAt, String? categoryHint}) {
    // 金额用整数分 → 字符串，不用 double（G-4 int64 分规则）
    String? amountStr;
    if (amountCents != null) {
      final neg = amountCents < 0;
      final abs = amountCents.abs();
      final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
      amountStr = neg ? '-$s' : s;
    }
    state = state.copyWith(
      amountExpression: amountStr ?? state.amountExpression,
      displayAmount: amountStr ?? state.displayAmount,
      note: (merchant != null && merchant.isNotEmpty) ? merchant : state.note,
      occurredAt: occurredAt ?? state.occurredAt,
      // 小票上的时间算「用户给定」的时间，保存时不再覆盖成 now()
      occurredAtUserSet: occurredAt != null ? true : null,
    );
    final hint = categoryHint;
    if (hint != null && hint.isNotEmpty) {
      // OCR 预填**保留**「顶到第一格」：这不是用户挑的，识别出来的分类往往
      // 不在宫格前 11 格里，不顶上第一格用户就完全看不到系统替他选了什么。
      selectCategory(hint);
    }
  }

  void onDateSelected(DateTime date) {
    state = state.copyWith(occurredAt: date, occurredAtUserSet: true);
    final calendar = ref.read(calendarProvider);
    final today = _clock.now();
    final cur = calendar.periodFor(today.year, today.month);
    final target = calendar.periodFor(date.year, date.month, day: date.day);
    if (target.label != cur.label) {
      state = state.copyWith(
        toastMessage: _strings.entryCountsInMonth(target.month),
      );
    }
  }

  void loadForEdit({required LedgerEntry entry}) {
    final expr = entry.amount.toYuanString();
    _editingEntry = entry;
    state = EntryInputState(
      amountExpression: expr,
      displayAmount: expr,
      selectedCategoryId: entry.categoryId,
      selectedAccountId: entry.accountId,
      toAccountId: entry.toAccountId,
      note: entry.note,
      type: entry.type,
      occurredAt: entry.occurredAt,
      isEditing: true,
      editingId: entry.id,
      reimburseStatus: entry.reimburseStatus,
      excludeFromStats: entry.excludeFromStats,
      canMarkExcluded: entry.canMarkExcluded,
    );
    refreshCurrencyContext();
  }

  /// Category tap only selects — save is an explicit OK action (PRD / UX fix).
  ///
  /// 点的是宫格里的格子 ⇒ 它本来就在展示的 11 格里 ⇒ **不动顺序**（口径
  /// 2026-10-16：点已显示的分类不重排，只有从「更多」选的才顶到第一格）。
  void submitOnCategoryTap(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
    if (categoryId.isNotEmpty) {
      ref.read(recentCategoriesProvider.notifier).use(
            state.type.wire,
            categoryId,
            alreadyVisible: true,
          );
    }
    _saveDraft();
  }

  String? get currentToast => state.toastMessage;

  Future<bool> saveExplicit() => _save();

  /// 校验拦截：写 state 的同时留一条 debug 日志。
  ///
  /// 「点了保存没反应」是最高频的用户困惑，而有日志之前这条链路上一个字都没有。
  bool _blockSave(String code) {
    state = state.copyWith(errorMessage: code, isSubmitting: false, clearToast: true);
    _log.debug('entry.save_blocked', fields: {'reason': code, 'type': state.type.wire});
    return false;
  }

  Future<bool> _save() async {
    if (state.isSubmitting) {
      _log.debug('entry.save_ignored', fields: {'reason': 'submitting'});
      return false;
    }
    _log.debug('entry.save_start', fields: {
      'type': state.type.wire,
      'editing': state.isEditing,
      'hasCategory': state.selectedCategoryId != null,
      'hasAccount': state.selectedAccountId != null,
      'noteLen': state.note?.length ?? 0,
    });
    // STORY-8.2 AC2：只读成员点保存时拦截（不写库、不消费任何额度）
    final deps = ref.read(appDependenciesProvider);
    if (!await deps.memberService.canWrite(deps.bookId)) {
      return _blockSave('member_read_only');
    }
    final eval = _evaluator.eval(state.amountExpression);
    if (eval.error != null) {
      // AC8：除零等非法表达式不得入账
      _log.debug('entry.expression_invalid', fields: {'expr': state.amountExpression});
      return _blockSave('expression_invalid');
    }
    // 新建态：0 元拦截；编辑态：允许存 0（AC9，轻提示）
    if (eval.money.isZero && !state.isEditing) {
      return _blockSave('amount_zero');
    }
    if (!eval.money.withinProductLimit) {
      return _blockSave('amount_over_limit');
    }
    // 转账不选分类（G-2 / AC12）；其余类型必须选分类
    final isTransfer = state.type == EntryType.transfer;
    if (!isTransfer && state.selectedCategoryId == null) {
      return _blockSave('category_required');
    }
    if (isTransfer && (state.selectedAccountId == null || state.toAccountId == null)) {
      return _blockSave('transfer_accounts_required');
    }
    state = state.copyWith(isSubmitting: true, clearError: true);

    // STORY-9.3：账户（或跨币种转账的任一端）不是本位币时，必须能确定汇率。
    // 拿不到汇率就拦截——不用 0 或 1 悄悄记错金额。
    final resolvedAccountId = await _resolveAccountId(state.selectedAccountId);
    double? fxRate;
    String? fxCurrency;
    if (resolvedAccountId != null) {
      final ctx = await foreignCurrencyContext(
        resolvedAccountId,
        toAccountId: state.type == EntryType.transfer ? state.toAccountId : null,
      );
      if (ctx != null) {
        if (ctx.rate == null || ctx.rate! <= 0) {
          _log.debug('entry.fx_rate_missing',
              fields: {'account': resolvedAccountId, 'currency': ctx.currency});
          return _blockSave('fx_rate_required');
        }
        fxRate = ctx.rate;
        fxCurrency = ctx.currency;
      }
    }

    if (state.isEditing && _editingEntry != null) {
      // 编辑一笔原币账单：沿用它自己锁定的汇率重算，不引入新汇率
      final rate = _editingEntry!.exchangeRate ?? fxRate;
      final currency = _editingEntry!.originalAmountCents != null
          ? fxCurrency
          : (fxRate == null ? null : fxCurrency);
      final result = await _updateEntry(
        existing: _editingEntry!,
        amount: rate != null && currency != null
            ? Money((eval.money.cents * rate).round())
            : eval.money,
        originalAmountCents: rate != null && currency != null
            ? eval.money.cents
            : _editingEntry!.originalAmountCents,
        exchangeRate: rate,
        categoryId: state.selectedCategoryId,
        clearCategoryId: state.selectedCategoryId == null,
        accountId: state.selectedAccountId,
        clearAccount: state.selectedAccountId == null,
        toAccountId: state.toAccountId,
        note: state.note,
        clearNote: state.note == null,
        occurredAt: state.occurredAt,
        type: state.type,
        reimburseStatus: state.reimburseStatus,
        excludeFromStats: state.excludeFromStats,
      );
      return result.when(
        success: (entry) {
          _editingEntry = entry;
          state = state.copyWith(
            toastMessage: _strings.entrySavedToast,
            isSubmitting: false,
            clearError: true,
          );
          draftStore.clear();
          // STORY-1.6：用户在这次编辑里确认了分类，也是一个学习信号
          unawaited(_learnMerchantFrom(entry));
          _updateWidgetSnapshot();
          _notifyEntryChanged();
          return true;
        },
        failure: (f) {
          _log.entrySaveFailed(entryType: state.type.wire, code: f.code);
          state = state.copyWith(isSubmitting: false, errorMessage: f.code, clearToast: true);
          return false;
        },
      );
    }

    final occurredAt = state.occurredAtUserSet ? state.occurredAt : _clock.now();
    final result = await _createEntry(CreateEntryInput(
      amountExpression: state.amountExpression,
      type: state.type,
      categoryId: state.selectedCategoryId ?? '',
      accountId: resolvedAccountId,
      toAccountId: state.toAccountId,
      note: state.note,
      occurredAt: occurredAt,
      bookId: _bookId,
      deviceId: _deviceId,
      reimburseStatus: state.reimburseStatus,
      excludeFromStats: state.excludeFromStats,
      // 原币记账：把输入金额当原币，用例折算出本位币
      exchangeRate: fxRate,
      originalCurrency: fxCurrency,
    ), s: _strings);

    return result.when(
      success: (entry) {
        final amt = entry.amount.toYuanString();
        final toast = eval.wasIncomplete
            ? _strings.savedAmountPrefix(amt)
            : _strings.savedAmount(amt);
        lastSavedEntryId = entry.id;
        state = state.copyWith(
          amountExpression: '',
          displayAmount: '',
          toastMessage: toast,
          wasIncompleteExpression: eval.wasIncomplete,
          isSubmitting: false,
          clearError: true,
          clearEmotion: true,
          // 下一笔回到「现在」：否则停留在记账页连记时，后面几笔都会继承
          // 第一笔的旧时间戳，流水排序跟着乱。
          occurredAt: _clock.now(),
          occurredAtUserSet: false,
        );
        draftStore.clear(); // Clear draft after successful save
        // STORY-1.6：记住这次的「备注 → 分类」
        unawaited(_learnMerchantFrom(entry));
        _updateWidgetSnapshot();
        _notifyEntryChanged();
        // 这里**不再** pin 分类：宫格顺序已经由「选中那一刻」决定
        // （submitOnCategoryTap / selectCategory，口径见 RecentCategoriesNotifier.use）。
        // 保存时再 pin 一次，会把「编辑旧账单、分类根本没动」也当成一次选择，
        // 白白重排宫格 —— 用户 2026-10-16 要的正是别乱动位置。
        // STORY-5.4：异步评估情绪反馈
        _evaluateEmotion(entry);
        // STORY-5.5：游戏化连续记账
        GamificationService.recordEntry(_clock.now(), _strings);
        return true;
      },
      failure: (f) {
        _log.entrySaveFailed(entryType: state.type.wire, code: f.code);
        state = state.copyWith(isSubmitting: false, errorMessage: f.code, clearToast: true);
        return false;
      },
    );
  }

  /// STORY-1.8：切换「需报销」标记。
  void toggleReimburse() {
    final next = state.reimburseStatus == ReimburseStatus.none
        ? ReimburseStatus.pending
        : ReimburseStatus.none;
    state = state.copyWith(reimburseStatus: next);
  }

  /// 编辑页 chip 走选择弹层，直接设定报销状态。
  void setReimburse(ReimburseStatus value) {
    state = state.copyWith(reimburseStatus: value);
  }

  /// G-2：设定「不计入收支」。
  void setExcludeFromStats(bool value) {
    state = state.copyWith(excludeFromStats: value);
  }

  /// STORY-5.4：清除情绪反馈（UI 层展示后调用）。
  void clearEmotion() {
    state = state.copyWith(clearEmotion: true);
  }

  /// STORY-5.4：异步评估情绪反馈（不影响保存主流程）。
  Future<void> _evaluateEmotion(LedgerEntry entry) async {
    if (entry.type != EntryType.expense) return;
    try {
      final deps = ref.read(appDependenciesProvider);
      final now = _clock.now();
      // 统计窗口：该分类近 90 天已入账支出（排除刚存的本笔）
      final windowStart = now.subtract(const Duration(days: 90));
      final page = await deps.ledgerRepository.listPage(
        filter: EntryFilter(
          categoryId: entry.categoryId,
          type: EntryType.expense.wire,
          fromMs: windowStart.millisecondsSinceEpoch,
          toMs: now.millisecondsSinceEpoch,
          bookId: _bookId,
        ),
        limit: 500,
      );
      final items = (page.successOrNull?.items ?? const <LedgerEntry>[])
          .where((e) => e.id != entry.id) // 排除本笔
          .toList();
      final amounts = items.map((e) => e.amount.cents).toList();

      // 判断本月首笔
      final period = deps.calendar.currentPeriod();
      final monthStartMs = DateTime.parse(period.dayFrom).millisecondsSinceEpoch;
      final monthEntries = await deps.ledgerRepository.listPage(
        filter: EntryFilter(bookId: _bookId, fromMs: monthStartMs, toMs: now.millisecondsSinceEpoch),
        limit: 2,
      );
      final isMonthFirst = (monthEntries.successOrNull?.items.length ?? 0) <= 1;

      // 判断是否超预算
      final budgetRes = await deps.budgetRepository.getTotal(_bookId);
      final budget = budgetRes.successOrNull;
      int overBudget = 0;
      if (budget != null) {
        final spent = await deps.budgetRepository.spentCents(
          bookId: _bookId, fromMs: monthStartMs, toMs: now.millisecondsSinceEpoch,
        );
        final spentCents = spent.successOrNull ?? 0;
        overBudget = spentCents - budget.amount.cents;
      }
      final isOverBudget = overBudget > 0;

      final feedback = await EmotionFeedbackPrefs.evaluate(
        s: _strings,
        amountCents: entry.amount.cents,
        categoryAmountsCents: amounts,
        isMonthFirstEntry: isMonthFirst,
        isOverBudget: isOverBudget,
        now: now,
      );
      if (feedback != null) {
        state = state.copyWith(emotionFeedback: feedback);
      }
    } catch (e, st) {
      // 反馈失败不影响业务
      _log.warn('entry.emotion_feedback_failed', fields: {'error': '$e', 'stack': '$st'});
    }
  }

  /// 保存 toast「撤销」：软删除刚新建的那一笔（5 秒窗口）。
  Future<bool> undoLastSaved() async {
    final id = lastSavedEntryId;
    if (id == null) return false;
    lastSavedEntryId = null;
    final r = await _deleteEntry(id);
    if (r.isSuccess) {
      _notifyEntryChanged();
    }
    return r.isSuccess;
  }

  /// 写库后统一通知：bump + 首页流水立即重载。
  void _notifyEntryChanged() {
    ref.invalidateData.bumpEntryMutated();
    Future.microtask(() {
      try {
        ref.read(flowListControllerProvider.notifier).refresh();
      } catch (e, st) {
        // 首页尚未构建时忽略，但要留痕：流水不刷新是可见故障
        _log.warn('flow.refresh_failed', fields: {'error': '$e', 'stack': '$st'});
      }
    });
  }

  void clearToast() => state = state.copyWith(clearToast: true);
  void clearError() => state = state.copyWith(clearError: true);

  void restoreDraft(EntryDraft draft) {
    if (draft.isExpired(_clock)) return;
    state = EntryInputState(
      amountExpression: draft.amountExpression,
      displayAmount: draft.amountExpression,
      selectedCategoryId: draft.categoryId,
      selectedAccountId: draft.accountId,
      toAccountId: draft.toAccountId,
      note: draft.note,
      type: draft.type,
      occurredAt: state.occurredAt ?? _clock.now(),
    );
    _refreshDisplay();
  }

  EntryDraft exportDraft() => EntryDraft(
        amountExpression: state.amountExpression,
        categoryId: state.selectedCategoryId,
        accountId: state.selectedAccountId,
        toAccountId: state.toAccountId,
        note: state.note,
        type: state.type,
        savedAt: _clock.now(),
      );

  void _append(String s) {
    final newExpr = state.amountExpression + s;
    final result = _evaluator.eval(newExpr);
    var display = result.money.toYuanString();
    final lastNum = _lastNumber(newExpr);
    if (lastNum.contains('.') && !_isOperatorPending(newExpr)) display = lastNum;

    state = state.copyWith(
      amountExpression: newExpr,
      displayAmount: display,
      wasIncompleteExpression: result.wasIncomplete,
      clearError: true,
    );
    _saveDraft();
  }

  void _saveDraft() {
    if (state.amountExpression.isEmpty && state.selectedCategoryId == null) {
      draftStore.clear();
      return;
    }
    draftStore.save(EntryDraft(
      amountExpression: state.amountExpression,
      categoryId: state.selectedCategoryId,
      accountId: state.selectedAccountId,
      toAccountId: state.toAccountId,
      note: state.note,
      type: state.type,
      savedAt: _clock.now(),
    ));
  }

  void _refreshDisplay() {
    final expr = state.amountExpression;
    if (expr.isEmpty) {
      state = state.copyWith(displayAmount: '');
      return;
    }
    final result = _evaluator.eval(expr);
    var display = result.money.toYuanString();
    final lastNum = _lastNumber(expr);
    if (lastNum.contains('.') && !_isOperatorPending(expr)) display = lastNum;
    state = state.copyWith(displayAmount: display, wasIncompleteExpression: result.wasIncomplete);
  }

  bool _isOperatorPending(String expr) {
    if (expr.isEmpty) return false;
    final last = expr[expr.length - 1];
    return last == '+' || last == '-' || last == '\u00d7' || last == '\u00f7' || last == '*' || last == '/';
  }

  String _lastNumber(String expr) {
    if (expr.isEmpty) return '';
    for (var i = expr.length - 1; i >= 0; i--) {
      final c = expr[i];
      if ('+-\u00d7\u00f7*/'.contains(c)) {
        return expr.substring(i + 1);
      }
    }
    return expr;
  }

  int _integerPartLength(String expr) {
    final lastNum = _lastNumber(expr);
    final dot = lastNum.indexOf('.');
    return dot < 0 ? lastNum.length : dot;
  }

  void _updateWidgetSnapshot() {
    Future.microtask(() async {
      try {
        final deps = ref.read(appDependenciesProvider);
        final calendar = ref.read(calendarProvider);
        final monthStartDay = ref.read(monthStartDayProvider);
        final now = _clock.now();
        final period = calendar.periodFor(now.year, now.month, day: monthStartDay);
        final summary = await deps.ledgerRepository.monthSummary(
          bookId: _bookId,
          dayFrom: period.dayFrom,
          dayTo: period.dayTo,
        );
        final s = summary.successOrNull;
        // G-7：隐藏余额时小组件一并遮蔽，不吐真实金额
        final hide = ref.read(hideAmountsProvider);
        final snapshot = SnapshotBuilder.build(
          monthExpenseCents: hide ? 0 : (s?.expenseCents ?? 0),
          monthIncomeCents: hide ? 0 : (s?.incomeCents ?? 0),
          entryCount: hide ? 0 : (s?.txCount ?? 0),
        );
        await PlatformBridge.updateWidgetSnapshot(snapshot);
        await PlatformBridge.reloadWidgetTimelines();
      } on Exception {
        // non-critical
      }
    });
  }

  Money get currentAmount => _evaluator.eval(state.amountExpression).money;
}

final entryInputControllerProvider =
    NotifierProvider<EntryInputController, EntryInputState>(EntryInputController.new);
