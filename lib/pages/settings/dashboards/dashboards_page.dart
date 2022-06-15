import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/sort.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  State<DashboardSettingsPage> createState() => _DashboardSettingsPageState();
}

class _DashboardSettingsPageState extends State<DashboardSettingsPage> {
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

    final portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return FloatingSearchBar(
      clearQueryOnClose: false,
      automaticallyImplyBackButton: false,
      hint: AppLocalizations.of(context)!.settingsDashboardsSearchHint,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: AppColors.appBarFgColor,
      margins: const EdgeInsets.only(top: 8),
      queryStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8),
      axisAlignment: isPortrait ? 0 : -1,
      openAxisAlignment: 0,
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
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsDashboardsTitle),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.entryBgColor,
        onPressed: () {
          context.router.push(const CreateDashboardRoute());
        },
        child: const Icon(MdiIcons.plus, size: 32),
      ),
      body: StreamBuilder<List<DashboardDefinition>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DashboardDefinition>> snapshot,
        ) {
          final dashboards =
              filteredSortedDashboards(snapshot.data ?? [], match);

          return Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  top: 64,
                ),
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
              buildFloatingSearchBar(),
            ],
          );
        },
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  DashboardCard({
    super.key,
    required this.dashboard,
    required this.index,
  });

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final DashboardDefinition dashboard;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
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
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          dashboard.description,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
        ),
        onTap: () {
          context.router.push(
            EditDashboardRoute(dashboardId: dashboard.id),
          );
        },
      ),
    );
  }
}
