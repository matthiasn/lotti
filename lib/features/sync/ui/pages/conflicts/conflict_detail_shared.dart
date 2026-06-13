import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Stacked vs side-by-side breakpoint for the diff cards. Below this,
/// the picker collapses to a single column and the header pill drops
/// the "fields differ" half.
const double kConflictStackedBreakpoint = 768;

/// Which side of a conflict an entry belongs to.
enum ConflictSide { local, remote }

// --- Pure helpers (no Flutter context) -------------------------------------

String firstLine(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text != null && text.isNotEmpty) return text.split('\n').first;
  return entity.runtimeType.toString();
}

int wordCount(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text == null || text.isEmpty) return 0;
  return text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;
}

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

/// Locale-aware "when did this side last touch the entry" stamp shown
/// in the diff card header. Same-day conflicts render time-only (12h
/// or 24h depending on the locale); older conflicts get a short date
/// prefix so the user can tell e.g. yesterday's edit from today's.
String formatHmsa(DateTime dt, String locale) {
  final now = DateTime.now();
  final isToday =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (isToday) return DateFormat.jms(locale).format(dt);
  return DateFormat.yMd(locale).add_jms().format(dt);
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

String formatTimeAgo(Duration delta, AppLocalizations messages) {
  // A future timestamp can happen on clock skew between sync peers;
  // floor at zero so we never render "0 days ago" for that case.
  final abs = delta.isNegative ? Duration.zero : delta;
  if (abs.inSeconds < 60) return messages.conflictBannerAgoJustNow;
  if (abs.inMinutes < 60) {
    return messages.conflictBannerAgoMinutes(abs.inMinutes);
  }
  if (abs.inHours < 48) {
    return messages.conflictBannerAgoHours(abs.inHours);
  }
  return messages.conflictBannerAgoDays(abs.inDays);
}

/// Maps the freezed sealed-type to a localized human label. Mirrors
/// the mapping used by the conflicts list view-model; pattern-matches
/// on the entity itself so the analyzer's `switch_on_type` lint stays
/// happy and a new entity type triggers a missing-case warning.
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

/// Walks a fixed set of metadata fields and returns a list of
/// localized labels for the ones that differ between the two sides.
/// "Title" is always added when titles differ — it's what the inline
/// diff in the cards is showing — so the banner subline reinforces it.
List<String> differingFieldLabels(
  JournalEntity local,
  JournalEntity remote,
  AppLocalizations messages,
) {
  final fields = <String>[];
  if (firstLine(local) != firstLine(remote)) {
    fields.add(messages.conflictFieldTitle);
  }
  if (wordCount(local) != wordCount(remote)) {
    fields.add(messages.conflictFieldWordCount);
  }
  if (audioDuration(local) != audioDuration(remote)) {
    fields.add(messages.conflictFieldDuration);
  }
  if (local.meta.categoryId != remote.meta.categoryId) {
    fields.add(messages.conflictFieldCategory);
  }
  return fields;
}
