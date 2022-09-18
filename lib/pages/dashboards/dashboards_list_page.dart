import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/how_to_use_page.dart';
import 'package:lotti/pages/settings/settings_card.dart';
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
          return const HowToUsePage();
        }

        if (dashboards.length == 1) {
          return DashboardPage(
            dashboardId: dashboards[0].id,
            showBackButton: false,
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: const DashboardsAppBar(),
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 200, top: 20),
            children: intersperse(
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
            ).toList(),
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
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 8,
        ),
        hoverColor: colorConfig().riplight,
        title: Text(
          dashboard.name,
          style: const TextStyle(
            color: Colors.black,
            fontFamily: mainFont,
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: dashboard.description.isNotEmpty
            ? Text(
                dashboard.description,
                style: TextStyle(
                  color: colorConfig().entryTextColor,
                  fontFamily: mainFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              )
            : null,
        onTap: () => beamToNamed('/dashboards/${dashboard.id}'),
      ),
    );
  }
}
