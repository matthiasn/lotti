import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class SelectDashboardWidget extends ConsumerWidget {
  const SelectDashboardWidget({
    required this.habitId,
    super.key,
  });

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    final dashboardsAsync = ref.watch(habitDashboardsProvider);
    final state = ref.watch(habitSettingsControllerProvider(habitId));

    final dashboardsById = <String, DashboardDefinition>{};

    final dashboards = filteredSortedDashboards(
      dashboardsAsync.valueOrNull ?? <DashboardDefinition>[],
    );

    for (final dashboard in dashboards) {
      dashboardsById[dashboard.id] = dashboard;
    }

    final currentHabitDefinition = state.habitDefinition;
    final dashboard = dashboardsById[currentHabitDefinition.dashboardId];

    controller.text = dashboard?.name ?? '';

    void onTap() {
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.habitDashboardLabel,
        builder: (BuildContext _) {
          return Container(
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
                        ref
                            .read(
                              habitSettingsControllerProvider(habitId).notifier,
                            )
                            .setDashboard(dashboard.id);
                        Navigator.pop(context);
                      },
                      title: dashboard.name,
                    ),
                  ),
                ],
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
        labelText: undefined ? '' : context.messages.habitDashboardLabel,
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
                  ref
                      .read(habitSettingsControllerProvider(habitId).notifier)
                      .setDashboard(null);
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
  }
}
