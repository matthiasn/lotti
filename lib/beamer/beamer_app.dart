import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/tasks/ui/tasks_badge_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/nav_bar.dart';
import 'package:lotti/widgets/nav_bar/nav_bar_item.dart';
import 'package:lotti/widgets/sync/matrix/incoming_verification_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  final NavService navService = getIt<NavService>();
  final JournalDb journalDb = getIt<JournalDb>();

  bool _isHabitsPageEnabled = true;
  bool _isDashboardsPageEnabled = true;
  bool _isCalendarPageEnabled = true;

  @override
  void initState() {
    super.initState();

    getIt<JournalDb>().watchActiveConfigFlagNames().forEach((configFlags) {
      setState(() {
        _isHabitsPageEnabled = configFlags.contains(enableHabitsPageFlag);
        _isDashboardsPageEnabled =
            configFlags.contains(enableDashboardsPageFlag);
        _isCalendarPageEnabled = configFlags.contains(enableCalendarPageFlag);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: navService.getIndexStream(),
      builder: (context, snapshot) {
        final index = snapshot.data ?? 0;

        return Scaffold(
          body: Stack(
            children: [
              const IncomingVerificationWrapper(),
              IndexedStack(
                index: index,
                children: [
                  Beamer(routerDelegate: navService.tasksDelegate),
                  if (_isCalendarPageEnabled)
                    Beamer(routerDelegate: navService.calendarDelegate),
                  if (_isHabitsPageEnabled)
                    Beamer(routerDelegate: navService.habitsDelegate),
                  if (_isDashboardsPageEnabled)
                    Beamer(routerDelegate: navService.dashboardsDelegate),
                  Beamer(routerDelegate: navService.journalDelegate),
                  Beamer(routerDelegate: navService.settingsDelegate),
                ],
              ),
              const Positioned(
                left: 10,
                bottom: 0,
                child: TimeRecordingIndicator(),
              ),
              const Positioned(
                right: 100,
                bottom: 0,
                child: AudioRecordingIndicator(),
              ),
            ],
          ),
          bottomNavigationBar: SpotifyStyleBottomNavigationBar(
            selectedItemColor: context.colorScheme.primary,
            unselectedItemColor: context.colorScheme.primary.withAlpha(127),
            enableFeedback: true,
            backgroundColor: context.colorScheme.surface,
            elevation: 8,
            iconSize: 30,
            selectedLabelStyle: const TextStyle(
              height: 2,
              fontWeight: FontWeight.normal,
              fontSize: fontSizeSmall,
            ),
            unselectedLabelStyle: const TextStyle(
              height: 2,
              fontWeight: FontWeight.w300,
              fontSize: fontSizeSmall,
            ),
            type: SpotifyStyleBottomNavigationBarType.fixed,
            currentIndex: index,
            items: [
              createNavBarItem(
                semanticLabel: 'Tasks Tab',
                icon: TasksBadge(
                  child: Icon(MdiIcons.checkboxMarkedCircleOutline),
                ),
                activeIcon: TasksBadge(
                  child: Icon(MdiIcons.checkboxMarkedCircle),
                ),
                label: context.messages.navTabTitleTasks,
              ),
              if (_isCalendarPageEnabled)
                createNavBarItem(
                  semanticLabel: 'Calendar Tab',
                  icon: const Icon(Ionicons.calendar_outline),
                  activeIcon: OutboxBadgeIcon(
                    icon: const Icon(Ionicons.calendar),
                  ),
                  label: context.messages.navTabTitleCalendar,
                ),
              if (_isHabitsPageEnabled)
                createNavBarItem(
                  semanticLabel: 'Habits Tab',
                  icon: Icon(MdiIcons.checkboxMultipleMarkedOutline),
                  activeIcon: Icon(MdiIcons.checkboxMultipleMarked),
                  label: context.messages.navTabTitleHabits,
                ),
              if (_isDashboardsPageEnabled)
                createNavBarItem(
                  semanticLabel: 'Dashboards Tab',
                  icon: const Icon(Ionicons.bar_chart_outline),
                  activeIcon: const Icon(Ionicons.bar_chart),
                  label: context.messages.navTabTitleInsights,
                ),
              createNavBarItem(
                semanticLabel: 'Logbook Tab',
                icon: const Icon(Ionicons.book_outline),
                activeIcon: const Icon(Ionicons.book),
                label: context.messages.navTabTitleJournal,
              ),
              createNavBarItem(
                semanticLabel: 'Settings Tab',
                icon: OutboxBadgeIcon(
                  icon: const Icon(Ionicons.settings_outline),
                ),
                activeIcon: OutboxBadgeIcon(
                  icon: const Icon(Ionicons.settings),
                ),
                label: context.messages.navTabTitleSettings,
              ),
            ],
            onTap: navService.tapIndex,
          ),
        );
      },
    );
  }
}

class MyBeamerApp extends StatelessWidget {
  MyBeamerApp({super.key});

  final routerDelegate = BeamerDelegate(
    initialPath: getIt<NavService>().currentPath,
    locationBuilder: RoutesLocationBuilder(
      routes: {'*': (context, state, data) => const AppScreen()},
    ).call,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<OutboxCubit>(
            lazy: false,
            create: (BuildContext context) => OutboxCubit(),
          ),
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => getIt<AudioPlayerCubit>(),
          ),
          BlocProvider<ThemingCubit>(
            create: (BuildContext context) => ThemingCubit(),
          ),
        ],
        child: BlocBuilder<ThemingCubit, ThemingState>(
          builder: (context, themingSnapshot) {
            if (themingSnapshot.darkTheme == null) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark()
                    .copyWith(scaffoldBackgroundColor: Colors.black87),
                home: const EmptyScaffoldWithTitle(
                  'Loading...',
                ),
              );
            }

            final updateActivity = getIt<UserActivityService>().updateActivity;

            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => updateActivity(),
              onPointerMove: (event) => updateActivity(),
              onPointerPanZoomStart: (event) => updateActivity(),
              onPointerPanZoomEnd: (event) => updateActivity(),
              onPointerUp: (event) => updateActivity(),
              onPointerSignal: (event) => updateActivity(),
              onPointerPanZoomUpdate: (event) => updateActivity(),
              child: TooltipVisibility(
                visible: themingSnapshot.enableTooltips,
                child: DesktopMenuWrapper(
                  child: MaterialApp.router(
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: themingSnapshot.lightTheme,
                    darkTheme: themingSnapshot.darkTheme,
                    themeMode: themingSnapshot.themeMode,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      FormBuilderLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                      FlutterQuillLocalizations.delegate,
                    ],
                    debugShowCheckedModeBanner: false,
                    routerDelegate: routerDelegate,
                    routeInformationParser: BeamerParser(),
                    backButtonDispatcher: BeamerBackButtonDispatcher(
                      delegate: routerDelegate,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
