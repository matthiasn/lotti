import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/app_bar/dashboards_app_bar.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';

class DashboardsListPage extends StatefulWidget {
  const DashboardsListPage({super.key});

  @override
  State<DashboardsListPage> createState() => _DashboardsListPageState();
}

class _DashboardsListPageState extends State<DashboardsListPage> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<List<DashboardDefinition>> stream = _db.watchDashboards();
  String match = '';

  @override
  void initState() {
    super.initState();
  }

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

        final dashboards = filteredSortedDashboards(
          snapshot.data ?? [],
          match: match,
        );

        if (dashboards.isEmpty) {
          return const EmptyDashboards();
        }

        if (dashboards.length == 1) {
          return DashboardPage(
            dashboardId: dashboards[0].id,
            showBackIcon: false,
          );
        }

        return Scaffold(
          backgroundColor: colorConfig().bodyBgColor,
          appBar: const DashboardsAppBar(),
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            children: List.generate(
              dashboards.length,
              (int index) {
                return DashboardCard(
                  dashboard: dashboards.elementAt(index),
                  index: index,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.dashboard,
    required this.index,
  });

  final DashboardDefinition dashboard;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorConfig().entryCardColor,
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
            color: colorConfig().entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          dashboard.description,
          style: TextStyle(
            color: colorConfig().entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
        ),
        onTap: () {
          context.beamToNamed(
            '/dashboards/dashboard/${dashboard.id}',
          );

          navigateNamedRoute(
            '/dashboards/dashboard/${dashboard.id}',
          );
        },
      ),
    );
  }
}
