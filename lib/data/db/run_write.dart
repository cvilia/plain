/// Shared write-path helper: transaction + Result + storage failure mapping.
///
/// Repositories used to copy-paste
/// `try { _db.transaction(() { ... }); return ok(x); } on Exception catch (e) { ... }`
/// at every create/update/softDelete. This folds the envelope so each site only
/// describes its payload.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';

/// Run [body] inside a transaction and return `ok(result)`.
///
/// [result] is the success value the caller wants to hand back (the entity or
/// `null` for `Result<void>`). Any thrown [Object] becomes a retryable
/// [StorageFailure] tagged with [failCode].
Result<T> runWrite<T>(
  AppDatabase db, {
  required String failCode,
  required T result,
  required void Function() body,
}) {
  try {
    db.transaction(body);
    return ok(result);
  } on Exception catch (e) {
    return err(StorageFailure(failCode, e.toString(), isRetryable: true));
  } on Object catch (e) {
    // Map non-Exception throwables too so callers never see a raw Error.
    return err(StorageFailure(failCode, e.toString(), isRetryable: true));
  }
}
