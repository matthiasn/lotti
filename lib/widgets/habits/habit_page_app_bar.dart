import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';

class HabitsPageAppBar extends StatelessWidget with PreferredSizeWidget {
  const HabitsPageAppBar({
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 120);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.settingsHabitsTitle;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: styleConfig().negspace,
      elevation: 0,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 100,
      bottom: const HabitCompletionRateChart(),
      title: Text(title, style: appBarTextStyleNewLarge()),
      centerTitle: true,
    );
  }
}
