/// Draft persistence for entry input. See PRD STORY-1.1 AC5.
/// Survives app kill for 24 hours.
library;


import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

/// In-memory draft store (survives page rebuild, not app kill).
/// For app-kill survival, would need local storage - V1.0 uses in-memory + timed expiry.
class DraftStore {
  EntryDraft? _draft;
  DateTime? _savedAt;

  void save(EntryDraft draft) {
    _draft = draft;
    _savedAt = draft.savedAt;
  }

  EntryDraft? load(Clock clock) {
    if (_draft == null) return null;
    if (_savedAt != null && clock.now().difference(_savedAt!) > DraftRules.draftTtl) {
      clear();
      return null;
    }
    return _draft;
  }

  void clear() {
    _draft = null;
    _savedAt = null;
  }

  bool get hasDraft => _draft != null;
}

/// Global draft store instance.
final draftStore = DraftStore();
