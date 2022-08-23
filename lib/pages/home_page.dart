import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/routes/observer.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final JournalDb _db = getIt<JournalDb>();

  // ignore: avoid_positional_boolean_parameters
  void onNavigateCallback(RouteMatch<dynamic> route, bool initial) {
    debugPrint('onNavigateCallback $route $initial');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _db.watchActiveConfigFlagNames(),
      builder: (context, snapshot) {
        final localizations = AppLocalizations.of(context)!;

        final showTasks = snapshot.data?.contains(showTasksTabFlag);

        if (showTasks == null) {
          return const CircularProgressIndicator();
        }

        return AutoTabsScaffold(
          lazyLoad: false,
          animationDuration: const Duration(milliseconds: 500),
          builder: (context, child, _) {
            return Container(
              color: colorConfig().bodyBgColor,
              height: double.maxFinite,
              width: double.maxFinite,
              child: Stack(
                children: [
                  ColorThemeRefresh(
                    keyPrefix: 'body',
                    child: child,
                  ),
                  const TimeRecordingIndicator(),
                  const AudioRecordingIndicator(),
                  //  if (showThemeConfig) const ThemeConfigWidget(),
                ],
              ),
            );
          },
          backgroundColor: colorConfig().bodyBgColor,
          routes: const [
            //TutorialRouter(),
          ],
          bottomNavigationBuilder: (_, TabsRouter tabsRouter) {
            final navService = getIt<NavService>();

            final routesByIndex = <String>[
              '/dashboards',
              '/journal',
              if (showTasks) '/tasks',
              '/settings',
            ];

            navService
              ..routesByIndex = routesByIndex
              ..tabsRouter = tabsRouter;

            void onTap(int index) {
              debugPrint('onTap: $index');
              tabsRouter.setActiveIndex(index);
              navService.bottomNavRouteTap(index);
              HapticFeedback.lightImpact();
            }

            return SalomonBottomBar(
              unselectedItemColor: colorConfig().bottomNavIconUnselected,
              selectedItemColor: colorConfig().bottomNavIconSelected,
              currentIndex: tabsRouter.activeIndex,
              onTap: onTap,
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  title: NavTitle(localizations.navTabTitleInsights),
                ),
                SalomonBottomBarItem(
                  icon: FlaggedBadgeIcon(),
                  title: NavTitle(localizations.navTabTitleJournal),
                ),
                if (showTasks)
                  SalomonBottomBarItem(
                    icon: TasksBadgeIcon(),
                    title: NavTitle(localizations.navTabTitleTasks),
                  ),
                SalomonBottomBarItem(
                  icon: OutboxBadgeIcon(
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  title: NavTitle(localizations.navTabTitleSettings),
                ),
              ],
            );
          },
          navigatorObservers: () => [NavObserver()],
        );
      },
    );
  }
}

class NavTitle extends StatelessWidget {
  const NavTitle(this.title, {super.key});

  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title),
    );
  }
}
