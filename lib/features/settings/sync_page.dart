/// WebDAV sync settings page. PRD F7.3.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/data/sync/webdav_client.dart';
import 'package:plain/data/sync/webdav_sync_service.dart';

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController(text: '/plain/sync');
  bool _obscurePass = true;
  bool _testing = false;
  bool _syncing = false;
  String? _status;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final deps = ref.read(appDependenciesProvider);
    String getK(String k) {
      final rows = deps.db.raw.select('SELECT value FROM app_meta WHERE key = ?', [k]);
      return rows.isEmpty ? '' : rows.first['value']! as String;
    }
    setState(() {
      _urlController.text = getK('webdav.url');
      _userController.text = getK('webdav.user');
      _passController.text = getK('webdav.pass');
      _pathController.text = getK('webdav.path').isEmpty ? '/plain/sync' : getK('webdav.path');
      _configured = _urlController.text.isNotEmpty;
    });
  }

  void _saveConfig() {
    final deps = ref.read(appDependenciesProvider);
    void setK(String k, String v) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      deps.db.raw.execute(
        'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
        [k, v, now, v, now],
      );
    }
    setK('webdav.url', _urlController.text.trim());
    setK('webdav.user', _userController.text.trim());
    setK('webdav.pass', _passController.text);
    setK('webdav.path', _pathController.text.trim());
    setState(() => _configured = _urlController.text.trim().isNotEmpty);
    showAppToast(context, '配置已保存');
  }

  WebDavConfig _buildConfig() => WebDavConfig(
    baseUrl: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text,
    remotePath: _pathController.text.trim().isEmpty ? '/plain/sync' : _pathController.text.trim(),
  );

  Future<void> _testConnection() async {
    setState(() { _testing = true; _status = null; });
    final client = WebDavClient();
    final service = WebDavSyncService(
      db: ref.read(appDependenciesProvider).db,
      client: client,
    );
    try {
      final ok = await service.testConnection(_buildConfig());
      setState(() => _status = ok ? '连接成功' : '连接失败，请检查地址和凭据');
    } finally {
      setState(() => _testing = false);
      client.dispose();
    }
  }

  Future<void> _upload() async {
    setState(() { _syncing = true; _status = null; });
    final client = WebDavClient();
    final service = WebDavSyncService(
      db: ref.read(appDependenciesProvider).db,
      client: client,
    );
    try {
      final result = await service.upload(_buildConfig());
      setState(() {
        _status = result.success
            ? '${result.message} (${((result.fileSize ?? 0) / 1024).toStringAsFixed(1)} KB)'
            : result.message;
      });
    } finally {
      setState(() => _syncing = false);
      client.dispose();
    }
  }

  Future<void> _download() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '从云端恢复',
      message: '将用云端备份替换本地数据，当前数据会被覆盖。确定继续？',
      confirmLabel: '确定恢复',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() { _syncing = true; _status = null; });
    final client = WebDavClient();
    final service = WebDavSyncService(
      db: ref.read(appDependenciesProvider).db,
      client: client,
    );
    try {
      final result = await service.download(_buildConfig());
      setState(() => _status = result.message);
    } finally {
      setState(() => _syncing = false);
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 同步')),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务器配置', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '支持坚果云、NextCloud 等 WebDAV 服务。数据仅在你自己的服务器上，不经过第三方。',
                      style: TextStyle(fontSize: 13, color: context.colors.inkSecondary),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: '服务器地址',
                        hintText: 'https://dav.example.com/dav',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _passController,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: '密码 / 应用专用密码',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _pathController,
                      decoration: InputDecoration(
                        labelText: '远程路径',
                        hintText: '/plain/sync',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _testing ? null : _testConnection,
                          child: _testing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('测试连接'),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: FilledButton(onPressed: _saveConfig, child: const Text('保存配置')),
                      ),
                    ]),
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
                    Text('同步操作', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '上传会将本地数据备份到云端；恢复会用云端备份覆盖本地数据。',
                      style: TextStyle(fontSize: 13, color: context.colors.inkSecondary),
                    ),
                    const SizedBox(height: Spacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _configured && !_syncing ? _upload : null,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(_syncing ? '同步中...' : '上传备份到云端'),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _configured && !_syncing ? _download : null,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('从云端恢复'),
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: Spacing.md),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: _status!.contains('成功')
                              ? context.colors.income.withValues(alpha: 0.08)
                              : context.colors.expense.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(_status!, style: const TextStyle(fontSize: 13)),
                      ),
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
                    Text('说明', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '• 同步基于整库备份文件，适合个人多设备使用\n'
                      '• 恢复后需重启应用生效\n'
                      '• 密码仅存储在本地设备，不会上传到任何第三方服务器\n'
                      '• 坚果云用户请在「安全设置」中生成应用专用密码',
                      style: TextStyle(fontSize: 12, color: context.colors.inkSecondary, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
