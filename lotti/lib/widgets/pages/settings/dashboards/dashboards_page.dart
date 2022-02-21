import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/dashboards/dashboard_details.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

class DashboardsPage extends StatefulWidget {
  const DashboardsPage({Key? key}) : super(key: key);

  @override
  State<DashboardsPage> createState() => _DashboardsPageState();
}

class _DashboardsPageState extends State<DashboardsPage> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<List<DashboardDefinition>> stream = _db.watchDashboards();
  String match = '';

  @override
  void initState() {
    super.initState();
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    double portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return FloatingSearchBar(
      clearQueryOnClose: false,
      automaticallyImplyBackButton: false,
      hint: 'Search dashboards...',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: AppColors.appBarFgColor,
      margins: const EdgeInsets.only(top: 8),
      queryStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
        fontWeight: FontWeight.w300,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
        fontWeight: FontWeight.w300,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8.0),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      width: isPortrait ? portraitWidth : 400,
      onQueryChanged: (query) async {
        setState(() {
          match = query.toLowerCase();
        });
      },
      actions: [
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (context, transition) {
        return const SizedBox.shrink();
      },
    );
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
          appBar: VersionAppBar(title: 'Dashboards, n= ${items.length}'),
          backgroundColor: AppColors.bodyBgColor,
          floatingActionButton: FloatingActionButton(
            child: const Icon(MdiIcons.plus, size: 32),
            backgroundColor: AppColors.entryBgColor,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    DateTime now = DateTime.now();
                    return DashboardDetailRoute(
                      dashboard: DashboardDefinition(
                        id: uuid.v1(),
                        name: '',
                        createdAt: now,
                        updatedAt: now,
                        lastReviewed: now,
                        description: '',
                        vectorClock: null,
                        version: '',
                        items: [],
                        active: true,
                        private: false,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          body: Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  bottom: 8,
                  top: 64,
                ),
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
              buildFloatingSearchBar(),
            ],
          ),
        );
      },
    );
  }
}

class DashboardCard extends StatelessWidget {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final DashboardDefinition dashboard;
  final int index;

  DashboardCard({
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
                return DashboardDetailRoute(
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
