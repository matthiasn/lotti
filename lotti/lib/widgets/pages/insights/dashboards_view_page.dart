import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/insights/dashboard_viewer.dart';

class DashboardsViewPage extends StatefulWidget {
  const DashboardsViewPage({Key? key}) : super(key: key);

  @override
  State<DashboardsViewPage> createState() => _DashboardsViewPageState();
}

class _DashboardsViewPageState extends State<DashboardsViewPage> {
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
        List<DashboardDefinition> items = snapshot.data ?? [];
        List<DashboardDefinition> filtered = items
            .where((DashboardDefinition dashboard) =>
                dashboard.name.toLowerCase().contains(match))
            .toList();

        return Scaffold(
          appBar: const VersionAppBar(title: 'Dashboards'),
          backgroundColor: AppColors.bodyBgColor,
          body: Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8.0),
                children: List.generate(
                  filtered.length,
                  (int index) {
                    return DashboardCard(
                      dashboard: filtered.elementAt(index),
                      index: index,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardCard extends StatelessWidget {
  final DashboardDefinition dashboard;
  final int index;

  const DashboardCard({
    Key? key,
    required this.dashboard,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.only(left: 16, top: 8, bottom: 20, right: 16),
        title: Text(
          dashboard.name,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 24.0,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          dashboard.description,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 16.0,
            fontWeight: FontWeight.w300,
          ),
        ),
        enabled: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return DashboardViewerRoute(
                  dashboard: dashboard,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
