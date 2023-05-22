import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/loading_widget.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/dashboards/dashboard_widget.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.dashboardId,
    super.key,
    this.showBackButton = true,
  });

  final String dashboardId;
  final bool showBackButton;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JournalDb _db = getIt<JournalDb>();

  double zoomStartScale = 10;
  double scale = 10;
  double horizontalPan = 0;
  bool zoomInProgress = false;
  int timeSpanDays = isDesktop ? 30 : 14;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // TODO: bring back or remove
    // final int shiftDays = max((horizontalPan / scale).floor(), 0);
    // final rangeStart = getRangeStart(
    //   context: context,
    //   scale: scale,
    //   shiftDays: shiftDays,
    // );
    // final rangeEnd = getRangeEnd(shiftDays: shiftDays);

    final rangeStart =
        getStartOfDay(DateTime.now().subtract(Duration(days: timeSpanDays)));
    final rangeEnd = getEndOfToday();

    return GestureDetector(
      // TODO: bring back or remove
      // onScaleStart: (_) {
      //   setState(() {
      //     zoomStartScale = scale;
      //     zoomInProgress = true;
      //   });
      // },
      // onScaleEnd: (_) {
      //   setState(() {
      //     zoomInProgress = false;
      //   });
      // },
      // onHorizontalDragUpdate: (DragUpdateDetails details) {
      //   setState(() {
      //     if (!zoomInProgress) {
      //       horizontalPan += details.delta.dx;
      //     }
      //   });
      // },
      // onScaleUpdate: (ScaleUpdateDetails details) {
      //   final horizontalScale = details.horizontalScale;
      //   setState(() {
      //     if (horizontalScale != 1) {
      //       scale = zoomStartScale * horizontalScale;
      //     }
      //   });
      // },
      child: StreamBuilder(
        stream: _db.watchDashboardById(widget.dashboardId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DashboardDefinition>> snapshot,
        ) {
          if (!snapshot.hasData) {
            return EmptyScaffoldWithTitle(
              localizations.dashboardsLoadingHint,
              body: const LoadingWidget(),
            );
          }

          DashboardDefinition? dashboard;
          final data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            dashboard = data.first;
          }

          if (dashboard == null) {
            beamToNamed('/dashboards');
            return EmptyScaffoldWithTitle(
              localizations.dashboardNotFound,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
