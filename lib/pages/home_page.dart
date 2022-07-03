import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/routes/observer.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/theme/theme_config.dart';

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
        final showTasks = snapshot.data?.contains('show_tasks_tab');
        final showThemeConfig = snapshot.data != null &&
            snapshot.data!.contains('show_theme_config') &&
            isDesktop;

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
                  Padding(
                    padding: EdgeInsets.only(left: showThemeConfig ? 400 : 0),
                    child: child,
                  ),
                  const TimeRecordingIndicator(),
                  const AudioRecordingIndicator(),
                  if (showThemeConfig) const ThemeConfigWidget(),
                ],
              ),
            );
          },
          backgroundColor: colorConfig().bodyBgColor,
          routes: [
            const JournalRouter(),
            if (showTasks) const TasksRouter(),
            const DashboardsRouter(),
            // ignore: flutter_style_todos
            // TODO: bring back or remove
            // MyDayRouter(),
            const SettingsRouter(),
            //TutorialRouter(),
          ],
          bottomNavigationBuilder: (_, TabsRouter tabsRouter) {
            final hideBottomNavRoutes = <String>{
              DashboardRoute.name,
              EntryDetailRoute.name,
              LoggingRoute.name,
              LogDetailRoute.name,
              SyncAssistantRoute.name,
            };

            final navService = getIt<NavService>();

            final routesByIndex = <String>[
              '/journal',
              if (showTasks) '/tasks',
              '/dashboards',
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

            if (hideBottomNavRoutes.contains(tabsRouter.topRoute.name)) {
              return const SizedBox.shrink();
            }

            return DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 0.75),
                  )
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: colorConfig().bottomNavBackground,
                unselectedItemColor: colorConfig().bottomNavIconUnselected,
                selectedItemColor: colorConfig().bottomNavIconSelected,
                currentIndex: tabsRouter.activeIndex,
                selectedLabelStyle: bottomNavLabelStyle.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                unselectedLabelStyle: bottomNavLabelStyle,
                onTap: onTap,
                enableFeedback: true,
                selectedFontSize: 18,
                unselectedFontSize: 16,
                items: [
                  BottomNavigationBarItem(
                    icon: FlaggedBadgeIcon(),
                    label: AppLocalizations.of(context)!.navTabTitleJournal,
                  ),
                  if (showTasks)
                    BottomNavigationBarItem(
                      icon: TasksBadgeIcon(),
                      label: AppLocalizations.of(context)!.navTabTitleTasks,
                    ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.dashboard_outlined),
                    label: AppLocalizations.of(context)!.navTabTitleInsights,
                  ),
                  // ignore: flutter_style_todos
                  // TODO: bring back or remove
                  // const BottomNavigationBarItem(
                  //   icon: Icon(Icons.calendar_today),
                  //   label: 'My Day',
                  // ),
                  BottomNavigationBarItem(
                    icon: OutboxBadgeIcon(
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    label: AppLocalizations.of(context)!.navTabTitleSettings,
                  ),
                ],
              ),
            );
          },
          navigatorObservers: () => [NavObserver()],
        );
      },
    );
  }
}
