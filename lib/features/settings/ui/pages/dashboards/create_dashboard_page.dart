import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateDashboardPage extends StatelessWidget {
  CreateDashboardPage({
    super.key,
  });

  final DashboardDefinition _dashboardDefinition = DashboardDefinition(
    id: uuid.v1(),
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lastReviewed: DateTime.now(),
    description: '',
    vectorClock: null,
    version: '',
    items: [],
    active: true,
    private: false,
  );

  @override
  Widget build(BuildContext context) {
    return DashboardDefinitionPage(dashboard: _dashboardDefinition);
  }
}
