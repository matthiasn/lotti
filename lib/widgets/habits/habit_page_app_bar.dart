import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';

class HabitsPageAppBar extends StatelessWidget with PreferredSizeWidget {
  HabitsPageAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 130);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.settingsHabitsTitle;

    return Column(
      children: [
        TitleAppBar(title: title, showBackButton: false),
        const HabitCompletionRateChart(),
      ],
    );
  }
}
