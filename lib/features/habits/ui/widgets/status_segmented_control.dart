import 'package:flutter/material.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/segmented_button.dart';

class HabitStatusSegmentedControl extends StatelessWidget {
  const HabitStatusSegmentedControl({
    required this.filter,
    required this.onValueChanged,
    super.key,
  });

  final HabitDisplayFilter filter;
  final void Function(HabitDisplayFilter?) onValueChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HabitDisplayFilter>(
      selected: {filter},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onValueChanged(selected.first),
      segments: [
        buttonSegment(
          context: context,
          value: HabitDisplayFilter.openNow,
          selected: filter,
          label: context.messages.habitsFilterOpenNow,
          semanticsLabel: 'Habits - due',
        ),
        buttonSegment(
          context: context,
          value: HabitDisplayFilter.pendingLater,
          selected: filter,
          label: context.messages.habitsFilterPendingLater,
          semanticsLabel: 'Habits - later',
        ),
        buttonSegment(
          context: context,
          value: HabitDisplayFilter.completed,
          selected: filter,
          label: context.messages.habitsFilterCompleted,
          semanticsLabel: 'Habits - done',
        ),
        buttonSegment(
          context: context,
          value: HabitDisplayFilter.all,
          selected: filter,
          label: context.messages.habitsFilterAll,
          semanticsLabel: 'Habits - all',
        ),
      ],
    );
  }
}
