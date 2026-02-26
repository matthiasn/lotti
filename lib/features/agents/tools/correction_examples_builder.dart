import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';

/// Builds correction examples context for injection into agent prompts.
///
/// Resolves the task's category, fetches its correction examples, sorts
/// by recency, caps at [maxExamples], and formats as a markdown section
/// the agent can reference when editing checklist items.
class CorrectionExamplesBuilder {
  CorrectionExamplesBuilder._();

  /// Maximum number of correction examples to inject into the agent context.
  static const maxExamples = 50;

  /// Builds the correction examples section for the user message.
  ///
  /// Returns an empty string if the task has no category, the category has
  /// no correction examples, or any lookup fails.
  static Future<String> buildContext({
    required Task task,
    required JournalDb journalDb,
  }) async {
    final categoryId = task.meta.categoryId;
    if (categoryId == null) return '';

    try {
      final category = await journalDb.getCategoryById(categoryId);
      if (category == null) return '';
      return formatExamples(category.correctionExamples);
    } catch (_) {
      return '';
    }
  }

  /// Formats a list of correction examples into a markdown section.
  ///
  /// Sorts by [ChecklistCorrectionExample.capturedAt] descending (most
  /// recent first), caps at [maxExamples], and escapes double quotes.
  ///
  /// Returns an empty string if [examples] is null or empty.
  static String formatExamples(
    List<ChecklistCorrectionExample>? examples,
  ) {
    if (examples == null || examples.isEmpty) return '';

    // Sort by capturedAt descending (most recent first), cap at limit.
    final sorted = [...examples]..sort((a, b) {
        final aTime = a.capturedAt ?? DateTime(2000);
        final bTime = b.capturedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
    final capped = sorted.take(maxExamples);

    final buffer = StringBuffer()
      ..writeln('## Correction Examples (for this category)')
      ..writeln(
        'Use these as reference for fixing transcription errors in '
        'checklist items:',
      );

    for (final e in capped) {
      final escapedBefore = e.before.replaceAll('"', r'\"');
      final escapedAfter = e.after.replaceAll('"', r'\"');
      buffer.writeln('- "$escapedBefore" → "$escapedAfter"');
    }

    buffer.writeln();
    return buffer.toString();
  }
}
