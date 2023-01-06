import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/dashboards/dashboard_definition_card.dart';

class DashboardSettingsPage extends StatelessWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DefinitionsListPage<DashboardDefinition>(
      stream: getIt<JournalDb>().watchDashboards(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/dashboards/create'),
      ),
      title: localizations.settingsDashboardsTitle,
      getName: (habitDefinition) => habitDefinition.name,
      definitionCard: (int index, DashboardDefinition item) {
        return DashboardDefinitionCard(
          index: index,
          dashboard: item,
        );
      },
    );
  }
}
