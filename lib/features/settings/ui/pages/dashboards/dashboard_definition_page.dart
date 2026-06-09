import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/chart_multi_select.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_item_card.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/dashboards/dashboard_category.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

part 'dashboard_definition_page_state.dart';

part 'edit_dashboard_page.dart';

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
      _DashboardDefinitionPageState();
}
