/// Note-based category suggestion (rule-based, not AI).
/// See PRD STORY-1.3 AC4: note "瑞幸" → suggest category from history.
library;


/// Suggestion result.
class CategorySuggestion {
  const CategorySuggestion({required this.categoryId, required this.confidence});

  final String categoryId;

  /// 0.0 to 1.0 based on match frequency.
  final double confidence;
}

/// Rule engine: match note keywords to historical category usage.
class CategorySuggester {
  /// Suggest a category based on note text and historical data.
  /// [history] maps note keywords to category IDs (from past entries).
  static CategorySuggestion? suggest({
    required String note,
    required Map<String, String> keywordToCategory,
  }) {
    if (note.trim().isEmpty) return null;
    final normalizedNote = note.trim().toLowerCase();

    // Exact match first
    for (final entry in keywordToCategory.entries) {
      if (normalizedNote == entry.key.toLowerCase()) {
        return CategorySuggestion(categoryId: entry.value, confidence: 1.0);
      }
    }

    // Contains match
    String? bestMatch;
    var bestScore = 0.0;
    for (final entry in keywordToCategory.entries) {
      final keyword = entry.key.toLowerCase();
      if (normalizedNote.contains(keyword)) {
        final score = keyword.length / normalizedNote.length;
        if (score > bestScore) {
          bestScore = score;
          bestMatch = entry.value;
        }
      }
    }

    if (bestMatch != null) {
      return CategorySuggestion(categoryId: bestMatch, confidence: bestScore);
    }

    return null;
  }
}
