/// STORY-1.5 附件文件存储（App 私有目录）。
///
/// 只做文件本体的事：拷贝、压缩（超限时）、生成缩略图、删除。
/// 元数据一律进 `attachments` 表（见 `attachment_repository.dart`）。
///
/// **压缩与缩略图不引第三方插件**：用 `dart:ui` 的解码器重采样，
/// 输出 PNG。HEIC 等平台不支持的格式会被 try/catch 兜住 —— 此时保留原件、
/// 不生成尺寸信息，界面按「无法内嵌预览」处理，绝不假装成功。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plain/core/constants/app_constants.dart';

/// 落盘结果。
class StoredAttachmentFile {
  const StoredAttachmentFile({
    required this.storedName,
    required this.sizeBytes,
    this.thumbnailName,
    this.width,
    this.height,
  });

  final String storedName;
  final int sizeBytes;
  final String? thumbnailName;
  final int? width;
  final int? height;
}

/// 存储失败（空间不足等）。
class AttachmentStorageException implements Exception {
  const AttachmentStorageException(this.code);
  final String code;
  @override
  String toString() => 'AttachmentStorageException($code)';
}

class AttachmentStore {
  AttachmentStore({Directory? root}) : _root = root;

  /// 目录名（App 文档目录下）。
  static const String dirName = 'attachments';

  Directory? _root;

  Future<Directory> _dir() async {
    var d = _root;
    if (d == null) {
      final docs = await getApplicationDocumentsDirectory();
      d = Directory(p.join(docs.path, dirName));
      _root = d;
    }
    if (!d.existsSync()) {
      try {
        await d.create(recursive: true);
      } on FileSystemException catch (e) {
        throw AttachmentStorageException('attachment.mkdir_failed: ${e.message}');
      }
    }
    return d;
  }

  /// 附件目录（供备份打包使用）。
  Future<Directory> directory() => _dir();

  Future<File> fileOf(String storedName) async => File(p.join((await _dir()).path, storedName));

  /// 把 [sourcePath]（相册/文件选择器给的临时文件）导入附件目录。
  ///
  /// [mime] 决定是否做图片处理；[thumbnailOnly] 用于「存储不足，仅保存缩略图」。
  Future<StoredAttachmentFile> importFile({
    required String sourcePath,
    required String id,
    required String mime,
    bool thumbnailOnly = false,
  }) async {
    final dir = await _dir();
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const AttachmentStorageException('attachment.source_missing');
    }
    final ext = _extensionOf(sourcePath);
    final isImage = AttachmentRules.isImage(mime);

    List<int>? raw;
    try {
      raw = await source.readAsBytes();
    } on FileSystemException catch (e) {
      throw AttachmentStorageException('attachment.read_failed: ${e.message}');
    }

    // 图片：压到长边 2048（PRD 明确），并另存缩略图
    if (isImage && !thumbnailOnly) {
      final compressed = await _resize(raw, AttachmentRules.compressLongSide);
      if (compressed != null) raw = compressed;
    }

    final storedName = '$id.$ext';
    try {
      if (thumbnailOnly && isImage) {
        final thumb = await _resize(raw, AttachmentRules.thumbnailLongSide);
        if (thumb == null) throw const AttachmentStorageException('attachment.no_thumbnail');
        // 仅存缩略图：原图不落盘；扩展名按实际内容给 .png，避免名不符实
        final thumbOnlyName = '$id.thumb.png';
        await File(p.join(dir.path, thumbOnlyName)).writeAsBytes(thumb, flush: true);
        return StoredAttachmentFile(storedName: thumbOnlyName, sizeBytes: thumb.length);
      }
      await File(p.join(dir.path, storedName)).writeAsBytes(raw, flush: true);
    } on FileSystemException catch (e) {
      throw AttachmentStorageException('attachment.storage_full: ${e.message}');
    }

    String? thumbName;
    int? width;
    int? height;
    if (isImage) {
      final size = await _dimensions(raw);
      width = size?.$1;
      height = size?.$2;
      final thumb = await _resize(raw, AttachmentRules.thumbnailLongSide);
      if (thumb != null) {
        thumbName = '$id.thumb.png';
        try {
          await File(p.join(dir.path, thumbName)).writeAsBytes(thumb, flush: true);
        } on FileSystemException {
          thumbName = null; // 缩略图是优化项，失败不影响原件
        }
      }
    }

    return StoredAttachmentFile(
      storedName: storedName,
      sizeBytes: raw.length,
      thumbnailName: thumbName,
      width: width,
      height: height,
    );
  }

  Future<void> delete(String? storedName) async {
    if (storedName == null || storedName.isEmpty) return;
    try {
      final f = await fileOf(storedName);
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // 文件系统能自愈，删不掉不阻断业务
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'bin';
    final ext = path.substring(dot + 1).toLowerCase();
    return AttachmentRules.allowedTypes.containsKey(ext) ? ext : 'bin';
  }

  /// 重采样到长边 [longSide]，返回 PNG 字节；解不开（HEIC 等）返回 null。
  static Future<Uint8List?> _resize(List<int> bytes, int longSide) async {
    try {
      final src = Uint8List.fromList(bytes);
      final buffer = await ui.ImmutableBuffer.fromUint8List(src);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) return null;
      final scale = w >= h ? longSide / w : longSide / h;
      // 已经比目标小就不放大（避免糊成一块）
      final targetW = scale >= 1 ? w : (w * scale).round().clamp(1, longSide);
      final targetH = scale >= 1 ? h : (h * scale).round().clamp(1, longSide);
      final codec = await descriptor.instantiateCodec(
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      if (data == null) return null;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      // 解不开（HEIC、或运行环境没有真实解码器）→ 保留原件，不阻断导入
      return null;
    }
  }

  /// 读原图尺寸（像素）；解不开返回 null。
  static Future<(int, int)?> _dimensions(List<int> bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(bytes));
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      descriptor.dispose();
      if (w <= 0 || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }
}
