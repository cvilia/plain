/// Entry input controller. Tap-category-to-save. See PRD STORY-1.1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/data_freshness.dart';
import 'package:plain/data/platform/platform_bridge.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/category_suggester.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/controllers/draft_store.dart';

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
    this.wasIncompleteExpression = false,
    this.isSubmitting = false,
    this.errorMessage,
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
  final bool wasIncompleteExpression;
  final bool isSubmitting;
  final String? errorMessage;

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
    bool? wasIncompleteExpression,
    bool? isSubmitting,
    String? errorMessage,
    bool clearCategory = false,
    bool clearAccount = false,
    bool clearNote = false,
    bool clearToast = false,
    bool clearError = false,
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
      wasIncompleteExpression: wasIncompleteExpression ?? this.wasIncompleteExpression,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class EntryInputController extends Notifier<EntryInputState> {
  final _evaluator = const ExpressionEvaluator();

  @override
  EntryInputState build() {
    // Don't access ref in build() - use post-frame for draft restore
    Future.microtask(_restoreDraftIfAny);
    return EntryInputState(occurredAt: DateTime.now().toUtc());
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
    } on Exception {
      // Ignore draft restore errors
    }
  }

  CreateEntryUseCase get _createEntry => ref.read(appDependenciesProvider).createEntry;
  Clock get _clock => ref.read(appDependenciesProvider).clock;
  String get _bookId => ref.read(appDependenciesProvider).bookId;
  String get _deviceId => ref.read(appDependenciesProvider).deviceId;

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

  void onClearAll() => state = EntryInputState(occurredAt: state.occurredAt);

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

  void onTypeChanged(EntryType type) => state = state.copyWith(type: type, clearCategory: true);

  /// Select category without saving (for picker page).
  void selectCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
    _saveDraft();
  }

  void onAccountSelected(String? accountId) =>
      state = state.copyWith(selectedAccountId: accountId, clearAccount: accountId == null);

  void onToAccountSelected(String? accountId) => state = state.copyWith(toAccountId: accountId);

  void onNoteChanged(String? note) {
    state = state.copyWith(note: note, clearNote: note == null || note.isEmpty);
    _saveDraft();
    _suggestCategoryFromNote(note);
  }

  /// Rule-based category suggestion from note (PRD STORY-1.3 AC4).
  void _suggestCategoryFromNote(String? note) {
    if (note == null || note.trim().isEmpty) return;
    // Skip if category already manually selected
    if (state.selectedCategoryId != null) return;

    // Historical keyword → category mapping
    const keywordMap = {
      '瑞幸': 'preset_food_drink',
      'luckin': 'preset_food_drink',
      '星巴克': 'preset_food_drink',
      'starbucks': 'preset_food_drink',
      '麦当劳': 'preset_food_lunch',
      'mcdonald': 'preset_food_lunch',
      '肯德基': 'preset_food_lunch',
      'kfc': 'preset_food_lunch',
      '滴滴': 'preset_transport_taxi',
      '打车': 'preset_transport_taxi',
      '地铁': 'preset_transport_bus',
      '加油': 'preset_transport_fuel',
      '房租': 'preset_housing_rent',
      '话费': 'preset_telecom_phone',
      '工资': 'preset_income_salary',
    };

    final suggestion = CategorySuggester.suggest(
      note: note,
      keywordToCategory: keywordMap,
    );

    if (suggestion != null && suggestion.confidence >= 0.3) {
      state = state.copyWith(selectedCategoryId: suggestion.categoryId);
    }
  }

  void onDateSelected(DateTime date) => state = state.copyWith(occurredAt: date);

  void loadForEdit({required LedgerEntry entry}) {
    final expr = entry.amount.toYuanString();
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
    );
  }

  Future<bool> submitOnCategoryTap(String categoryId) async {
    if (state.isEditing) {
      state = state.copyWith(selectedCategoryId: categoryId);
      return false;
    }
    state = state.copyWith(selectedCategoryId: categoryId);
    if (!state.hasAmount) return false;
    return _save();
  }

  Future<bool> saveExplicit() => _save();

  Future<bool> _save() async {
    if (state.isSubmitting) return false;
    final eval = _evaluator.eval(state.amountExpression);
    if (eval.money.isZero) {
      state = state.copyWith(errorMessage: 'amount_zero', clearToast: true);
      return false;
    }
    if (!eval.money.withinProductLimit) {
      state = state.copyWith(errorMessage: 'amount_over_limit', clearToast: true);
      return false;
    }
    if (state.selectedCategoryId == null) {
      state = state.copyWith(errorMessage: 'category_required', clearToast: true);
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await _createEntry(CreateEntryInput(
      amountExpression: state.amountExpression,
      type: state.type,
      categoryId: state.selectedCategoryId!,
      accountId: state.selectedAccountId,
      toAccountId: state.toAccountId,
      note: state.note,
      occurredAt: state.occurredAt,
      bookId: _bookId,
      deviceId: _deviceId,
    ));

    return result.when(
      success: (entry) {
        final toast = eval.wasIncomplete
            ? 'Saved ${entry.amount.toYuanString()} (prefix)'
            : 'Saved \u00a5${entry.amount.toYuanString()}';
        state = state.copyWith(
          amountExpression: '',
          displayAmount: '',
          toastMessage: toast,
          wasIncompleteExpression: eval.wasIncomplete,
          isSubmitting: false,
          clearError: true,
        );
        draftStore.clear(); // Clear draft after successful save
        _updateWidgetSnapshot();
        ref.read(dataFreshnessProvider.notifier).bump();
        return true;
      },
      failure: (f) {
        state = state.copyWith(isSubmitting: false, errorMessage: f.code, clearToast: true);
        return false;
      },
    );
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
      occurredAt: state.occurredAt ?? DateTime.now().toUtc(),
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
      savedAt: DateTime.now().toUtc(),
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

  /// No-op placeholder (kept for API compatibility).
  void _noop() {}

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
        final snapshot = SnapshotBuilder.build(
          monthExpenseCents: 0,
          monthIncomeCents: 0,
          entryCount: 1,
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
