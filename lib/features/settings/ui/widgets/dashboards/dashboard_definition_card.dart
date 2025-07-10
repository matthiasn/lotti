import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardDefinitionCard extends StatelessWidget {
  const DashboardDefinitionCard({
    required this.dashboard,
    super.key,
  });

  final DashboardDefinition dashboard;

  @override
  Widget build(BuildContext context) {
    final description = dashboard.description;
    return SettingsNavCard(
      path: '/settings/dashboards/${dashboard.id}',
      title: dashboard.name,
      leading: CategoryColorIcon(dashboard.categoryId),
      subtitle: description.isNotEmpty ? Text(description) : null,
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
