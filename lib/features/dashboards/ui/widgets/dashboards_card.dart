import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/categories_type_card.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.dashboard,
    required this.index,
    super.key,
  });

  final DashboardDefinition dashboard;
  final int index;

  @override
  Widget build(BuildContext context) {
    final description = dashboard.description;
    return SettingsNavCard(
      path: '/dashboards/${dashboard.id}',
      title: dashboard.name,
      subtitle: description.isNotEmpty ? Text(dashboard.description) : null,
      leading: CategoryColorIcon(dashboard.categoryId),
    );
  }
}
