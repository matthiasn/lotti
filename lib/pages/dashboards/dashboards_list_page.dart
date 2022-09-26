import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/how_to_use_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/app_bar/dashboards_app_bar.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

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
          return const HowToUsePage();
        }

        if (dashboards.length == 1) {
          return DashboardPage(
            dashboardId: dashboards[0].id,
            showBackButton: false,
          );
        }

        return Scaffold(
          backgroundColor: colorConfig().negspace,
          appBar: const DashboardsAppBar(),
          body: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 200, top: 70),
              children: [
                const SettingsDivider(),
                ...intersperse(
                  const SettingsDivider(),
                  List.generate(
                    dashboards.length,
                    (int index) {
                      return DashboardCard(
                        dashboard: dashboards.elementAt(index),
                        index: index,
                      );
                    },
                  ),
                ),
                const SettingsDivider(),
              ]),
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
    return SettingsNavCard(
      path: '/dashboards/${dashboard.id}',
      title: dashboard.name,
    );
  }
}
