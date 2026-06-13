import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page_state.dart';

export 'package:lotti/features/settings/ui/pages/dashboards/edit_dashboard_page.dart';

class DashboardDefinitionPage extends StatefulWidget {
  const DashboardDefinitionPage({
    required this.dashboard,
    super.key,
    this.formKey,
  });

  final DashboardDefinition dashboard;
  final GlobalKey<FormBuilderState>? formKey;

  @override
  State<DashboardDefinitionPage> createState() =>
      DashboardDefinitionPageState();
}
