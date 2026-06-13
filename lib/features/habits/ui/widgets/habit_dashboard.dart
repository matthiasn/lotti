import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Dashboard picker for the habit editor, rendered as a
/// [SettingsPickerField] so it matches the design-system fields around
/// it. Selection happens in a single-page modal listing the dashboards.
class SelectDashboardWidget extends ConsumerWidget {
  const SelectDashboardWidget({
    required this.habitId,
    super.key,
  });

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardsAsync = ref.watch(habitDashboardsProvider);
    final state = ref.watch(habitSettingsControllerProvider(habitId));
    final notifier = ref.read(
      habitSettingsControllerProvider(habitId).notifier,
    );

    final dashboards = filteredSortedDashboards(
      dashboardsAsync.value ?? <DashboardDefinition>[],
    );
    final dashboardsById = <String, DashboardDefinition>{
      for (final dashboard in dashboards) dashboard.id: dashboard,
    };
    final dashboard = dashboardsById[state.habitDefinition.dashboardId];

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
                        notifier.setDashboard(dashboard.id);
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

    return SettingsPickerField(
      label: context.messages.habitDashboardLabel,
      valueText: dashboard?.name,
      hintText: context.messages.habitDashboardHint,
      onClear: dashboard != null ? () => notifier.setDashboard(null) : null,
      onTap: onTap,
    );
  }
}
