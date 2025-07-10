import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/chart_scale_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    required this.dashboardId,
    super.key,
    this.showBackButton = true,
  });

  final String dashboardId;
  final bool showBackButton;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  double zoomStartScale = 10;
  double scale = 10;
  double horizontalPan = 0;
  bool zoomInProgress = false;
  int timeSpanDays = 180;

  late TransformationController _transformationController;

  @override
  void initState() {
    _transformationController = TransformationController();
    _transformationController.addListener(() {
      ref.read(barWidthControllerProvider.notifier).updateScale(
            _transformationController.value,
          );
    });

    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = getIt<EntitiesCacheService>().getDashboardById(
      widget.dashboardId,
    );

    final rangeStart =
        DateTime.now().subtract(Duration(days: timeSpanDays)).dayAtMidnight;
    final rangeEnd = DateTime.now()
        .dayAtMidnight
        .add(const Duration(hours: 23, minutes: 59, seconds: 59));

    if (dashboard == null) {
      beamToNamed('/dashboards');
      return EmptyScaffoldWithTitle(
        context.messages.dashboardNotFound,
      );
    }

    return SliverBoxAdapterPage(
      title: dashboard.name,
      showBackButton: true,
      child: Column(
        children: [
          const SizedBox(height: 15),
          TimeSpanSegmentedControl(
            timeSpanDays: timeSpanDays,
            segments: const [180, 365],
            onValueChanged: (int value) {
              setState(() {
                timeSpanDays = value;
              });
            },
          ),
          const SizedBox(height: 15),
          DashboardWidget(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            dashboardId: widget.dashboardId,
            transformationController: _transformationController,
          ),
        ],
      ),
    );
  }
}
