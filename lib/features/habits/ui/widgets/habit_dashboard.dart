import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class SelectDashboardWidget extends StatelessWidget {
  SelectDashboardWidget({super.key});

  final TagsService tagsService = getIt<TagsService>();

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return StreamBuilder<List<DashboardDefinition>>(
      stream: getIt<JournalDb>().watchDashboards(),
      builder: (context, snapshot) {
        final dashboardsById = <String, DashboardDefinition>{};

        final dashboards = filteredSortedDashboards(
          snapshot.data ?? <DashboardDefinition>[],
        );

        for (final dashboard in dashboards) {
          dashboardsById[dashboard.id] = dashboard;
        }

        return BlocBuilder<HabitSettingsCubit, HabitSettingsState>(
          builder: (
            context,
            HabitSettingsState state,
          ) {
            final habitDefinition = state.habitDefinition;
            final dashboard = dashboardsById[habitDefinition.dashboardId];
            final cubit = context.read<HabitSettingsCubit>();

            controller.text = dashboard?.name ?? '';

            void onTap() {
              ModalUtils.showSinglePageModal<void>(
                context: context,
                title: context.messages.habitDashboardLabel,
                builder: (BuildContext _) {
                  return BlocProvider.value(
                    value: BlocProvider.of<HabitSettingsCubit>(context),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 20,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...dashboards.map(
                              (dashboard) => SettingsCard(
                                onTap: () {
                                  context
                                      .read<HabitSettingsCubit>()
                                      .setDashboard(dashboard.id);
                                  Navigator.pop(context);
                                },
                                title: dashboard.name,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            final undefined = state.habitDefinition.dashboardId == null;
            final style = context.textTheme.titleMedium;

            return TextField(
              onTap: onTap,
              readOnly: true,
              focusNode: FocusNode(),
              controller: controller,
              decoration: inputDecoration(
                labelText:
                    undefined ? '' : context.messages.habitDashboardLabel,
                themeData: Theme.of(context),
              ).copyWith(
                suffixIcon: undefined
                    ? null
                    : GestureDetector(
                        child: Icon(
                          Icons.close_rounded,
                          color: style?.color,
                        ),
                        onTap: () {
                          controller.clear();
                          cubit.setDashboard(null);
                        },
                      ),
                hintText: context.messages.habitDashboardHint,
                hintStyle: style?.copyWith(
                  color: context.colorScheme.outline.withAlpha(127),
                ),
                border: InputBorder.none,
              ),
              style: style,
            );
          },
        );
      },
    );
  }
}
