import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

class EntryTypeFilter extends ConsumerWidget {
  const EntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableEventsAsync = ref.watch(configFlagProvider(enableEventsFlag));
    final enableHabitsAsync =
        ref.watch(configFlagProvider(enableHabitsPageFlag));
    final enableDashboardsAsync =
        ref.watch(configFlagProvider(enableDashboardsPageFlag));

    // Use unwrapPrevious to keep previous value during loading/error states
    // Default to false (hide features) on initial load with no previous value
    final enableEvents = enableEventsAsync
            .unwrapPrevious()
            .whenData((value) => value)
            .valueOrNull ??
        false;
    final enableHabits = enableHabitsAsync
            .unwrapPrevious()
            .whenData((value) => value)
            .valueOrNull ??
        false;
    final enableDashboards = enableDashboardsAsync
            .unwrapPrevious()
            .whenData((value) => value)
            .valueOrNull ??
        false;

    final filteredEntryTypes = computeAllowedEntryTypes(
      events: enableEvents,
      habits: enableHabits,
      dashboards: enableDashboards,
    );

    return Wrap(
      runSpacing: 10,
      spacing: 5,
      children: [
        ...filteredEntryTypes.map(EntryTypeChip.new),
        EntryTypeAllChip(filteredEntryTypes: filteredEntryTypes),
        const SizedBox(width: 5),
      ],
    );
  }
}

class EntryTypeChip extends ConsumerWidget {
  const EntryTypeChip(
    this.entryType, {
    super.key,
  });

  final String entryType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    final isSelected = state.selectedEntryTypes.contains(entryType);

    void onTap() {
      controller.toggleSelectedEntryTypes(entryType);
      HapticFeedback.heavyImpact();
    }

    void onLongPress() {
      controller.selectSingleEntryType(entryType);
      HapticFeedback.heavyImpact();
    }

    return FilterChoiceChip(
      label: _entryTypeLabel(context, entryType),
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      selectedColor: context.colorScheme.secondary,
    );
  }
}

class EntryTypeAllChip extends ConsumerWidget {
  const EntryTypeAllChip({
    required this.filteredEntryTypes,
    super.key,
  });

  final List<String> filteredEntryTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

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

    return FilterChoiceChip(
      label: context.messages.taskStatusAll,
      isSelected: isSelected,
      onTap: onTap,
      selectedColor: context.colorScheme.secondary,
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
