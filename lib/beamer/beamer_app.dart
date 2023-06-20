import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
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
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/badges/tasks_badge_icon.dart';
import 'package:lotti/widgets/charts/loading_widget.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';

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
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(height: 2),
                type: BottomNavigationBarType.shifting,
                currentIndex: index,
                items: [
                  BottomNavigationBarItem(
                    icon: Semantics(
                      container: true,
                      label: 'Habits Tab',
                      image: true,
                      child: const Icon(Icons.checklist_outlined),
                    ),
                    label: localizations.navTabTitleHabits,
                    tooltip: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Semantics(
                      container: true,
                      label: 'Dashboards Tab',
                      image: true,
                      child: const Icon(Icons.insights_outlined),
                    ),
                    label: localizations.navTabTitleInsights,
                    tooltip: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Semantics(
                      container: true,
                      label: 'Logbook Tab',
                      image: true,
                      child: const Icon(Icons.auto_stories_outlined),
                    ),
                    label: localizations.navTabTitleJournal,
                    tooltip: '',
                  ),
                  if (showTasksTab)
                    BottomNavigationBarItem(
                      icon: Semantics(
                        container: true,
                        label: 'Tasks Tab',
                        image: true,
                        child: TasksBadge(
                          child: const Icon(Icons.task_alt_outlined),
                        ),
                      ),
                      label: localizations.navTabTitleTasks,
                      tooltip: '',
                    ),
                  BottomNavigationBarItem(
                    icon: Semantics(
                      container: true,
                      label: 'Settings Tab',
                      image: true,
                      child: OutboxBadgeIcon(
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ),
                    label: localizations.navTabTitleSettings,
                    tooltip: '',
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
    return MultiBlocProvider(
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
    );
  }
}
