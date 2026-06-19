import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Which side of a conflict an entry belongs to: the version currently in the
/// journal ([local]) or the incoming version recorded on the conflict row
/// ([remote]).
enum ConflictSide { local, remote }

// --- Pure helpers (no Flutter context) -------------------------------------

Duration? audioDuration(JournalEntity entity) {
  return switch (entity) {
    JournalAudio(:final data) => data.duration,
    _ => null,
  };
}

int maxCounter(VectorClock? clock) {
  if (clock == null || clock.vclock.isEmpty) return 0;
  return clock.vclock.values.reduce((a, b) => a > b ? a : b);
}

String formatDuration(Duration duration) {
  final total = duration.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

/// Maps the freezed sealed-type to a localized human label. Pattern-matches on
/// the entity itself so the analyzer's `switch_on_type` lint stays happy and a
/// new entity type triggers a missing-case warning.
String entityTypeLabel(JournalEntity entity, AppLocalizations messages) {
  return switch (entity) {
    Task() => messages.entryTypeLabelTask,
    JournalEntry() => messages.entryTypeLabelJournalEntry,
    JournalEvent() => messages.entryTypeLabelJournalEvent,
    JournalAudio() => messages.entryTypeLabelJournalAudio,
    JournalImage() => messages.entryTypeLabelJournalImage,
    MeasurementEntry() => messages.entryTypeLabelMeasurementEntry,
    SurveyEntry() => messages.entryTypeLabelSurveyEntry,
    WorkoutEntry() => messages.entryTypeLabelWorkoutEntry,
    HabitCompletionEntry() => messages.entryTypeLabelHabitCompletionEntry,
    QuantitativeEntry() => messages.entryTypeLabelQuantitativeEntry,
    Checklist() => messages.entryTypeLabelChecklist,
    ChecklistItem() => messages.entryTypeLabelChecklistItem,
    _ => entity.runtimeType.toString(),
  };
}
