import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/segmented_control.dart';

class HabitStatusSegmentedControl extends StatelessWidget {
  const HabitStatusSegmentedControl({
    required this.filter,
    required this.onValueChanged,
    super.key,
  });

  final HabitDisplayFilter filter;
  final void Function(HabitDisplayFilter) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return CupertinoSegmentedControl<HabitDisplayFilter>(
      selectedColor: styleConfig().primaryColor,
      unselectedColor: styleConfig().negspace,
      borderColor: styleConfig().primaryColor,
      groupValue: filter,
      onValueChanged: onValueChanged,
      children: {
        HabitDisplayFilter.openNow: TextSegment(
          localizations.habitsFilterOpenNow,
          semanticsLabel: 'Habits - due',
        ),
        HabitDisplayFilter.pendingLater: TextSegment(
          localizations.habitsFilterPendingLater,
          semanticsLabel: 'Habits - later',
        ),
        HabitDisplayFilter.completed: TextSegment(
          localizations.habitsFilterCompleted,
          semanticsLabel: 'Habits - done',
        ),
        HabitDisplayFilter.all: TextSegment(localizations.habitsFilterAll),
      },
    );
  }
}
