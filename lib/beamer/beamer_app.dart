import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/badges/tasks_badge_icon.dart';
import 'package:lotti/widgets/charts/loading_widget.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/nav_bar_item.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  final navService = getIt<NavService>();
  final journalDb = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<bool>(
      stream: journalDb.watchConfigFlag(enableTaskManagement),
      builder: (context, configSnapshot) {
        final showTasksTab = configSnapshot.data ?? false;

        return StreamBuilder<int>(
          stream: navService.getIndexStream(),
          builder: (context, snapshot) {
            final index = snapshot.data ?? 0;

            return Scaffold(
              body: Stack(
                children: [
                  IndexedStack(
                    index: index,
                    children: [
                      Beamer(routerDelegate: navService.habitsDelegate),
                      Beamer(routerDelegate: navService.dashboardsDelegate),
                      Beamer(routerDelegate: navService.journalDelegate),
                      if (showTasksTab)
                        Beamer(routerDelegate: navService.tasksDelegate),
                      Beamer(routerDelegate: navService.settingsDelegate),
                    ],
                  ),
                  const TimeRecordingIndicator(),
                  const Positioned(
                    right: 120,
                    bottom: 0,
                    child: AudioRecordingIndicator(),
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.5),
                enableFeedback: true,
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
                type: BottomNavigationBarType.fixed,
                currentIndex: index,
                items: [
                  createNavBarItem(
                    semanticLabel: 'Habits Tab',
                    icon: Icon(MdiIcons.checkboxMultipleMarkedOutline),
                    activeIcon: Icon(MdiIcons.checkboxMultipleMarked),
                    label: localizations.navTabTitleHabits,
                  ),
                  createNavBarItem(
                    semanticLabel: 'Dashboards Tab',
                    icon: const Icon(Ionicons.bar_chart_outline),
                    activeIcon: const Icon(Ionicons.bar_chart),
                    label: localizations.navTabTitleInsights,
                  ),
                  createNavBarItem(
                    semanticLabel: 'Logbook Tab',
                    icon: const Icon(Ionicons.book_outline),
                    activeIcon: const Icon(Ionicons.book),
                    label: localizations.navTabTitleJournal,
                  ),
                  if (showTasksTab)
                    createNavBarItem(
                      semanticLabel: 'Tasks Tab',
                      icon: TasksBadge(
                        child: Icon(MdiIcons.checkboxMarkedCircleOutline),
                      ),
                      activeIcon: TasksBadge(
                        child: Icon(MdiIcons.checkboxMarkedCircle),
                      ),
                      label: localizations.navTabTitleTasks,
                    ),
                  createNavBarItem(
                    semanticLabel: 'Settings Tab',
                    icon: OutboxBadgeIcon(
                      icon: const Icon(Ionicons.settings_outline),
                    ),
                    activeIcon: OutboxBadgeIcon(
                      icon: const Icon(Ionicons.settings),
                    ),
                    label: localizations.navTabTitleSettings,
                  ),
                ],
                onTap: navService.tapIndex,
              ),
            );
          },
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
          BlocProvider<SyncConfigCubit>(
            lazy: false,
            create: (BuildContext context) => SyncConfigCubit(
              testOnNetworkChange: true,
            ),
          ),
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
              return const EmptyScaffoldWithTitle(
                '...',
                body: LoadingWidget(),
              );
            }

            return DesktopMenuWrapper(
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
            );
          },
        ),
      ),
    );
  }
}
