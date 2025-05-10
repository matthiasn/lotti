import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/features/journal/riverpod/journal_providers.dart';

class RiverpodEntryTypeFilter extends ConsumerWidget {
  const RiverpodEntryTypeFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final filtersNotifier = ref.read(journalFiltersProvider.notifier);
    final selectedEntryTypes = filters.selectedEntryTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entry Types',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 10,
          children: [
            for (final entryType in entryTypes)
              FilterChip(
                label: Text(entryTypeDisplayNames[entryType] ?? entryType),
                selected: selectedEntryTypes.contains(entryType),
                onSelected: (selected) {
                  Set<String> newTypes;
                  if (selected) {
                    newTypes = {...selectedEntryTypes, entryType};
                  } else {
                    newTypes = {...selectedEntryTypes}..remove(entryType);
                  }
                  filtersNotifier.update(
                    (state) => state.copyWith(
                      selectedEntryTypes: newTypes,
                    ),
                  );
                },
              ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                filtersNotifier.update(
                  (state) => state.copyWith(
                    selectedEntryTypes: entryTypes.toSet(),
                  ),
                );
              },
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () {
                filtersNotifier.update(
                  (state) => state.copyWith(
                    selectedEntryTypes: {},
                  ),
                );
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

// Copied from EntryTypeFilter
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
