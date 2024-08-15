import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardDefinitionCard extends StatelessWidget {
  const DashboardDefinitionCard({
    required this.dashboard,
    required this.index,
    super.key,
  });

  final DashboardDefinition dashboard;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/dashboards/${dashboard.id}',
      title: dashboard.name,
      leading: CategoryColorIcon(dashboard.categoryId),
      trailing: Visibility(
        visible: dashboard.private,
        child: Icon(
          MdiIcons.security,
          color: context.colorScheme.error,
          size: settingsIconSize,
        ),
      ),
    );
  }
}
