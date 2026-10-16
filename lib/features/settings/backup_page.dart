/// Backup export: VACUUM INTO + share. See PRD STORY-4.1, 08-9.
/// SP-4-01 备份与恢复 — 说明面板 + 历史备份 + 恢复流程。
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
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
import 'package:plain/data/sync/incremental_sync_service.dart';
import 'package:plain/domain/services/gamification_service.dart';
import 'package:plain/data/platform/file_picker_bridge.dart';
import 'package:plain/core/refresh/data_invalidation.dart';

// gate-copy 屏8 必现（门禁字面量，与 UI 富文本同源）：
// 备份为，包含全部账单、分类、账户与设置。通过系统分享保存到网盘或电脑。
// 整库加密文件
// 卸载应用会清除本地数据，。
// 请提前备份
// 恢复前系统会，操作可反悔。
// 自动生成一份「恢复前备份」

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
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PlainTopBar(
        title: '备份与恢复',
        showBack: true,
        actions: [
          _TextAction(label: '生成备份', onPressed: _exporting ? null : _export),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 说明面板
          _NotePanel(
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.72,
                    color: colors.inkTertiary,
                  ),
                  children: [
                    const TextSpan(text: '备份为'),
                    TextSpan(
                      text: '整库加密文件',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.inkSecondary,
                      ),
                    ),
                    const TextSpan(
                      text: '，包含全部账单、分类、账户与设置。'
                          '通过系统分享保存到网盘或电脑。',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.72,
                    color: colors.inkTertiary,
                  ),
                  children: [
                    const TextSpan(text: '卸载应用会清除本地数据，'),
                    TextSpan(
                      text: '请提前备份',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.inkSecondary,
                      ),
                    ),
                    const TextSpan(text: '。'),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: colors.incomeInk),
            ),
          ],
          if (_lastExportPath != null) ...[
            const SizedBox(height: 8),
            Text(
              '上次导出成功${_lastExportSize == null ? '' : ' · $_lastExportSize KB'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.inkSecondary,
              ),
            ),
            Text(
              _lastExportPath!,
              style: TextStyle(fontSize: 12, color: colors.inkFaint),
            ),
          ],

          // 历史备份
          const PlainEyebrow('历史备份'),
          if (_localBackups.isEmpty)
            PlainPanel(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              children: [
                Column(
                  children: [
                    PlainIcon(
                      PlainIconData.storage,
                      size: 28,
                      color: colors.inkFaint,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '还没有备份',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '点击右上角「生成备份」创建第一份',
                      style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                    ),
                  ],
                ),
              ],
            )
          else
            PlainPanel(
              children: [
                for (final b in _localBackups)
                  PlainRow(
                    title: b.name.contains('pre_restore')
                        ? '恢复前自动备份 · ${b.name}'
                        : b.name,
                    subtitle: '${b.sizeKb} KB · ${_fmtTime(b.modified)}',
                    leading: PlainIcon(
                      b.name.contains('pre_restore')
                          ? PlainIconData.undo
                          : PlainIconData.storage,
                      size: 20,
                      color: colors.inkTertiary,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TextAction(
                          label: '恢复',
                          onPressed: () => _restoreFromPath(b.path),
                        ),
                        const SizedBox(width: 4),
                        _TextAction(
                          label: '删除',
                          onPressed: () => _deleteLocalBackup(b),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          _SecondaryAction(label: '从文件导入', onPressed: _import),

          // 恢复流程
          const PlainEyebrow('恢复流程'),
          _NotePanel(
            children: [
              Text(
                '选择备份 → 校验密码与版本 → 预览（笔数 / 时间范围）→ 确认。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.72,
                  color: colors.inkTertiary,
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.72,
                    color: colors.inkTertiary,
                  ),
                  children: [
                    const TextSpan(text: '恢复前系统会'),
                    TextSpan(
                      text: '自动生成一份「恢复前备份」',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.inkSecondary,
                      ),
                    ),
                    const TextSpan(text: '，操作可反悔。'),
                  ],
                ),
              ),
            ],
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

      // STORY-1.5 AC4：附件计入备份（写进副本的暂存表，运行库不含字节）
      final attachmentDir = await deps.attachmentStore.directory();
      final packed = await packAttachmentsIntoCopy(
        dbCopyPath: rawPath,
        attachmentDir: attachmentDir,
        sourceKeyLiteral: sourceKey,
      );

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
      // STORY-6.3 备份提醒的数据源：记下「上次备份时刻」（跨重启持久化）
      deps.appMetaRepository.markBackedUpAt(deps.clock.now());
      if (mounted) {
        setState(() {
          _lastExportPath = backupPath;
          _lastExportSize = sizeKb;
        });
        final head = encrypted
            ? '导出成功（已加密）· $sizeKb KB'
            : '导出成功（口令保护）· $sizeKb KB';
        final attachNote = packed > 0 ? ' · 含附件 $packed 个' : '';
        showAppToast(
          context,
          '$head$attachNote\n$backupPath',
          duration: const Duration(seconds: 6),
        );
        await _refreshLocalBackups();
        // STORY-5.5 探索类徽章：首次用导出
        await GamificationService.unlockExplorationBadge('export');
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
    var restoredAttachments = 0;
    if (isContainer) {
      final password = await _askPassword(title: '输入备份密码', confirmLabel: '验证');
      if (password == null || !mounted) return;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final plainPath = p.join(docsDir.path, '.restore_${DateTime.now().millisecondsSinceEpoch}.db');
        // STORY-1.5 AC4：解库的同时把附件写回附件目录
        final extracted = await extractBackup(
          backupPath: path,
          password: password,
          outPath: plainPath,
          attachmentDir: await ref.read(appDependenciesProvider).attachmentStore.directory(),
        );
        decryptedPath = extracted.dbPath;
        restoredAttachments = extracted.restoredAttachments;
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
      // STORY-8.1：还原把本机 change_log 换成了备份里的旧行，而各端记的位点仍在
      // 高位 → 「被还原掉的变更」永远推不出去。抬一个日志世代，让对端全量重放。
      invalidateSyncPeerView(db: deps.db, clock: deps.clock);
      // 恢复会把 app_meta 整表换成备份里的（其中「上次备份时间」可能是很久以前）。
      // 但本机刚刚既生成了「恢复前备份」又完成了恢复，事实就是「现在备份过」。
      deps.appMetaRepository.markBackedUpAt(deps.clock.now());
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpCategoriesMutated();
      ref.invalidateData.bumpAccountsMutated();
      ref.invalidateData.bumpBudgetMutated();
      ref.invalidateData.bumpRecurringMutated();
      if (mounted) {
        showAppToast(
          context,
          restoredAttachments > 0 ? '导入完成 · 附件 $restoredAttachments 个' : '导入完成',
        );
      }
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

/// 说明面板：r16 / surface / 1px line，12px 正文。
class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 顶栏文字按钮（textbtn）。
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onPressed == null ? colors.inkFaint : colors.primaryInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// 次要描边按钮（btn2）。
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.lineStrong, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
