import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/dashboards/dashboard_definition_card.dart';

class DashboardSettingsPage extends StatelessWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<DashboardDefinition>(
      stream: getIt<JournalDb>().watchDashboards(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/dashboards/create'),
        semanticLabel: 'Add Dashboard',
      ),
      title: context.messages.settingsDashboardsTitle,
      getName: (habit) => '${habit.name} ${habit.description}',
      definitionCard: (int index, DashboardDefinition item) {
        return DashboardDefinitionCard(
          index: index,
          dashboard: item,
        );
      },
    );
  }
}
