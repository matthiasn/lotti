import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';

class DashboardsAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.settings_outlined),
                color: styleConfig().secondaryTextColor,
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

class DashboardsSliverAppBar extends StatelessWidget {
  const DashboardsSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: styleConfig().negspace,
      expandedHeight: 50,
      primary: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          SettingsButton('/settings/dashboards'),
        ],
      ),
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }
}
