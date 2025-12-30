import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitsSliverAppBar extends ConsumerWidget {
  const HabitsSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

    return SliverAppBar(
      primary: false,
      toolbarHeight: 240,
      title: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HabitStatusSegmentedControl(
                  filter: state.displayFilter,
                  onValueChanged: controller.setDisplayFilter,
                ),
                const SizedBox(width: 10),
                const HabitsFilter(),
                IconButton(
                  onPressed: controller.toggleShowSearch,
                  icon: Icon(
                    Icons.search,
                    color: state.showSearch
                        ? Theme.of(context).primaryColor
                        : context.colorScheme.outline,
                  ),
                ),
                IconButton(
                  onPressed: controller.toggleShowTimeSpan,
                  icon: Icon(
                    Icons.calendar_month,
                    color: state.showTimeSpan
                        ? Theme.of(context).primaryColor
                        : context.colorScheme.outline,
                  ),
                ),
                if (state.minY > 20)
                  IconButton(
                    onPressed: controller.toggleZeroBased,
                    icon: Icon(
                      state.zeroBased
                          ? MdiIcons.unfoldLessHorizontal
                          : MdiIcons.unfoldMoreHorizontal,
                      color: context.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: HabitCompletionRateChart(),
          ),
        ],
      ),
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }
}
