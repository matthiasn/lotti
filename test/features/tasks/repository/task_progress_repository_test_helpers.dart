import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Builds a [JournalEntry] whose time span runs from [from] to [to].
///
/// Used across the `sumTimeSpentFromEntities` cases so each test only states
/// the id and the interval it cares about instead of re-spelling a full
/// [Metadata] block.
JournalEntry hMakeJournalEntry(String id, DateTime from, DateTime to) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: from,
      dateFrom: from,
      dateTo: to,
      updatedAt: to,
    ),
    entryText: EntryText(plainText: id),
  );
}
