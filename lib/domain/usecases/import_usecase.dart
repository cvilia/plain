/// CSV import use case: parse → dedup → batch insert. PRD F7.5.
library;

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/csv_importer.dart';

class ImportCsvUseCase {
  ImportCsvUseCase({
    required LedgerRepository repository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _repository = repository, _clock = clock, _idGen = idGen;

  final LedgerRepository _repository;
  final Clock _clock;
  final UuidV7 _idGen;

  /// Import CSV text with the given column mapping.
  /// [resolveCategoryId] maps a category name to an existing category id (or null).
  Future<Result<ImportReport>> call({
    required String csvText,
    required CsvColumnMapping mapping,
    required String bookId,
    required String deviceId,
    String? defaultAccountId,
    String? Function(String categoryName)? resolveCategoryId,
    int skipHeaderRows = 1,
  }) async {
    final rows = parseCsv(csvText);
    if (rows.length <= skipHeaderRows) {
      return err<ImportReport>(const ValidationFailure('import.empty', 'no data rows'));
    }

    final parsed = parseRows(rows, mapping, skipHeaderRows: skipHeaderRows);
    if (parsed.entries.isEmpty) {
      return err<ImportReport>(ValidationFailure('import.no_valid_rows', parsed.errors.join('; ')));
    }

    // Build fingerprint range from parsed entries
    var minMs = parsed.entries.first.occurredAt.millisecondsSinceEpoch;
    var maxMs = minMs;
    for (final e in parsed.entries) {
      final ms = e.occurredAt.millisecondsSinceEpoch;
      if (ms < minMs) minMs = ms;
      if (ms > maxMs) maxMs = ms;
    }

    final fpResult = await _repository.fingerprintsInRange(fromMs: minMs, toMs: maxMs);
    final existing = fpResult.successOrNull ?? <String>{};

    final deduped = dedupEntries(parsed.entries, existing);
    final now = _clock.now();
    final importedIds = <String>[];
    var failed = 0;
    final errors = List<String>.from(parsed.errors);

    for (final p in deduped.unique) {
      final categoryId = p.categoryName != null
          ? (resolveCategoryId?.call(p.categoryName!) ?? null)
          : null;
      final entry = parsedToLedgerEntry(
        p,
        id: _idGen.generate(at: p.occurredAt),
        bookId: bookId,
        deviceId: deviceId,
        categoryId: categoryId,
        accountId: defaultAccountId,
        now: now,
      );
      final result = await _repository.create(entry);
      if (result.isSuccess) {
        importedIds.add(entry.id);
      } else {
        failed++;
        errors.add('导入失败: ${p.fingerprint}');
      }
    }

    return ok(ImportReport(
      successCount: importedIds.length,
      dedupedCount: deduped.dedupedCount,
      failedCount: failed,
      errors: errors,
      importedIds: importedIds,
    ));
  }
}
