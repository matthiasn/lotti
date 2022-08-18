import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/beamer/beamer_locations.dart';
import 'package:lotti/beamer/locations/settings.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/home_page.dart';
import 'package:lotti/pages/settings/outbox/outbox_badge.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/bottom_nav/flagged_badge_icon.dart';
import 'package:lotti/widgets/bottom_nav/tasks_badge_icon.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/theme/theme_config.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  AppScreenState createState() => AppScreenState();
}

class AppScreenState extends State<AppScreen> {
  late int currentIndex;

  final routerDelegates = [
    BeamerDelegate(
      initialPath: '/dashboards',
      locationBuilder: (routeInformation, _) {
        if (routeInformation.location!.contains('dashboards')) {
          return DashboardsLocation(routeInformation);
        }
        return NotFound(path: routeInformation.location!);
      },
    ),
    BeamerDelegate(
      initialPath: '/journal',
      locationBuilder: (routeInformation, _) {
        if (routeInformation.location!.contains('journal')) {
          return JournalLocation(routeInformation);
        }
        if (routeInformation.location!.contains('tasks')) {
          return TasksLocation(routeInformation);
        }
        return NotFound(path: routeInformation.location!);
      },
    ),
    BeamerDelegate(
      initialPath: '/tasks',
      locationBuilder: (routeInformation, _) {
        if (routeInformation.location!.contains('tasks')) {
          return TasksLocation(routeInformation);
        }
        return NotFound(path: routeInformation.location!);
      },
    ),
    BeamerDelegate(
      initialPath: '/settings',
      locationBuilder: (routeInformation, _) {
        if (routeInformation.location!.contains('settings')) {
          return SettingsLocation(routeInformation);
        }
        return NotFound(path: routeInformation.location!);
      },
    ),
    BeamerDelegate(
      initialPath: '/config_flags',
      locationBuilder: (routeInformation, _) {
        if (routeInformation.location!.contains('config_flags')) {
          return ConfigFlagsLocation(routeInformation);
        }
        return NotFound(path: routeInformation.location!);
      },
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uriString = Beamer.of(context).configuration.location!;
    debugPrint('didChangeDependencies $uriString');
    currentIndex = uriString.contains('tasks') ? 2 : 0;
  }

  @override
  Widget build(BuildContext context) {
    const showTasks = true;
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          Beamer(routerDelegate: routerDelegates[0]),
          Beamer(routerDelegate: routerDelegates[1]),
          Beamer(routerDelegate: routerDelegates[2]),
          Beamer(routerDelegate: routerDelegates[3]),
          Beamer(routerDelegate: routerDelegates[4]),
        ],
      ),
      bottomNavigationBar: SalomonBottomBar(
        unselectedItemColor: colorConfig().bottomNavIconUnselected,
        selectedItemColor: colorConfig().bottomNavIconSelected,
        currentIndex: currentIndex,
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
          SalomonBottomBarItem(
            icon: const Icon(Icons.app_settings_alt),
            title: const NavTitle('ConfigFlags'),
          ),
        ],
        onTap: (index) {
          if (index != currentIndex) {
            setState(
              () => currentIndex = index,
            );
            routerDelegates[currentIndex].update(rebuild: false);
          }
        },
      ),
    );
  }
}

class MyBeamerApp extends StatelessWidget {
  MyBeamerApp({super.key});

  final JournalDb _db = getIt<JournalDb>();

  final routerDelegate = BeamerDelegate(
    initialPath: '/dashboards',
    locationBuilder: RoutesLocationBuilder(
      routes: {
        '*': (context, state, data) => const AppScreen(),
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
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
            ThemeConfigWrapper(
              MaterialApp.router(
                color: colorConfig().bodyBgColor,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  primarySwatch: Colors.grey,
                  scaffoldBackgroundColor: colorConfig().bodyBgColor,
                ),
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
                scaffoldMessengerKey: GlobalKey(debugLabel: 'MyBeamerApp'),
              ),
            ),
          ),
        );
      },
    );
  }
}
