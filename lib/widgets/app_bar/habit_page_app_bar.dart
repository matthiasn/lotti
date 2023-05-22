import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/habits/habits_filter.dart';
import 'package:lotti/widgets/habits/status_segmented_control.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HabitStatusSegmentedControl(
                  filter: state.displayFilter,
                  onValueChanged: cubit.setDisplayFilter,
                ),
                const HabitsFilter(),
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
                SettingsButton('/settings/habits/search/${state.searchString}'),
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
