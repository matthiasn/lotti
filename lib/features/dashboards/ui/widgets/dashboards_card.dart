import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/services/nav_service.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.dashboard,
    required this.showDivider,
    super.key,
  });

  final DashboardDefinition dashboard;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final description = dashboard.description.trim();
    return DesignSystemListItem(
      title: dashboard.name,
      subtitle: description.isNotEmpty ? description : null,
      leading: CategoryIconCompact(
        dashboard.categoryId,
        size: CategoryIconConstants.iconSizeMedium,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: tokens.spacing.step6,
        color: tokens.colors.text.lowEmphasis,
      ),
      showDivider: showDivider,
      onTap: () => beamToNamed('/dashboards/${dashboard.id}'),
    );
  }
}
