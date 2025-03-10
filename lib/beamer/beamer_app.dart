import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/manual/widget/navbar_showcase.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/recorder_cubit.dart';
import 'package:lotti/features/speech/ui/widgets/audio_recording_indicator.dart';
import 'package:lotti/features/tasks/ui/tasks_badge_icon.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/nav_bar.dart';
import 'package:lotti/widgets/nav_bar/nav_bar_item.dart';
import 'package:lotti/widgets/sync/matrix/incoming_verification_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  final navService = getIt<NavService>();
  final journalDb = getIt<JournalDb>();

  final _fabShowcaseKey1 = GlobalKey();
  final _fabShowcaseKey2 = GlobalKey();
  final _fabShowcaseKey3 = GlobalKey();
  final _fabShowcaseKey4 = GlobalKey();
  final _fabShowcaseKey5 = GlobalKey();
  final _fabShowcaseKey6 = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        // Only show for tasks page
        // ignore: use_build_context_synchronously
        ShowCaseWidget.of(context).startShowCase(
          [
            _fabShowcaseKey1,
            _fabShowcaseKey2,
            _fabShowcaseKey3,
            _fabShowcaseKey4,
            _fabShowcaseKey5,
            _fabShowcaseKey6,

          ],
        );
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
                  Beamer(routerDelegate: navService.calendarDelegate),
                  Beamer(routerDelegate: navService.habitsDelegate),
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
                  showcaseKey: _fabShowcaseKey1,
                  child: Icon(MdiIcons.checkboxMarkedCircleOutline),
                ),
                activeIcon: TasksBadge(
                  showcaseKey: _fabShowcaseKey1,
                  child: Icon(MdiIcons.checkboxMarkedCircle),
                ),
                label: context.messages.navTabTitleTasks,
              ),
              createNavBarItem(
                semanticLabel: 'Calendar Tab',
                icon: NavbarShowcase(
                  showcaseKey: _fabShowcaseKey2,
                  description: const Text(
                    'This is the calendar view. You can add events to your calendar hereeee.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Ionicons.calendar_outline),
                ),
                activeIcon: OutboxBadgeIcon(
                  icon: const Icon(Ionicons.calendar),
                ),
                label: context.messages.navTabTitleCalendar,
              ),
              createNavBarItem(
                semanticLabel: 'Habits Tab',
                icon:  NavbarShowcase(
                  showcaseKey: _fabShowcaseKey3,
                  description: const Text(
                    'This is the habits view. You can add habits here.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: Icon(MdiIcons.checkboxMultipleMarkedOutline),
                ),
                activeIcon: Icon(MdiIcons.checkboxMultipleMarked),
                label: context.messages.navTabTitleHabits,
              ),
              createNavBarItem(
                semanticLabel: 'Dashboards Tab',
                icon: NavbarShowcase(
                  showcaseKey: _fabShowcaseKey4,
                  description: const Text(
                    'This is the insights view. You can see your insights here.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Ionicons.bar_chart_outline),
                ),
                activeIcon: const Icon(Ionicons.bar_chart),
                label: context.messages.navTabTitleInsights,
              ),
              createNavBarItem(
                semanticLabel: 'Logbook Tab',
                icon: NavbarShowcase(
                  showcaseKey: _fabShowcaseKey5,
                  description: const Text(
                    'This is the logbook view. You can log your activities here.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Ionicons.book),
                ),
                activeIcon: const Icon(Ionicons.book),
                label: context.messages.navTabTitleJournal,
              ),
              createNavBarItem(
                semanticLabel: 'Settings Tab',
                icon: NavbarShowcase(
                  endNav: true,
                  showcaseKey: _fabShowcaseKey6,
                  description: const Text(
                    'This is the settings view. You can change your settings here.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
    return ShowCaseWidget(
      builder: (context) => GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: MultiBlocProvider(
          providers: [
            BlocProvider<OutboxCubit>(
              lazy: false,
              create: (BuildContext context) => OutboxCubit(),
            ),
            BlocProvider<AudioRecorderCubit>(
              create: (BuildContext context) => AudioRecorderCubit(),
            ),
            BlocProvider<AudioPlayerCubit>(
              create: (BuildContext context) => AudioPlayerCubit(),
            ),
            BlocProvider<ThemingCubit>(
              create: (BuildContext context) => ThemingCubit(),
            ),
          ],
          child: BlocBuilder<ThemingCubit, ThemingState>(
            builder: (context, themingSnapshot) {
              if (themingSnapshot.darkTheme == null) {
                return const MaterialApp(
                  home: EmptyScaffoldWithTitle(
                    '...',
                    body: CircularProgressIndicator(),
                  ),
                );
              }

              final updateActivity =
                  getIt<UserActivityService>().updateActivity;

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
      ),
    );
  }
}
