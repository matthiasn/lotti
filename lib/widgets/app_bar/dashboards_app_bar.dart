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
        void onPressSettings() => beamToNamed('/settings/dashboards');

        return AppBar(
          backgroundColor: styleConfig().negspace,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 10,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Text(
                localizations.navTabTitleInsights,
                style: appBarTextStyleNew(),
              ),
              IconButton(
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.dashboard_customize_outlined),
                color: styleConfig().primaryTextColor,
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
