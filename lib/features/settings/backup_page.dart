/// Backup export: VACUUM INTO + share. See PRD STORY-4.1, 08-9.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/data/platform/file_picker_bridge.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/app/theme/design_tokens.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _exporting = false;
  String? _lastExportPath;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导出数据', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '创建包含所有记账数据的备份文件。',
                    style: TextStyle(fontSize: 13, color: context.colors.inkSecondary),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.backup_outlined),
                      label: Text(_exporting ? '导出中...' : '导出备份'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Spacing.md),
                    Text(_error!, style: TextStyle(fontSize: 12, color: context.colors.expense)),
                  ],
                  if (_lastExportPath != null) ...[
                    const SizedBox(height: Spacing.md),
                    Text('上次导出: $_lastExportPath', style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导入数据', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '从备份文件恢复数据。',
                    style: TextStyle(fontSize: 13, color: context.colors.inkSecondary),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('导入备份'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final deps = ref.read(appDependenciesProvider);
      final db = deps.db;

      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = p.join(docsDir.path, 'sujibackup_$timestamp.db');

      // VACUUM INTO requires a literal path (no bound params) — escape quotes.
      final escapedPath = backupPath.replaceAll("'", "''");
      db.raw.execute("VACUUM INTO '$escapedPath'");

      final file = File(backupPath);
      if (await file.exists()) {
        final size = await file.length();
        setState(() {
          _lastExportPath = '$backupPath (${(size / 1024).toStringAsFixed(1)} KB)';
        });
        await Share.shareXFiles([XFile(backupPath)], text: 'SuJi Backup');
      }
    } on Exception catch (e) {
      setState(() => _error = '导出失败: $e');
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final path = await FilePickerBridge.pickFile(mime: '*/*', extension: 'db');
    if (path == null || !mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '导入备份',
      message: '导入将替换当前所有数据，此操作不可恢复。确定继续？',
      confirmLabel: '确定导入',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final deps = ref.read(appDependenciesProvider);
      deps.db.restoreFrom(path);
      // Everything changed at once — bump every scope so UI refetches.
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpCategoriesMutated();
      ref.invalidateData.bumpAccountsMutated();
      ref.invalidateData.bumpBudgetMutated();
      ref.invalidateData.bumpRecurringMutated();
      if (mounted) {
        showAppToast(context, '导入完成');
      }
    } on Exception catch (e) {
      setState(() => _error = '导入失败: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
