import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
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
    return DefinitionCard(
      beamTo: '/settings/dashboards/${dashboard.id}',
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dashboard.name,
            style: definitionCardTitleStyle(),
          ),
          Visibility(
            visible: dashboard.private,
            child: Icon(
              MdiIcons.security,
              color: colorConfig().alarm,
              size: settingsIconSize,
            ),
          ),
        ],
      ),
    );
  }
}

class DefinitionCard extends StatelessWidget {
  const DefinitionCard({
    super.key,
    required this.beamTo,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final Widget title;
  final String beamTo;
  final Widget? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 8,
        ),
        hoverColor: colorConfig().riplight,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: title,
        ),
        subtitle: subtitle,
        leading: leading,
        onTap: () => beamToNamed(beamTo),
      ),
    );
  }
}
