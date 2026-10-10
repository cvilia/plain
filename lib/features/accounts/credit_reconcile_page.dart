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
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/services/credit_card_service.dart';

/// 对账页一次性快照，避免 build 里散落 FutureBuilder / dynamic。
class _CreditSnapshot {
  const _CreditSnapshot({
    required this.account,
    required this.balanceCents,
    required this.storedDebtCents,
    required this.aggregatedDebtCents,
    required this.diffCents,
  });

  final Account account;
  final int balanceCents;
  final int storedDebtCents;
  final int aggregatedDebtCents;
  final int diffCents;

  factory _CreditSnapshot.from({
    required Account account,
    required int balanceCents,
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final deps = ref.read(appDependenciesProvider);
    final acctRes = await deps.accountRepository.getById(widget.accountId);
    final balRes = await deps.accountRepository.balanceOf(widget.accountId);
    if (!mounted) return;

    final account = acctRes.successOrNull;
    final bal = balRes.successOrNull;
    if (account == null || bal == null) {
      setState(() {
        _loading = false;
        _error = '账户加载失败';
      });
      return;
    }
    setState(() {
      _snap = _CreditSnapshot.from(
        account: account,
        balanceCents: bal.balanceCents,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('信用卡对账')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _snap == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? '加载失败'),
            const SizedBox(height: Spacing.md),
            OutlinedButton(onPressed: _reload, child: const Text('重试')),
          ],
        ),
      );
    }
    final snap = _snap!;
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _AggregateCard(snap: snap),
        const SizedBox(height: Spacing.lg),
        _WriteDebtCard(
          actualCtrl: _actualCtrl,
          saving: _saving,
          onSubmit: () => _submit(snap.account),
        ),
      ],
    );
  }

  Future<void> _submit(Account account) async {
    final v = double.tryParse(_actualCtrl.text.trim());
    if (v == null || v < 0) {
      showAppToast(context, '请输入有效欠款金额');
      return;
    }
    final actual = (v * 100).round();
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
              ? '欠款已更新'
              : '已写入欠款，生成调整 ${formatAmountYuan(res.adjustmentCents.abs())}',
        );
        _reload();
      },
      failure: (f) => showAppToast(context, '对账失败: ${f.code}'),
    );
  }
}

class _AggregateCard extends StatelessWidget {
  const _AggregateCard({required this.snap});
  final _CreditSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final diff = snap.diffCents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('聚合校验', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            Text('按账单聚合：${formatAmountYuan(snap.aggregatedDebtCents)}'),
            Text('当前存储欠款：${formatAmountYuan(snap.storedDebtCents)}'),
            if (diff != 0)
              Text(
                '相差 ${formatAmountYuan(diff.abs())}，可写入银行 App 数字生成调整凭证',
                style: TextStyle(color: context.colors.expense),
              )
            else
              Text('两者一致', style: TextStyle(color: context.colors.income)),
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('银行 App 显示欠款', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: actualCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '实际欠款',
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
                  : const Text('写入欠款并生成调整凭证'),
            ),
          ],
        ),
      ),
    );
  }
}
