import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme/theme.dart';

class DashboardsAppBar extends StatelessWidget with PreferredSizeWidget {
  const DashboardsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AppBar(
      backgroundColor: getIt<ThemeService>().colors.headerBgColor,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Text(
            localizations.navTabTitleInsights,
            style: appBarTextStyle,
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.dashboard_customize_outlined),
            color: getIt<ThemeService>().colors.entryTextColor,
            onPressed: () {
              final navService = getIt<NavService>();

              navService.tabsRouter
                  ?.setActiveIndex(navService.routesByIndex.length - 1);

              Future<void>.delayed(const Duration(milliseconds: 50))
                  .then((value) => pushNamedRoute('/settings/dashboards/'));
            },
          ),
        ],
      ),
      centerTitle: true,
    );
  }
}
