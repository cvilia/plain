/// STORY-1.5 账单附件（小票/凭据）。
///
/// 文件本体在 App 私有目录里（`stored_name` / `thumbnail_name` 是文件名），
/// 本实体只承载元数据。附件**不进云同步**，随备份包一起还原。
library;

class Attachment {
  const Attachment({
    required this.id,
    required this.entryId,
    required this.bookId,
    required this.storedName,
    this.thumbnailName,
    required this.mime,
    required this.sizeBytes,
    this.width,
    this.height,
    this.isOrphan = false,
    this.orphanedAt,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String entryId;
  final String bookId;

  /// 原件文件名（在附件目录内）。
  final String storedName;

  /// 缩略图文件名；为 null 表示没有缩略图。
  final String? thumbnailName;
  final String mime;
  final int sizeBytes;
  final int? width;
  final int? height;

  /// 账单被删除后标记为孤儿；30 天内随回收站恢复而复原。
  final bool isOrphan;
  final DateTime? orphanedAt;

  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isImage => mime.startsWith('image/');

  /// 列表与详情里的可读尺寸（KB 向上取整，0 字节显示 0）。
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = (sizeBytes / 1024).ceil();
    if (kb < 1024) return '$kb KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Attachment copyWith({
    String? storedName,
    String? thumbnailName,
    bool clearThumbnail = false,
    int? sizeBytes,
    int? width,
    int? height,
    bool? isOrphan,
    DateTime? orphanedAt,
    bool clearOrphanedAt = false,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? revision,
    int? baseRevision,
  }) =>
      Attachment(
        id: id,
        entryId: entryId,
        bookId: bookId,
        storedName: storedName ?? this.storedName,
        thumbnailName: clearThumbnail ? null : (thumbnailName ?? this.thumbnailName),
        mime: mime,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        width: width ?? this.width,
        height: height ?? this.height,
        isOrphan: isOrphan ?? this.isOrphan,
        orphanedAt: clearOrphanedAt ? null : (orphanedAt ?? this.orphanedAt),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is Attachment && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
