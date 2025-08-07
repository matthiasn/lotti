import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.dashboard,
    super.key,
  });

  final DashboardDefinition dashboard;

  @override
  Widget build(BuildContext context) {
    final description = dashboard.description;
    return SettingsNavCard(
      path: '/dashboards/${dashboard.id}',
      title: dashboard.name,
      subtitle: description.isNotEmpty ? Text(dashboard.description) : null,
      leading: CategoryIconCompact(
        dashboard.categoryId,
        size: CategoryIconConstants.iconSizeMedium,
      ),
    );
  }
}
