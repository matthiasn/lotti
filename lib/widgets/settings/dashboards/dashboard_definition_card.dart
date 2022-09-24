import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardDefinitionCard extends StatelessWidget {
  const DashboardDefinitionCard({
    super.key,
    required this.dashboard,
    required this.index,
  });

  final DashboardDefinition dashboard;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/dashboards/${dashboard.id}',
      title: dashboard.name,
      trailing: Visibility(
        visible: dashboard.private,
        child: Icon(
          MdiIcons.security,
          color: colorConfig().alarm,
          size: settingsIconSize,
        ),
      ),
    );
  }
}
