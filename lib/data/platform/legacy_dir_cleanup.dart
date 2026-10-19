/// 已下线功能的**历史目录清理**。
///
/// 两件事都做过一遍就不能回头，所以集中放在一处、注释写清因果：
///
/// 1. 账单附件（原 STORY-1.5）→ `attachments/`。
///    表在 `AppDatabase._migrate()` 里 DROP，文件在这里删。只 DROP 表会留下
///    一整个无人引用的目录（几百 MB 的照片）；只删目录则会留下读不到文件的
///    元数据表。
/// 2. 自定义分类图标（原 F1.2）→ `icons/`。
///    `categories.icon_asset` 在迁移里清空，文件在这里删。
///
/// 幂等：目录不存在直接返回。异常一律吞掉，下次启动再试 ——
/// 与其它启动巡检同款，清理是自愈手段，绝不能拖累启动。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 账单附件目录名。
const String kAttachmentDirName = 'attachments';

/// 自定义分类图标目录名（与旧 `custom_icon_store` 的 'icons' 一致，别改名，
/// 否则清不掉老目录）。
const String kCustomIconDirName = 'icons';

Future<void> _purgeDir(String name) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!dir.existsSync()) return;
    await dir.delete(recursive: true);
  } catch (_) {
    // 文件系统的失败能自愈，下次启动再试
  }
}

/// 删除 App 私有目录下的 `attachments/`（含全部子文件）。
Future<void> purgeAttachmentDirectory() => _purgeDir(kAttachmentDirName);

/// 删除 App 私有目录下的 `icons/`（用户上传过的自定义分类图标）。
Future<void> purgeCustomIconDirectory() => _purgeDir(kCustomIconDirName);
