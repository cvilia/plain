/// CSV import engine: parse, map columns, dedup, convert to entries.
/// Dedup fingerprint = date + amount + merchant/note. See PRD F7.5.
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';

/// Column mapping for a CSV source. Indices are 0-based into each row.
class CsvColumnMapping {
  const CsvColumnMapping({
    required this.dateCol,
    required this.amountCol,
    this.typeCol,
    this.categoryCol,
    this.noteCol,
    this.merchantCol,
    this.incomeMarkers = const ['收入', 'income', '+', '进账', '转入'],
  });

  final int dateCol;
  final int amountCol;
  final int? typeCol;
  final int? categoryCol;
  final int? noteCol;
  final int? merchantCol;
  final List<String> incomeMarkers;
}

/// A single parsed row ready for import.
class ParsedEntry {
  const ParsedEntry({
    required this.occurredAt,
    required this.amountCents,
    required this.type,
    this.categoryName,
    this.note,
    this.merchant,
    required this.fingerprint,
  });

  final DateTime occurredAt;
  final int amountCents;
  final EntryType type;
  final String? categoryName;
  final String? note;
  final String? merchant;
  final String fingerprint;
}

/// Outcome of an import run.
class ImportReport {
  const ImportReport({
    required this.successCount,
    required this.dedupedCount,
    required this.failedCount,
    this.errors = const [],
    this.importedIds = const [],
  });

  final int successCount;
  final int dedupedCount;
  final int failedCount;
  final List<String> errors;
  final List<String> importedIds;
}

/// Parse CSV text into rows (handles quoted fields, CRLF, BOM).
List<List<String>> parseCsv(String text) {
  final cleaned = text.replaceFirst('\uFEFF', '');
  final rows = <List<String>>[];
  var current = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < cleaned.length) {
    final ch = cleaned[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < cleaned.length && cleaned[i + 1] == '"') {
          buf.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      buf.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',') {
      current.add(buf.toString().trim());
      buf.clear();
      i++;
      continue;
    }
    if (ch == '\r') {
      i++;
      continue;
    }
    if (ch == '\n') {
      current.add(buf.toString().trim());
      buf.clear();
      if (current.isNotEmpty && !(current.length == 1 && current.first.isEmpty)) {
        rows.add(current);
      }
      current = <String>[];
      i++;
      continue;
    }
    buf.write(ch);
    i++;
  }
  current.add(buf.toString().trim());
  if (current.isNotEmpty && !(current.length == 1 && current.first.isEmpty)) {
    rows.add(current);
  }
  return rows;
}

/// Try to parse a date string in common formats. Returns null on failure.
DateTime? parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // 2024-01-15 / 2024/01/15 / 2024.01.15
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null) {
    return _tryDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  // 20240115
  m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
  if (m != null) {
    return _tryDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  // 2024年1月15日
  m = RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日?').firstMatch(s);
  if (m != null) {
    return _tryDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  // 01-15 (assume current year)
  m = RegExp(r'^(\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  if (m != null) {
    final now = DateTime.now();
    return _tryDate(now.year, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  return null;
}

DateTime? _tryDate(int y, int mo, int d) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  try {
    return DateTime(y, mo, d);
  } on FormatException {
    return null;
  }
}

/// Parse an amount string to cents. Handles ¥, 元, commas, parentheses.
/// Returns null on failure. Sign is preserved (negative = expense by convention).
int? parseAmountCents(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  // Strip currency symbols and units
  s = s.replaceAll(RegExp(r'[¥￥$,，元圆]'), '');
  s = s.replaceAll(RegExp(r'\s'), '');

  // (25.00) means negative
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }

  if (s.isEmpty) return null;
  // Must be a number
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;

  final parts = s.split('.');
  final yuan = int.parse(parts[0]);
  var cents = 0;
  if (parts.length > 1) {
    var frac = parts[1];
    if (frac.length > 2) frac = frac.substring(0, 2);
    while (frac.length < 2) {
      frac = '${frac}0';
    }
    cents = int.parse(frac);
  }
  final total = yuan * 100 + cents;
  return negative ? -total : total;
}

/// 构建去重指纹：日期 + 金额 + 标签 + 币种（+ 可选来源）。
/// 默认不含来源 → 跨来源交叉去重（STORY-9.1 AC6）。
/// [includeSource] 为 true 时指纹附加来源，仅同来源内去重。
String buildFingerprint({
  required DateTime date,
  required int amountCents,
  String? label,
  String currency = 'CNY',
  String? source,
  bool includeSource = false,
}) {
  final dayKey = Clock.dayKeyOf(date);
  final base = '$dayKey|${amountCents.abs()}|${label ?? ''}|$currency';
  if (includeSource && source != null && source.isNotEmpty) {
    return '$base|$source';
  }
  return base;
}

/// Compose the note/label from merchant + note, matching what stored entries carry.
String composeLabel({String? merchant, String? note}) {
  if (merchant != null && merchant.isNotEmpty && note != null && note.isNotEmpty) {
    return '$merchant $note';
  }
  return merchant?.isNotEmpty == true ? merchant! : (note ?? '');
}

/// Parse CSV rows into ParsedEntry list using the given column mapping.
/// Returns (entries, errors). Rows with unparseable date/amount go to errors.
({List<ParsedEntry> entries, List<String> errors}) parseRows(
  List<List<String>> rows,
  CsvColumnMapping mapping, {
  int skipHeaderRows = 1,
}) {
  final entries = <ParsedEntry>[];
  final errors = <String>[];

  for (var i = skipHeaderRows; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((c) => c.isEmpty)) continue;

    final lineNo = i + 1;
    if (row.length <= mapping.amountCol || row.length <= mapping.dateCol) {
      errors.add('第 $lineNo 行: 列数不足');
      continue;
    }

    final date = parseDate(row[mapping.dateCol]);
    if (date == null) {
      errors.add('第 $lineNo 行: 无法解析日期 "${row[mapping.dateCol]}"');
      continue;
    }

    final amountCents = parseAmountCents(row[mapping.amountCol]);
    if (amountCents == null || amountCents == 0) {
      errors.add('第 $lineNo 行: 无法解析金额 "${row[mapping.amountCol]}"');
      continue;
    }

    // Determine type: from type column or amount sign
    var type = EntryType.expense;
    if (mapping.typeCol != null && row.length > mapping.typeCol!) {
      final typeRaw = row[mapping.typeCol!].trim();
      if (mapping.incomeMarkers.any((m) => typeRaw.contains(m))) {
        type = EntryType.income;
      }
    } else if (amountCents > 0) {
      // Positive amount without type column → income (common in bank exports)
      // But many exports use positive for expense too. Default to expense
      // unless the amount is explicitly negative.
      type = EntryType.expense;
    }
    // Negative amount without type column → expense
    if (amountCents < 0) type = EntryType.expense;

    final merchant = mapping.merchantCol != null && row.length > mapping.merchantCol!
        ? row[mapping.merchantCol!].trim()
        : null;
    final note = mapping.noteCol != null && row.length > mapping.noteCol!
        ? row[mapping.noteCol!].trim()
        : null;
    final categoryName = mapping.categoryCol != null && row.length > mapping.categoryCol!
        ? row[mapping.categoryCol!].trim()
        : null;

    final fingerprint = buildFingerprint(
      date: date, amountCents: amountCents, label: composeLabel(merchant: merchant, note: note),
    );

    entries.add(ParsedEntry(
      occurredAt: date,
      amountCents: amountCents.abs(),
      type: type,
      categoryName: categoryName?.isNotEmpty == true ? categoryName : null,
      note: note?.isNotEmpty == true ? note : null,
      merchant: merchant?.isNotEmpty == true ? merchant : null,
      fingerprint: fingerprint,
    ));
  }
  return (entries: entries, errors: errors);
}

/// Dedup parsed entries against a set of existing fingerprints and against each other.
/// Returns (unique, dedupedCount).
({List<ParsedEntry> unique, int dedupedCount}) dedupEntries(
  List<ParsedEntry> entries,
  Set<String> existingFingerprints,
) {
  final seen = Set<String>.from(existingFingerprints);
  final unique = <ParsedEntry>[];
  var deduped = 0;
  for (final e in entries) {
    if (seen.contains(e.fingerprint)) {
      deduped++;
      continue;
    }
    seen.add(e.fingerprint);
    unique.add(e);
  }
  return (unique: unique, dedupedCount: deduped);
}

/// Convert a ParsedEntry to a LedgerEntry ready for repository.create().
LedgerEntry parsedToLedgerEntry(
  ParsedEntry p, {
  required String id,
  required String bookId,
  required String deviceId,
  required String? categoryId,
  String? accountId,
  required DateTime now,
}) {
  // Compose note/label consistently with fingerprint
  final label = composeLabel(merchant: p.merchant, note: p.note);
  final note = label.isEmpty ? null : label;

  return LedgerEntry(
    id: id, bookId: bookId, type: p.type,
    amount: Money(p.amountCents), currency: MoneyRules.defaultCurrency,
    categoryId: categoryId, accountId: accountId,
    occurredAt: p.occurredAt.toUtc(),
    note: note, source: EntrySource.import,
    createdAt: now, updatedAt: now,
    revision: 1, deviceId: deviceId, baseRevision: 0,
  );
}

/// STORY-9.1：常见账单来源的 CSV 列映射预设。
class ImportSourcePresets {
  ImportSourcePresets._();

  /// 支付宝（典型导出列：交易时间 / 交易分类 / 交易对方 / 商品说明 / 金额）
  static const CsvColumnMapping alipay = CsvColumnMapping(
    dateCol: 0,
    amountCol: 4,
    noteCol: 3,
    merchantCol: 2,
    typeCol: 1,
  );

  /// 微信支付（典型：交易时间 / 交易类型 / 交易对方 / 商品 / 收/支 / 金额）
  static const CsvColumnMapping wechat = CsvColumnMapping(
    dateCol: 0,
    amountCol: 5,
    typeCol: 4,
    merchantCol: 2,
    noteCol: 3,
    incomeMarkers: ['收入', '+', '存入'],
  );

  /// 通用：日期、金额
  static const CsvColumnMapping generic = CsvColumnMapping(
    dateCol: 0,
    amountCol: 1,
  );
}
