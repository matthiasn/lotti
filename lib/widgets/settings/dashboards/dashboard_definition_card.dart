import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';

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
    final id = dashboard.id;

    return Card(
      color: AppColors.headerBgColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.only(left: 16, top: 8, bottom: 20, right: 16),
        title: Text(
          dashboard.name,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          dashboard.description,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
        ),
        onTap: () => context.router.push(EditDashboardRoute(dashboardId: id)),
      ),
    );
  }
}
