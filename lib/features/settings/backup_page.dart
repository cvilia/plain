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
import 'package:plain/core/backup/backup_container.dart';
import 'package:plain/core/security/db_passphrase.dart';
import 'package:plain/data/db/database.dart';
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
  String? _lastExportSize;
  String? _error;
  List<_LocalBackup> _localBackups = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalBackups());
  }

  Future<void> _refreshLocalBackups() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final files = docs
          .listSync()
          .whereType<File>()
          .where((f) {
            final n = p.basename(f.path);
            return n.endsWith('.sujibak') || n.startsWith('sujibackup_');
          })
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (!mounted) return;
      setState(() {
        _localBackups = [
          for (final f in files)
            _LocalBackup(
              path: f.path,
              name: p.basename(f.path),
              sizeKb: (f.lengthSync() / 1024).toStringAsFixed(1),
              modified: f.lastModifiedSync(),
            ),
        ];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
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
                    Container(
                      padding: const EdgeInsets.all(Spacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '上次导出成功${_lastExportSize == null ? '' : ' · $_lastExportSize KB'}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.inkSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastExportPath!,
                            style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // 本机备份列表：导出文件在应用私有目录，系统文件选择器可能看不到
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('本机备份', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: _refreshLocalBackups,
                        child: const Text('刷新'),
                      ),
                    ],
                  ),
                  Text(
                    '导出的备份保存在应用内，下方可直接恢复；系统选择器可能看不到这些文件。',
                    style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                  ),
                  const SizedBox(height: Spacing.sm),
                  if (_localBackups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                      child: Text('暂无本机备份', style: TextStyle(fontSize: 13, color: context.colors.inkTertiary)),
                    )
                  else
                    for (final b in _localBackups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          b.name.contains('pre_restore')
                              ? Icons.history_outlined
                              : Icons.insert_drive_file_outlined,
                        ),
                        title: Text(
                          b.name.contains('pre_restore')
                              ? '恢复前自动备份 · ${b.name}'
                              : b.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${b.sizeKb} KB · ${_fmtTime(b.modified)}', style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _restoreFromPath(b.path),
                              child: const Text('恢复'),
                            ),
                            IconButton(
                              tooltip: '删除备份',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteLocalBackup(b),
                            ),
                          ],
                        ),
                      ),
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
                  Text('从文件导入', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '选择外部的 .sujibak / .db 备份文件（如微信、网盘里保存的）。',
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
    final password = await _askPassword(title: '设置备份密码', confirmLabel: '导出');
    if (password == null || !mounted) return;
    if (password.length < 4) {
      setState(() => _error = '密码至少 4 位');
      showAppToast(context, '密码至少 4 位');
      return;
    }

    setState(() {
      _exporting = true;
      _error = null;
    });

    String? backupPath;
    try {
      final deps = ref.read(appDependenciesProvider);
      final db = deps.db;

      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // 先 VACUUM 出副本，再加密成 .sujibak
      final rawPath = p.join(docsDir.path, 'sujibackup_$timestamp.tmp.db');
      backupPath = p.join(docsDir.path, 'sujibackup_$timestamp.sujibak');

      final escapedPath = rawPath.replaceAll("'", "''");
      db.raw.execute("VACUUM INTO '$escapedPath'");

      String? sourceKey;
      try {
        sourceKey = sqlcipherKeyLiteral(await loadOrCreateDbPassphrase());
      } catch (_) {
        sourceKey = null;
      }

      final encrypted = await writeEncryptedBackup(
        sourceDbPath: rawPath,
        outPath: backupPath,
        password: password,
        sourceKeyLiteral: sourceKey,
      );
      try {
        File(rawPath).deleteSync();
      } catch (_) {}

      final file = File(backupPath);
      if (!await file.exists()) {
        throw FileSystemException('备份文件未生成', backupPath);
      }
      final size = await file.length();
      final sizeKb = (size / 1024).toStringAsFixed(1);
      if (mounted) {
        setState(() {
          _lastExportPath = backupPath;
          _lastExportSize = sizeKb;
        });
        showAppToast(
          context,
          encrypted
              ? '导出成功（已加密）· $sizeKb KB\n$backupPath'
              : '导出成功（口令保护）· $sizeKb KB\n$backupPath',
          duration: const Duration(seconds: 6),
        );
        await _refreshLocalBackups();
      }

      // 分享失败不影响「已导出到本机」的结论
      try {
        await Share.shareXFiles([XFile(backupPath)], text: '素记备份（需密码）');
      } on Exception {
        if (mounted) {
          showAppToast(context, '文件已保存到应用文档目录（系统分享不可用）');
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = '导出失败: $e');
        showAppToast(context, '导出失败: $e');
      }
    } catch (e) {
      // StateError 等也会给出反馈，不再静默
      final msg = e.toString().contains('backup_rekey_failed')
          ? '加密失败：无法用密码改写备份（请重试或重启应用）'
          : '导出失败: $e';
      if (mounted) {
        setState(() => _error = msg);
        showAppToast(context, msg);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final path = await FilePickerBridge.pickFile(mime: '*/*', extension: 'sujibak,db');
    if (path == null || !mounted) return;
    await _restoreFromPath(path);
  }

  Future<String?> _askPassword({required String title, required String confirmLabel}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '至少 4 位',
            helperText: '忘记密码将无法恢复备份',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocalBackup(_LocalBackup b) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除备份',
      message: '确定删除「${b.name}」？删除后无法恢复该备份。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      final f = File(b.path);
      if (await f.exists()) await f.delete();
      if (mounted) {
        showAppToast(context, '已删除备份');
        await _refreshLocalBackups();
      }
    } on Exception catch (e) {
      if (mounted) showAppToast(context, '删除失败: $e');
    }
  }

  String _fmtTime(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 从任意路径恢复（本机列表 / 系统选择器）。
  Future<void> _restoreFromPath(String path) async {
    if (!mounted) return;
    final bytes = await File(path).readAsBytes();
    String magicAt(int n) => bytes.length >= n ? String.fromCharCodes(bytes.sublist(0, n)) : '';
    final isContainer = magicAt(kBackupMagicPlain.length) == kBackupMagicPlain ||
        magicAt(kBackupMagic.length) == kBackupMagic;

    String? decryptedPath = path;
    if (isContainer) {
      final password = await _askPassword(title: '输入备份密码', confirmLabel: '验证');
      if (password == null || !mounted) return;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final plainPath = p.join(docsDir.path, '.restore_${DateTime.now().millisecondsSinceEpoch}.db');
        await extractBackupDb(backupPath: path, password: password, outPath: plainPath);
        decryptedPath = plainPath;
      } on FormatException {
        if (mounted) setState(() => _error = '密码错误');
        return;
      } on Exception catch (e) {
        if (mounted) setState(() => _error = '备份无法读取: $e');
        return;
      }
    }

    if (!mounted) return;
    final preview = AppDatabase.previewBackup(decryptedPath);
    final previewLine = preview == null
        ? '⚠️ 无法读取备份摘要，文件可能已损坏或不完整'
        : '备份摘要：${preview.describe()}';
    final confirmed = await showConfirmDialog(
      context,
      title: '导入备份',
      message: '$previewLine\n\n导入将替换当前所有数据，此操作不可恢复。确定继续？',
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
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        // 恢复前自动备份（AC5），文件名标明用途，列表里会显示「恢复前自动备份」
        final pre = p.join(docsDir.path, 'sujibackup_pre_restore_$ts.db');
        final esc = pre.replaceAll("'", "''");
        deps.db.raw.execute("VACUUM INTO '$esc'");
        if (mounted) {
          showAppToast(context, '已生成「恢复前自动备份」');
        }
      } catch (_) {}
      deps.db.restoreFrom(decryptedPath);
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpCategoriesMutated();
      ref.invalidateData.bumpAccountsMutated();
      ref.invalidateData.bumpBudgetMutated();
      ref.invalidateData.bumpRecurringMutated();
      if (mounted) showAppToast(context, '导入完成');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '导入失败: $e');
    } finally {
      if (decryptedPath != path) {
        try {
          File(decryptedPath).deleteSync();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _exporting = false);
        _refreshLocalBackups();
      }
    }
  }
}

class _LocalBackup {
  const _LocalBackup({
    required this.path,
    required this.name,
    required this.sizeKb,
    required this.modified,
  });
  final String path;
  final String name;
  final String sizeKb;
  final DateTime modified;
}
