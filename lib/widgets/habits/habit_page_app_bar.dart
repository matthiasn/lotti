import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/habits/habits_filter.dart';
import 'package:lotti/widgets/habits/status_segmented_control.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitsSliverTitleBar extends StatelessWidget {
  const HabitsSliverTitleBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SliverAppBar(
      backgroundColor: styleConfig().negspace,
      expandedHeight: 100,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          localizations.settingsHabitsTitle,
          style: appBarTextStyleNewLarge(),
        ),
      ),
    );
  }
}

class HabitsSliverAppBar extends StatelessWidget {
  const HabitsSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();

        return SliverAppBar(
          backgroundColor: styleConfig().negspace,
          expandedHeight: 250,
          primary: false,
          title: Wrap(
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HabitStatusSegmentedControl(
                filter: state.displayFilter,
                onValueChanged: cubit.setDisplayFilter,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: cubit.toggleShowSearch,
                    icon: Icon(
                      Icons.search,
                      color: state.showSearch
                          ? styleConfig().primaryColor
                          : styleConfig().secondaryTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: cubit.toggleShowTimeSpan,
                    icon: Icon(
                      Icons.calendar_month,
                      color: state.showTimeSpan
                          ? styleConfig().primaryColor
                          : styleConfig().secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const HabitsFilter(),
                  if (state.minY > 20)
                    IconButton(
                      onPressed: cubit.toggleZeroBased,
                      icon: Icon(
                        state.zeroBased
                            ? MdiIcons.unfoldLessHorizontal
                            : MdiIcons.unfoldMoreHorizontal,
                        color: styleConfig().secondaryTextColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pinned: true,
          automaticallyImplyLeading: false,
          flexibleSpace: const FlexibleSpaceBar(
            background: Padding(
              padding: EdgeInsets.only(top: 70),
              child: HabitCompletionRateChart(),
            ),
          ),
        );
      },
    );
  }
}
