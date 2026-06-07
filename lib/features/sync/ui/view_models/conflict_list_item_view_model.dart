import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Visual tone for the status badge. Mapped to a `DesignSystemBadgeTone`
/// at the widget layer; kept token-free here so the view model stays a
/// pure data record (no Flutter `Color`/`Icon` baked in).
enum ConflictStatusTone { resolved, unresolved }

/// View model for a single conflicts-list row. Pure data: no Riverpod, no
/// Widgets, no theme `Color` lookups. The widget renders from this.
class ConflictListItemViewModel {
  const ConflictListItemViewModel({
    required this.timestampLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.entityLabel,
    required this.conflictIdFull,
    required this.conflictIdShort,
    required this.semanticsLabel,
  });

  factory ConflictListItemViewModel.fromConflict({
    required BuildContext context,
    required Conflict conflict,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final messages = context.messages;
    final status = ConflictStatus.values[conflict.status];

    final timestamp = df.format(conflict.createdAt);
    final statusLabel = _titleCase(
      status == ConflictStatus.resolved
          ? messages.conflictsResolved
          : messages.conflictsUnresolved,
      locale,
    );
    final statusTone = status == ConflictStatus.resolved
        ? ConflictStatusTone.resolved
        : ConflictStatusTone.unresolved;

    final entity = fromSerialized(conflict.serialized);
    final entityLabel = _entityLabel(
      context: context,
      type: entity.runtimeType.toString(),
    );

    final conflictIdFull = conflict.id;
    final conflictIdShort = shortenConflictId(conflictIdFull);

    final semantics = messages.conflictListItemSemanticsLabel(
      statusLabel,
      timestamp,
      entityLabel,
      conflictIdFull,
    );

    return ConflictListItemViewModel(
      timestampLabel: timestamp,
      statusLabel: statusLabel,
      statusTone: statusTone,
      entityLabel: entityLabel,
      conflictIdFull: conflictIdFull,
      conflictIdShort: conflictIdShort,
      semanticsLabel: semantics,
    );
  }

  final String timestampLabel;
  final String statusLabel;
  final ConflictStatusTone statusTone;
  final String entityLabel;
  final String conflictIdFull;
  final String conflictIdShort;
  final String semanticsLabel;

  /// First 8 characters of [id]; ids of 8 chars or fewer pass through
  /// unchanged. Visible for direct property testing.
  @visibleForTesting
  static String shortenConflictId(String id) =>
      id.length > 8 ? id.substring(0, 8) : id;

  static String _entityLabel({
    required BuildContext context,
    required String type,
  }) {
    final messages = context.messages;
    final map = <String, String>{
      'Task': messages.entryTypeLabelTask,
      'JournalEntry': messages.entryTypeLabelJournalEntry,
      'JournalEvent': messages.entryTypeLabelJournalEvent,
      'JournalAudio': messages.entryTypeLabelJournalAudio,
      'JournalImage': messages.entryTypeLabelJournalImage,
      'MeasurementEntry': messages.entryTypeLabelMeasurementEntry,
      'SurveyEntry': messages.entryTypeLabelSurveyEntry,
      'WorkoutEntry': messages.entryTypeLabelWorkoutEntry,
      'HabitCompletionEntry': messages.entryTypeLabelHabitCompletionEntry,
      'QuantitativeEntry': messages.entryTypeLabelQuantitativeEntry,
      'Checklist': messages.entryTypeLabelChecklist,
      'ChecklistItem': messages.entryTypeLabelChecklistItem,
      'AiResponseEntry': messages.entryTypeLabelAiResponse,
    };
    return map[type] ?? type;
  }

  static String _titleCase(String value, String locale) {
    final String? formatted = toBeginningOfSentenceCase(value, locale);
    return formatted ?? value;
  }
}
