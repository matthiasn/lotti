import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

class EntryTypeFilter extends ConsumerWidget {
  const EntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableEventsAsync = ref.watch(configFlagProvider(enableEventsFlag));

    return enableEventsAsync.when(
      data: (enableEvents) {
        final filteredEntryTypes = enableEvents
            ? entryTypes
            : entryTypes.where((type) => type != 'JournalEvent').toList();

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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
          label: entryTypeDisplayNames[entryType] ?? '',
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
          label: 'All',
          isSelected: isSelected,
          onTap: onTap,
          selectedColor: context.colorScheme.secondary,
        );
      },
    );
  }
}

const entryTypeDisplayNames = {
  'Task': 'Task',
  'JournalEntry': 'Text',
  'JournalEvent': 'Event',
  'JournalAudio': 'Audio',
  'JournalImage': 'Photo',
  'MeasurementEntry': 'Measured',
  'SurveyEntry': 'Survey',
  'WorkoutEntry': 'Workout',
  'HabitCompletionEntry': 'Habit',
  'QuantitativeEntry': 'Health',
  'Checklist': 'Checklist',
  'ChecklistItem': 'ChecklistItem',
  'AiResponse': 'AI Response',
};
