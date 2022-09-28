import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/how_to_use_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardCarouselPage extends StatefulWidget {
  const DashboardCarouselPage({super.key});

  @override
  State<DashboardCarouselPage> createState() => _DashboardCarouselPageState();
}

class _DashboardCarouselPageState extends State<DashboardCarouselPage> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<List<DashboardDefinition>> stream = _db.watchDashboards();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DashboardDefinition>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<DashboardDefinition>> snapshot,
      ) {
        if (snapshot.data == null) {
          return const LoadingDashboards();
        }

        final dashboards = filteredSortedDashboards(snapshot.data ?? []);

        if (dashboards.isEmpty) {
          return const HowToUsePage();
        }

        final rangeStart = getRangeStart(context: context);
        final rangeEnd = getRangeEnd();

        return Scaffold(
          backgroundColor: styleConfig().negspace,
          appBar: const TitleAppBar(title: 'Dashboards'),
          body: CarouselSlider(
            items: dashboards
                .map(
                  (dashboard) => DashboardWidget(
                    dashboard: dashboard,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    dashboardId: dashboard.id,
                    showTitle: true,
                  ),
                )
                .toList(),
            options: CarouselOptions(
              viewportFraction: 1,
              height: 10000,
              // autoPlay: false,
            ),
          ),
        );
      },
    );
  }
}
