import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/util/entry_type_icon.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:quiver/collection.dart';

/// Entry-type multi-select for the logbook filter. Renders the same
/// design-system choice pills the tasks filter uses, each carrying the type's
/// feed glyph so the filter and the list share one visual vocabulary.
class EntryTypeFilter extends ConsumerWidget {
  const EntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableEventsAsync = ref.watch(configFlagProvider(enableEventsFlag));
    final enableHabitsAsync = ref.watch(
      configFlagProvider(enableHabitsPageFlag),
    );
    final enableDashboardsAsync = ref.watch(
      configFlagProvider(enableDashboardsPageFlag),
    );

    // Use unwrapPrevious to keep previous value during loading/error states
    // Default to false (hide features) on initial load with no previous value
    final enableEvents =
        enableEventsAsync.unwrapPrevious().whenData((value) => value).value ??
        false;
    final enableHabits =
        enableHabitsAsync.unwrapPrevious().whenData((value) => value).value ??
        false;
    final enableDashboards =
        enableDashboardsAsync
            .unwrapPrevious()
            .whenData((value) => value)
            .value ??
        false;

    final filteredEntryTypes = computeAllowedEntryTypes(
      events: enableEvents,
      habits: enableHabits,
      dashboards: enableDashboards,
    );

    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final textStyle = tokens.typography.styles.body.bodyMedium;

    return Wrap(
      runSpacing: tokens.spacing.step2,
      spacing: tokens.spacing.step2,
      children: [
        ...filteredEntryTypes.map(
          (type) => EntryTypeChip(
            type,
            palette: palette,
            textStyle: textStyle,
          ),
        ),
        EntryTypeAllChip(
          filteredEntryTypes: filteredEntryTypes,
          palette: palette,
          textStyle: textStyle,
        ),
      ],
    );
  }
}

class EntryTypeChip extends ConsumerWidget {
  const EntryTypeChip(
    this.entryType, {
    required this.palette,
    required this.textStyle,
    super.key,
  });

  final String entryType;
  final DesignSystemFilterPalette palette;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    final isSelected = state.selectedEntryTypes.contains(entryType);

    void onTap() {
      controller.toggleSelectedEntryTypes(entryType);
      HapticFeedback.heavyImpact();
    }

    void onLongPress() {
      controller.selectSingleEntryType(entryType);
      HapticFeedback.heavyImpact();
    }

    return DesignSystemFilterChoicePill(
      label: _entryTypeLabel(context, entryType),
      selected: isSelected,
      palette: palette,
      textStyle: textStyle,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Icon(
        entryTypeIcon(entryType),
        size: 16,
        color: isSelected ? palette.accent : palette.secondaryText,
      ),
    );
  }
}

class EntryTypeAllChip extends ConsumerWidget {
  const EntryTypeAllChip({
    required this.filteredEntryTypes,
    required this.palette,
    required this.textStyle,
    super.key,
  });

  final List<String> filteredEntryTypes;
  final DesignSystemFilterPalette palette;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    final isSelected = setsEqual(
      state.selectedEntryTypes.toSet(),
      filteredEntryTypes.toSet(),
    );

    void onTap() {
      if (isSelected) {
        controller.clearSelectedEntryTypes();
      } else {
        controller.selectAllEntryTypes(filteredEntryTypes);
      }
      HapticFeedback.heavyImpact();
    }

    return DesignSystemFilterChoicePill(
      label: context.messages.taskStatusAll,
      selected: isSelected,
      palette: palette,
      textStyle: textStyle,
      onTap: onTap,
    );
  }
}

String _entryTypeLabel(BuildContext context, String type) {
  final labels = <String, String>{
    'Task': context.messages.entryTypeLabelTask,
    'JournalEntry': context.messages.entryTypeLabelJournalEntry,
    'JournalEvent': context.messages.entryTypeLabelJournalEvent,
    'JournalAudio': context.messages.entryTypeLabelJournalAudio,
    'JournalImage': context.messages.entryTypeLabelJournalImage,
    'MeasurementEntry': context.messages.entryTypeLabelMeasurementEntry,
    'SurveyEntry': context.messages.entryTypeLabelSurveyEntry,
    'WorkoutEntry': context.messages.entryTypeLabelWorkoutEntry,
    'HabitCompletionEntry': context.messages.entryTypeLabelHabitCompletionEntry,
    'QuantitativeEntry': context.messages.entryTypeLabelQuantitativeEntry,
    'Checklist': context.messages.entryTypeLabelChecklist,
    'ChecklistItem': context.messages.entryTypeLabelChecklistItem,
    'AiResponse': context.messages.entryTypeLabelAiResponse,
  };
  return labels[type] ?? '';
}
