import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:quiver/collection.dart';

class EntryTypeFilter extends StatelessWidget {
  const EntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Wrap(
          runSpacing: 10,
          spacing: 5,
          children: [
            ...entryTypes.map(EntryTypeChip.new),
            const EntryTypeAllChip(),
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
  const EntryTypeAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        final isSelected = setsEqual(
          snapshot.selectedEntryTypes.toSet(),
          entryTypes.toSet(),
        );

        void onTap() {
          if (isSelected) {
            cubit.clearSelectedEntryTypes();
          } else {
            cubit.selectAllEntryTypes();
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

final entryTypeDisplayNames = {
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
};
