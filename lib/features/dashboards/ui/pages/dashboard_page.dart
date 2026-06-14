import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    required this.dashboardId,
    super.key,
  });

  final String dashboardId;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int timeSpanDays = 90;

  @override
  Widget build(BuildContext context) {
    final dashboard = getIt<EntitiesCacheService>().getDashboardById(
      widget.dashboardId,
    );

    final rangeStart = DateTime.now()
        .subtract(Duration(days: timeSpanDays))
        .dayAtMidnight;
    final rangeEnd = DateTime.now().dayAtMidnight.add(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    );

    if (dashboard == null) {
      beamToNamed('/dashboards');
      return EmptyScaffoldWithTitle(
        context.messages.dashboardNotFound,
      );
    }

    final tokens = context.designTokens;
    return SliverBoxAdapterPage(
      title: dashboard.name,
      showBackButton: true,
      // Content shares the header's horizontal inset so the cards align with
      // the title instead of hugging the page edges.
      child: SettingsContentArea(
        child: Column(
          children: [
            SizedBox(height: tokens.spacing.step5),
            TimeSpanSegmentedControl(
              timeSpanDays: timeSpanDays,
              onValueChanged: (int value) {
                setState(() {
                  timeSpanDays = value;
                });
              },
            ),
            SizedBox(height: tokens.spacing.step5),
            DashboardWidget(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              dashboardId: widget.dashboardId,
            ),
          ],
        ),
      ),
    );
  }
}
