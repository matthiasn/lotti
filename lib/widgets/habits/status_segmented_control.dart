import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';

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
        ),
        buttonSegment(
          value: HabitDisplayFilter.pendingLater,
          selected: filter,
          label: localizations.habitsFilterPendingLater,
        ),
        buttonSegment(
          value: HabitDisplayFilter.completed,
          selected: filter,
          label: localizations.habitsFilterCompleted,
        ),
        buttonSegment(
          value: HabitDisplayFilter.all,
          selected: filter,
          label: localizations.habitsFilterAll,
        ),
      ],
    );
  }
}

ButtonSegment<HabitDisplayFilter> buttonSegment({
  required HabitDisplayFilter value,
  required HabitDisplayFilter selected,
  required String label,
}) {
  return ButtonSegment(
    value: value,
    label: Text(
      label,
      style: value == selected
          ? buttonLabelStyle().copyWith(color: Colors.black)
          : buttonLabelStyle()
              .copyWith(color: styleConfig().secondaryTextColor),
    ),
  );
}
