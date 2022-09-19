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

        void onPressSettings() {
          beamToNamed('/settings/dashboards');
        }

        void onPressCarousel() {
          beamToNamed('/dashboards/carousel');
        }

        return AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 10,
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
                  color: colorConfig().coal,
                  hoverColor: Colors.transparent,
                  onPressed: onPressCarousel,
                ),
              ),
              Text(
                localizations.navTabTitleInsights,
                style: appBarTextStyleNew(),
              ),
              IconButton(
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.dashboard_customize_outlined),
                color: colorConfig().coal,
                hoverColor: Colors.transparent,
                onPressed: onPressSettings,
              ),
            ],
          ),
          centerTitle: true,
        );
      },
    );
  }
}
