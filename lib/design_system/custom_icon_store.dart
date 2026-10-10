/// 分类本地图标存储（F1.2 本地上传）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 复制选中的图片到应用文档目录 `icons/`，返回可持久化路径。
Future<String?> saveCustomIcon(String sourcePath) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'icons'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final name = 'cat_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.png' : ext}';
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  } catch (_) {
    return null;
  }
}

/// 删除自定义图标文件（分类删除时可选清理）。
Future<void> deleteCustomIcon(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
