import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class ConflictListItem extends StatelessWidget {
  const ConflictListItem({
    required this.conflict,
    this.onTap,
    super.key,
  });

  final Conflict conflict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = ConflictStatus.values[conflict.status];
    final statusLabel = _statusLabel(context, status);
    final statusColor = _statusColor(context, status);
    final statusIcon = _statusIcon(status);

    final entity = fromSerialized(conflict.serialized);
    final entityLabel = _entityLabel(context, entity.runtimeType.toString());
    final vectorClock = entity.meta.vectorClock.toString();

    return Semantics(
      label:
          '$statusLabel conflict from ${df.format(conflict.createdAt)} for $entityLabel',
      child: ModernBaseCard(
        onTap: onTap,
        child: ModernCardContent(
          leading: ModernIconContainer(
            icon: statusIcon,
            iconColor: statusColor,
          ),
          title: df.format(conflict.createdAt),
          trailing:
              onTap == null ? null : const Icon(Icons.chevron_right_rounded),
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernStatusChip(
                label: statusLabel,
                color: statusColor,
                icon: status == ConflictStatus.resolved
                    ? Icons.verified_rounded
                    : Icons.report_rounded,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                '${context.messages.conflictEntityLabel}: $entityLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                '${context.messages.conflictIdLabel}: ${conflict.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: AppTheme.alphaSurfaceVariant),
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                vectorClock,
                style: monoTabularStyle(fontSize: fontSizeSmall).copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: AppTheme.alphaSurfaceVariant),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(BuildContext context, ConflictStatus status) {
    final locale = Localizations.localeOf(context).toString();
    final base = status == ConflictStatus.resolved
        ? context.messages.conflictsResolved
        : context.messages.conflictsUnresolved;
    return _titleCaseMessage(base, locale);
  }

  static Color _statusColor(BuildContext context, ConflictStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return status == ConflictStatus.resolved ? scheme.primary : scheme.error;
  }

  static IconData _statusIcon(ConflictStatus status) {
    return status == ConflictStatus.resolved
        ? Icons.verified_user_outlined
        : Icons.report_problem_outlined;
  }

  static String _entityLabel(BuildContext context, String type) {
    final map = <String, String>{
      'Task': context.messages.entryTypeLabelTask,
      'JournalEntry': context.messages.entryTypeLabelJournalEntry,
      'JournalEvent': context.messages.entryTypeLabelJournalEvent,
      'JournalAudio': context.messages.entryTypeLabelJournalAudio,
      'JournalImage': context.messages.entryTypeLabelJournalImage,
      'MeasurementEntry': context.messages.entryTypeLabelMeasurementEntry,
      'SurveyEntry': context.messages.entryTypeLabelSurveyEntry,
      'WorkoutEntry': context.messages.entryTypeLabelWorkoutEntry,
      'HabitCompletionEntry':
          context.messages.entryTypeLabelHabitCompletionEntry,
      'QuantitativeEntry': context.messages.entryTypeLabelQuantitativeEntry,
      'Checklist': context.messages.entryTypeLabelChecklist,
      'ChecklistItem': context.messages.entryTypeLabelChecklistItem,
      'AiResponse': context.messages.entryTypeLabelAiResponse,
    };
    return map[type] ?? type;
  }

  static String _titleCaseMessage(String value, String locale) {
    return toBeginningOfSentenceCase(value, locale) ?? value;
  }
}
