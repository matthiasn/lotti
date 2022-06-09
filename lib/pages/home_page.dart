import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox_badge.dart';
import 'package:lotti/routes/observer.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/app_bar_version.dart';
import 'package:lotti/widgets/app_bar/dashboard_app_bar.dart';
import 'package:lotti/widgets/app_bar/dashboards_app_bar.dart';
import 'package:lotti/widgets/app_bar/empty_app_bar.dart';
import 'package:lotti/widgets/app_bar/task_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';

class HomePage extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();

  HomePage({Key? key}) : super(key: key);

  void onNavigateCallback(RouteMatch<dynamic> route, bool initial) {
    debugPrint('onNavigateCallback $route $initial');
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return StreamBuilder<bool>(
        stream: _db.watchConfigFlag('show_tasks_tab'),
        builder: (context, snapshot) {
          bool? showTasks = snapshot.data;

          if (showTasks == null) {
            return const CircularProgressIndicator();
          }

          return AutoTabsScaffold(
            lazyLoad: false,
            animationDuration: const Duration(milliseconds: 500),
            appBarBuilder: (context, TabsRouter tabsRouter) {
              final String topRouteName = tabsRouter.topRoute.name;

              if (topRouteName == DashboardRoute.name) {
                return DashboardAppBar(
                  dashboardId:
                      tabsRouter.topRoute.pathParams.getString('dashboardId'),
                );
              }

              if (topRouteName == DashboardsListRoute.name) {
                return const DashboardsAppBar();
              }

              if (topRouteName == DashboardSettingsRoute.name) {
                return TitleAppBar(
                    title: localizations.settingsDashboardsTitle);
              }

              if (topRouteName == MeasurablesRoute.name) {
                return TitleAppBar(
                    title: localizations.settingsMeasurablesTitle);
              }

              if (topRouteName == EntryDetailRoute.name) {
                return TaskAppBar(
                  itemId: tabsRouter.topRoute.pathParams.getString('itemId'),
                );
              }

              if (topRouteName == SettingsRoute.name) {
                return VersionAppBar(title: localizations.navTabTitleSettings);
              }

              if ({TasksRoute.name, JournalRoute.name}.contains(topRouteName)) {
                return EmptyAppBar();
              }

              return const VersionAppBar(title: 'Lotti');
            },
            builder: (context, child, _) {
              return Container(
                color: AppColors.bodyBgColor,
                height: double.maxFinite,
                width: double.maxFinite,
                child: Stack(
                  children: [
                    child,
                    const TimeRecordingIndicator(),
                    const AudioRecordingIndicator(),
                  ],
                ),
              );
            },
            backgroundColor: AppColors.bodyBgColor,
            routes: [
              const JournalRouter(),
              if (showTasks) const TasksRouter(),
              const DashboardsRouter(),
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

              NavService navService = getIt<NavService>();

              List<String> routesByIndex = [
                '/journal',
                if (showTasks) '/tasks',
                '/dashboards',
                '/settings',
              ];

              navService.routesByIndex = routesByIndex;
              navService.tabsRouter = tabsRouter;

              void onTap(int index) {
                debugPrint('onTap: $index');
                tabsRouter.setActiveIndex(index);
                navService.bottomNavRouteTap(index);
              }

              if (hideBottomNavRoutes.contains(tabsRouter.topRoute.name)) {
                return const SizedBox.shrink();
              }

              return Container(
                decoration: const BoxDecoration(
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0.0, 0.75))
                  ],
                ),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: AppColors.headerBgColor,
                  unselectedItemColor: AppColors.bottomNavIconUnselected,
                  selectedItemColor: AppColors.bottomNavIconSelected,
                  currentIndex: tabsRouter.activeIndex,
                  onTap: onTap,
                  enableFeedback: true,
                  selectedFontSize: 18,
                  unselectedFontSize: 14,
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
                      icon: const Icon(Icons.dashboard),
                      label: AppLocalizations.of(context)!.navTabTitleInsights,
                    ),
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
        });
  }
}
