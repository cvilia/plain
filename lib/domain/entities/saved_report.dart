/// STORY-11.3「我的报表」——保存下来的交叉分析配置。
library;

import 'package:plain/domain/entities/enums.dart';

class SavedReport {
  const SavedReport({
    required this.id,
    required this.bookId,
    required this.name,
    required this.rowDim,
    required this.colDim,
    required this.fromMs,
    required this.toMs,
    this.entryFilter = ReportEntryFilter.expense,
    this.heatmap = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String name;
  final CrossDimension rowDim;
  final CrossDimension colDim;

  /// 时间范围（UTC 毫秒，左闭右开）。
  final int fromMs;
  final int toMs;
  final ReportEntryFilter entryFilter;

  /// 是否开启热力着色。
  final bool heatmap;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  DateTime get from => DateTime.fromMillisecondsSinceEpoch(fromMs, isUtc: true);
  DateTime get to => DateTime.fromMillisecondsSinceEpoch(toMs, isUtc: true);

  /// 一句话描述这个组合（列表里直接可读）。
  String get describe =>
      '行 ${rowDim.label} × 列 ${colDim.label} · ${entryFilter.label}';

  SavedReport copyWith({
    String? name,
    CrossDimension? rowDim,
    CrossDimension? colDim,
    int? fromMs,
    int? toMs,
    ReportEntryFilter? entryFilter,
    bool? heatmap,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) =>
      SavedReport(
        id: id,
        bookId: bookId,
        name: name ?? this.name,
        rowDim: rowDim ?? this.rowDim,
        colDim: colDim ?? this.colDim,
        fromMs: fromMs ?? this.fromMs,
        toMs: toMs ?? this.toMs,
        entryFilter: entryFilter ?? this.entryFilter,
        heatmap: heatmap ?? this.heatmap,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is SavedReport && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
