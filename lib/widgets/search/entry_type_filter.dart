import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
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
    final enableEvents =
        ref.watch(configFlagProvider(enableEventsFlag)).value ?? false;
    final enableHabits =
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
    final enableDashboards =
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;

    final filteredEntryTypes = computeAllowedEntryTypes(
      events: enableEvents,
      habits: enableHabits,
      dashboards: enableDashboards,
    );

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Wrap(
          runSpacing: 10,
          spacing: 5,
          children: [
            ...filteredEntryTypes.map(EntryTypeChip.new),
            EntryTypeAllChip(filteredEntryTypes: filteredEntryTypes),
            const SizedBox(width: 5),
          ],
        );
      },
    );
  }
}

class EntryTypeChip extends StatelessWidget {
  const EntryTypeChip(
    this.entryType, {
    super.key,
  });

  final String entryType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        final isSelected = snapshot.selectedEntryTypes.contains(entryType);

        void onTap() {
          cubit.toggleSelectedEntryTypes(entryType);
          HapticFeedback.heavyImpact();
        }

        void onLongPress() {
          cubit.selectSingleEntryType(entryType);
          HapticFeedback.heavyImpact();
        }

        return FilterChoiceChip(
          label: _entryTypeLabel(context, entryType),
          isSelected: isSelected,
          onTap: onTap,
          onLongPress: onLongPress,
          selectedColor: context.colorScheme.secondary,
        );
      },
    );
  }
}

class EntryTypeAllChip extends StatelessWidget {
  const EntryTypeAllChip({
    required this.filteredEntryTypes,
    super.key,
  });

  final List<String> filteredEntryTypes;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        final isSelected = setsEqual(
          snapshot.selectedEntryTypes.toSet(),
          filteredEntryTypes.toSet(),
        );

        void onTap() {
          if (isSelected) {
            cubit.clearSelectedEntryTypes();
          } else {
            cubit.selectAllEntryTypes(filteredEntryTypes);
          }
          HapticFeedback.heavyImpact();
        }

        return FilterChoiceChip(
          label: context.messages.taskStatusAll,
          isSelected: isSelected,
          onTap: onTap,
          selectedColor: context.colorScheme.secondary,
        );
      },
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
