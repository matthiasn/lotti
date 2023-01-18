import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitsPageAppBar extends StatelessWidget with PreferredSizeWidget {
  const HabitsPageAppBar({
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 160);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = localizations.settingsHabitsTitle;

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: styleConfig().negspace,
          elevation: 0,
          scrolledUnderElevation: 10,
          titleSpacing: 0,
          leadingWidth: 100,
          bottom: const HabitCompletionRateChart(),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Spacer(),
              Text(title, style: appBarTextStyleNewLarge()),
              const Spacer(),
              Opacity(
                opacity: state.minY > 0 ? 1 : 0,
                child: GestureDetector(
                  onTap: cubit.toggleZeroBased,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      state.zeroBased
                          ? MdiIcons.unfoldLessHorizontal
                          : MdiIcons.unfoldMoreHorizontal,
                    ),
                  ),
                ),
              )
            ],
          ),
          centerTitle: true,
        );
      },
    );
  }
}
