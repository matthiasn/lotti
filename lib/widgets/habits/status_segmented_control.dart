import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
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
    final localizations = AppLocalizations.of(context)!;

    return SegmentedButton<HabitDisplayFilter>(
      selected: {filter},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onValueChanged(selected.first),
      segments: [
        buttonSegment(
          value: HabitDisplayFilter.openNow,
          selected: filter,
          label: localizations.habitsFilterOpenNow,
          semanticsLabel: 'Habits - due',
        ),
        buttonSegment(
          value: HabitDisplayFilter.pendingLater,
          selected: filter,
          label: localizations.habitsFilterPendingLater,
          semanticsLabel: 'Habits - later',
        ),
        buttonSegment(
          value: HabitDisplayFilter.completed,
          selected: filter,
          label: localizations.habitsFilterCompleted,
          semanticsLabel: 'Habits - done',
        ),
        buttonSegment(
          value: HabitDisplayFilter.all,
          selected: filter,
          label: localizations.habitsFilterAll,
          semanticsLabel: 'Habits - all',
        ),
      ],
    );
  }
}
