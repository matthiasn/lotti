import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ConflictListItemViewModel {
  const ConflictListItemViewModel({
    required this.timestampLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.statusChipIcon,
    required this.entityLabel,
    required this.conflictIdValue,
    required this.vectorClockLabel,
    required this.semanticsLabel,
  });

  factory ConflictListItemViewModel.fromConflict({
    required BuildContext context,
    required Conflict conflict,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final messages = context.messages;
    final theme = Theme.of(context);
    final status = ConflictStatus.values[conflict.status];

    final timestamp = df.format(conflict.createdAt);
    final statusLabel = _titleCase(
      status == ConflictStatus.resolved
          ? messages.conflictsResolved
          : messages.conflictsUnresolved,
      locale,
    );

    final statusColor = status == ConflictStatus.resolved
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    final statusIcon = status == ConflictStatus.resolved
        ? Icons.verified_user_outlined
        : Icons.report_problem_outlined;
    final statusChipIcon = status == ConflictStatus.resolved
        ? Icons.verified_rounded
        : Icons.report_rounded;

    final entity = fromSerialized(conflict.serialized);
    final entityLabel = _entityLabel(
      context: context,
      type: entity.runtimeType.toString(),
    );

    final vectorClockLabel = entity.meta.vectorClock.toString();

    final semantics = '$statusLabel, $timestamp, $entityLabel';

    return ConflictListItemViewModel(
      timestampLabel: timestamp,
      statusLabel: statusLabel,
      statusColor: statusColor,
      statusIcon: statusIcon,
      statusChipIcon: statusChipIcon,
      entityLabel: entityLabel,
      conflictIdValue: conflict.id,
      vectorClockLabel: vectorClockLabel,
      semanticsLabel: semantics,
    );
  }

  final String timestampLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final IconData statusChipIcon;
  final String entityLabel;
  final String conflictIdValue;
  final String vectorClockLabel;
  final String semanticsLabel;

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
      'AiResponse': messages.entryTypeLabelAiResponse,
    };
    return map[type] ?? type;
  }

  static String _titleCase(String value, String locale) {
    return toBeginningOfSentenceCase(value, locale);
  }
}
