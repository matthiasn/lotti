import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/tasks/ui/tasks_badge_icon.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/nav_bar.dart';
import 'package:lotti/widgets/nav_bar/nav_bar_item.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class AppScreenConstants {
  const AppScreenConstants._();

  static const double navigationElevation = 8;
  static const double navigationIconSize = 30;
  static const double navigationTextHeight = 2;
  static const double navigationPadding = 10;
  static const double navigationTimeIndicatorBottom = 0;
  static const double navigationAudioIndicatorRight = 100;
}

/// Check if the app is running inside Flatpak sandbox
bool _isRunningInFlatpak() {
  return Platform.isLinux &&
      (Platform.environment['FLATPAK_ID'] != null &&
          Platform.environment['FLATPAK_ID']!.isNotEmpty);
}

class AppScreen extends ConsumerStatefulWidget {
  const AppScreen({
    super.key,
    this.journalDb,
  });

  final JournalDb? journalDb;

  @override
  ConsumerState<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends ConsumerState<AppScreen> {
  final NavService navService = getIt<NavService>();

  bool _isHabitsPageEnabled = true;
  bool _isDashboardsPageEnabled = true;
  bool _isCalendarPageEnabled = true;
  bool _notLoggedInToastShown = false;

  @override
  void initState() {
    super.initState();

    (widget.journalDb ?? getIt<JournalDb>())
        .watchActiveConfigFlagNames()
        .forEach((configFlags) {
      if (mounted) {
        setState(() {
          _isHabitsPageEnabled = configFlags.contains(enableHabitsPageFlag);
          _isDashboardsPageEnabled =
              configFlags.contains(enableDashboardsPageFlag);
          _isCalendarPageEnabled = configFlags.contains(enableCalendarPageFlag);
        });
      }
    });
  }

  void _showNotLoggedInToast(BuildContext context) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.syncNotLoggedInToast),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reset toast guard on login, and listen for login-gate events from outbox.
    ref
      ..listen(loginStateStreamProvider, (prev, next) {
        final state = next.asData?.value;
        if (state == LoginState.loggedIn) {
          _notLoggedInToastShown = false;
        }
      })
      ..listen(outboxLoginGateStreamProvider, (prev, next) {
        next.when(
          data: (_) {
            if (_notLoggedInToastShown) return;
            _notLoggedInToastShown = true;
            _showNotLoggedInToast(context);
          },
          loading: () {},
          error: (error, stack) {
            getIt<LoggingService>().captureException(
              error,
              domain: 'OUTBOX',
              subDomain: 'notLoggedInGateStream',
              stackTrace: stack,
            );
          },
        );
      });

    return StreamBuilder<int>(
      stream: navService.getIndexStream(),
      builder: (context, snapshot) {
        final rawIndex = snapshot.data ?? 0;

        // Calculate the number of navigation items based on enabled flags
        final navItems = [
          true, // Tasks
          _isCalendarPageEnabled, // Calendar
          _isHabitsPageEnabled, // Habits
          _isDashboardsPageEnabled, // Dashboards
          true, // Journal
          true, // Settings
        ];
        final itemCount = navItems.where((isEnabled) => isEnabled).length;

        // Clamp index to valid range to prevent out of bounds errors
        // when flags are toggled and items list shrinks
        final index = rawIndex < 0
            ? 0
            : (rawIndex > itemCount - 1 ? itemCount - 1 : rawIndex);

        // No eager toast from build(); event-driven toast handled via ref.listen

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
                left: AppScreenConstants.navigationPadding,
                bottom: AppScreenConstants.navigationTimeIndicatorBottom,
                child: TimeRecordingIndicator(),
              ),
              // Only show AudioRecordingIndicator when not running in Flatpak
              // Flatpak builds have MediaKit compatibility issues
              if (!_isRunningInFlatpak())
                const Positioned(
                  right: AppScreenConstants.navigationAudioIndicatorRight,
                  bottom: AppScreenConstants.navigationTimeIndicatorBottom,
                  child: AudioRecordingIndicator(),
                ),
            ],
          ),
          bottomNavigationBar: SpotifyStyleBottomNavigationBar(
            selectedItemColor: context.colorScheme.primary,
            unselectedItemColor: context.colorScheme.primary.withAlpha(127),
            enableFeedback: true,
            backgroundColor: context.colorScheme.surface,
            elevation: AppScreenConstants.navigationElevation,
            iconSize: AppScreenConstants.navigationIconSize,
            selectedLabelStyle: const TextStyle(
              height: AppScreenConstants.navigationTextHeight,
              fontWeight: FontWeight.normal,
              fontSize: fontSizeSmall,
            ),
            unselectedLabelStyle: const TextStyle(
              height: AppScreenConstants.navigationTextHeight,
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
                  activeIcon: const OutboxBadgeIcon(
                    icon: Icon(Ionicons.calendar),
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
                icon: const OutboxBadgeIcon(
                  icon: Icon(Ionicons.settings_outline),
                ),
                activeIcon: const OutboxBadgeIcon(
                  icon: Icon(Ionicons.settings),
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

class MyBeamerApp extends ConsumerStatefulWidget {
  const MyBeamerApp({
    super.key,
    this.navService,
    this.audioPlayerCubit,
    this.userActivityService,
    this.journalDb,
  });

  final NavService? navService;
  final AudioPlayerCubit? audioPlayerCubit;
  final UserActivityService? userActivityService;
  final JournalDb? journalDb;

  @override
  ConsumerState<MyBeamerApp> createState() => _MyBeamerAppState();
}

class _MyBeamerAppState extends ConsumerState<MyBeamerApp> {
  late final BeamerDelegate routerDelegate;
  late final NavService effectiveNavService;

  @override
  void initState() {
    super.initState();
    effectiveNavService = widget.navService ?? getIt<NavService>();

    routerDelegate = BeamerDelegate(
      initialPath: effectiveNavService.currentPath,
      locationBuilder: RoutesLocationBuilder(
        routes: {
          '*': (context, state, data) => AppScreen(journalDb: widget.journalDb)
        },
      ).call,
    );
  }

  @override
  void dispose() {
    routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themingState = ref.watch(themingControllerProvider);
    final enableTooltips =
        ref.watch(enableTooltipsProvider).valueOrNull ?? true;

    if (themingState.darkTheme == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black87),
        home: const EmptyScaffoldWithTitle(
          'Loading...',
        ),
      );
    }

    final updateActivity =
        (widget.userActivityService ?? getIt<UserActivityService>())
            .updateActivity;

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: BlocProvider<AudioPlayerCubit>(
        create: (BuildContext context) =>
            widget.audioPlayerCubit ?? getIt<AudioPlayerCubit>(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => updateActivity(),
          onPointerMove: (event) => updateActivity(),
          onPointerPanZoomStart: (event) => updateActivity(),
          onPointerPanZoomEnd: (event) => updateActivity(),
          onPointerUp: (event) => updateActivity(),
          onPointerSignal: (event) => updateActivity(),
          onPointerPanZoomUpdate: (event) => updateActivity(),
          child: TooltipVisibility(
            visible: enableTooltips,
            child: DesktopMenuWrapper(
              child: MaterialApp.router(
                supportedLocales: AppLocalizations.supportedLocales,
                theme: themingState.lightTheme,
                darkTheme: themingState.darkTheme,
                themeMode: themingState.themeMode,
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
        ),
      ),
    );
  }
}
