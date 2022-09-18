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
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/audio/audio_recording_indicator.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/theme/theme_config.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  final navService = getIt<NavService>();

  @override
  Widget build(BuildContext context) {
    const showTasks = true;
    final localizations = AppLocalizations.of(context)!;

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
                  Beamer(routerDelegate: navService.dashboardsDelegate),
                  Beamer(routerDelegate: navService.journalDelegate),
                  Beamer(routerDelegate: navService.tasksDelegate),
                  Beamer(routerDelegate: navService.settingsDelegate),
                ],
              ),
              const TimeRecordingIndicator(),
              const AudioRecordingIndicator(),
            ],
          ),
          bottomNavigationBar: SalomonBottomBar(
            unselectedItemColor: colorConfig().bottomNavIconUnselected,
            selectedItemColor: colorConfig().bottomNavIconSelected,
            currentIndex: index,
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
            onTap: navService.tapIndex,
          ),
        );
      },
    );
  }
}

class MyBeamerApp extends StatelessWidget {
  MyBeamerApp({super.key});

  final JournalDb _db = getIt<JournalDb>();

  final routerDelegate = BeamerDelegate(
    initialPath: getIt<NavService>().currentPath,
    locationBuilder: RoutesLocationBuilder(
      routes: {'*': (context, state, data) => const AppScreen()},
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      primarySwatch: Colors.grey,
      hoverColor: colorConfig().riptide,
      scaffoldBackgroundColor: colorConfig().bodyBgColor,
      highlightColor: colorConfig().settingsHoverColor,
      appBarTheme: AppBarTheme(
        iconTheme: IconThemeData(color: colorConfig().entryTextColor),
      ),
    );

    return StreamBuilder<Set<String>>(
      stream: _db.watchActiveConfigFlagNames(),
      builder: (context, snapshot) {
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
          ],
          child: DesktopMenuWrapper(
            child: ThemeConfigWrapper(
              MaterialApp.router(
                color: colorConfig().bodyBgColor,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: theme,
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
      child: Text(
        title,
        style: const TextStyle(fontFamily: mainFont),
      ),
    );
  }
}
