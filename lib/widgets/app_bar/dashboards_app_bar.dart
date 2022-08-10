import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class DashboardsAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<DashboardDefinition>>(
      stream: getIt<JournalDb>().watchDashboards(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<DashboardDefinition>> snapshot,
      ) {
        final dashboards = snapshot.data ?? [];

        return AppBar(
          backgroundColor: colorConfig().headerBgColor,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Visibility(
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                visible: dashboards.isNotEmpty,
                child: IconButton(
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Icons.slideshow_outlined),
                  color: colorConfig().entryTextColor,
                  onPressed: () {
                    final navService = getIt<NavService>();

                    navService.tabsRouter?.setActiveIndex(
                      navService.routesByIndex.length - 1,
                    );

                    Future<void>.delayed(const Duration(milliseconds: 50)).then(
                      (value) => navigateNamedRoute('/dashboards/carousel'),
                    );
                  },
                ),
              ),
              Text(
                localizations.navTabTitleInsights,
                style: appBarTextStyle(),
              ),
              IconButton(
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.dashboard_customize_outlined),
                color: colorConfig().entryTextColor,
                onPressed: () {
                  final navService = getIt<NavService>();

                  navService.tabsRouter?.setActiveIndex(
                    navService.routesByIndex.length - 1,
                  );

                  Future<void>.delayed(const Duration(milliseconds: 50)).then(
                    (value) => navigateNamedRoute('/settings/dashboards/'),
                  );
                },
              ),
            ],
          ),
          centerTitle: true,
        );
      },
    );
  }
}
