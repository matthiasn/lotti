import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_provider_selection_modal.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/tasks/ui/saved_filters/tasks_saved_filters_tree.dart';
import 'package:lotti/features/tasks/ui/tasks_badge_icon.dart';
import 'package:lotti/features/tasks/ui/tasks_trailing_badge.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:matrix/matrix.dart';

class AppScreenConstants {
  const AppScreenConstants._();

  static const double navigationPadding = 34;
  static const double navigationTimeIndicatorBottom = 0;
  static const double navigationAudioIndicatorRight = 100;

  /// Amount by which the recording indicators visually overlap the top edge
  /// of the bottom-nav pill so their flat bottoms tuck into it.
  static const double navigationIndicatorPillOverlap = 6;
}

/// Check if the app is running inside Flatpak sandbox
bool _isRunningInFlatpak() {
  return Platform.isLinux &&
      (Platform.environment['FLATPAK_ID'] != null &&
          Platform.environment['FLATPAK_ID']!.isNotEmpty);
}

enum _AppNavigationDestinationKind {
  tasks,
  projects,
  dailyOs,
  habits,
  dashboards,
  journal,
  settings,
}

class _AppNavigationDestination {
  const _AppNavigationDestination({
    required this.kind,
    required this.label,
    required this.iconBuilder,
    this.mobileIconWrapper,
    this.trailingBuilder,
    this.expandedChildBuilder,
  });

  final _AppNavigationDestinationKind kind;
  final String label;

  /// Plain icon (no badge overlay). Used directly in the desktop sidebar,
  /// where the count lives in [trailingBuilder].
  final Widget Function({required bool active}) iconBuilder;

  /// Optional wrapper applied to the icon in compact (mobile) contexts where
  /// the count must overlay the icon rather than sit in its own row slot.
  final Widget Function(Widget icon)? mobileIconWrapper;

  /// Optional trailing widget shown on the right side of the desktop sidebar
  /// row. Typically a count pill.
  final Widget Function({required bool active})? trailingBuilder;

  /// Optional builder for a subtree rendered immediately under the
  /// destination row when it is the active tab and the sidebar is expanded.
  /// The Tasks destination uses this to host the saved-filters treeview.
  final Widget Function()? expandedChildBuilder;

  Widget _mobileIcon({required bool active}) {
    final icon = iconBuilder(active: active);
    return mobileIconWrapper?.call(icon) ?? icon;
  }

  DesignSystemNavigationTabBarItem toDesignSystemItem({
    required bool active,
    required VoidCallback onTap,
  }) {
    return DesignSystemNavigationTabBarItem(
      label: label,
      icon: _mobileIcon(active: false),
      activeIcon: _mobileIcon(active: true),
      active: active,
      onTap: onTap,
    );
  }

  DesktopSidebarDestination toDesktopSidebarDestination() {
    return DesktopSidebarDestination(
      label: label,
      iconBuilder: iconBuilder,
      trailingBuilder: trailingBuilder,
      expandedChildBuilder: expandedChildBuilder,
    );
  }
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
  bool _notLoggedInToastShown = false;

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

  void _showAiSetupPrompt(BuildContext context, WidgetRef ref) {
    if (!mounted) return;
    AiProviderSelectionModal.show(
      context,
      onProviderSelected: (providerType) {
        // Modal closes itself, then we navigate
        const AiSettingsNavigationService().navigateToCreateProvider(
          context,
          preselectedType: providerType,
        );
      },
      onDismiss: () {
        // Modal closes itself, then we persist dismissal
        ref.read(aiSetupPromptServiceProvider.notifier).dismissPrompt();
      },
    );
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
      })
      // Auto-show What's New modal when app version changes
      ..listen(shouldAutoShowWhatsNewProvider, (prev, next) {
        next.when(
          data: (shouldShow) {
            if (shouldShow && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  WhatsNewModal.show(context, ref);
                }
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            getIt<LoggingService>().captureException(
              error,
              domain: 'WHATS_NEW',
              subDomain: 'shouldAutoShowWhatsNew',
              stackTrace: stack,
            );
          },
        );
      })
      // When What's New is dismissed, re-check if AI setup prompt should show
      ..listen(whatsNewControllerProvider, (prev, next) {
        final prevHasUnseen = prev?.asData?.value.hasUnseenRelease ?? true;
        final nextHasUnseen = next.asData?.value.hasUnseenRelease ?? true;

        // If What's New transitioned from unseen to seen, re-check AI setup prompt
        if (prevHasUnseen && !nextHasUnseen) {
          ref.invalidate(aiSetupPromptServiceProvider);
        }
      })
      // Auto-show AI setup prompt for new users without AI providers
      ..listen(aiSetupPromptServiceProvider, (prev, next) {
        next.when(
          data: (shouldShow) {
            if (shouldShow && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showAiSetupPrompt(context, ref);
                }
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            getIt<LoggingService>().captureException(
              error,
              domain: 'AI_FTUE',
              subDomain: 'aiSetupPromptService',
              stackTrace: stack,
            );
          },
        );
      });

    return StreamBuilder<int>(
      stream: navService.getIndexStream(),
      builder: (context, snapshot) {
        final rawIndex = snapshot.data ?? 0;
        final isProjectsPageEnabled = navService.isProjectsPageEnabled;
        final isDailyOsPageEnabled = navService.isDailyOsPageEnabled;
        final isHabitsPageEnabled = navService.isHabitsPageEnabled;
        final isDashboardsPageEnabled = navService.isDashboardsPageEnabled;

        final destinations = _buildNavigationDestinations(
          context: context,
          isProjectsPageEnabled: isProjectsPageEnabled,
          isDailyOsPageEnabled: isDailyOsPageEnabled,
          isHabitsPageEnabled: isHabitsPageEnabled,
          isDashboardsPageEnabled: isDashboardsPageEnabled,
        );
        final itemCount = destinations.length;

        // Clamp index to valid range to prevent out of bounds errors
        // when flags are toggled and items list shrinks
        final index = rawIndex < 0
            ? 0
            : (rawIndex > itemCount - 1 ? itemCount - 1 : rawIndex);

        final isWide = isDesktopLayout(context);
        navService.isDesktopMode = isWide;

        final beamerChildren = [
          Beamer(routerDelegate: navService.tasksDelegate),
          if (isProjectsPageEnabled)
            Beamer(routerDelegate: navService.projectsDelegate),
          if (isDailyOsPageEnabled)
            Beamer(routerDelegate: navService.calendarDelegate),
          if (isHabitsPageEnabled)
            Beamer(routerDelegate: navService.habitsDelegate),
          if (isDashboardsPageEnabled)
            Beamer(routerDelegate: navService.dashboardsDelegate),
          Beamer(routerDelegate: navService.journalDelegate),
          Beamer(routerDelegate: navService.settingsDelegate),
        ];

        if (isWide) {
          return _buildDesktopLayout(
            context: context,
            index: index,
            destinations: destinations,
            beamerChildren: beamerChildren,
          );
        }

        return _buildMobileLayout(
          context: context,
          index: index,
          destinations: destinations,
          beamerChildren: beamerChildren,
        );
      },
    );
  }

  Widget _buildDesktopLayout({
    required BuildContext context,
    required int index,
    required List<_AppNavigationDestination> destinations,
    required List<Widget> beamerChildren,
  }) {
    // Separate Settings from other destinations
    final mainDestinations = <_AppNavigationDestination>[];
    _AppNavigationDestination? settingsDestination;
    var settingsIndex = -1;

    for (var i = 0; i < destinations.length; i++) {
      if (destinations[i].kind == _AppNavigationDestinationKind.settings) {
        settingsDestination = destinations[i];
        settingsIndex = i;
      } else {
        mainDestinations.add(destinations[i]);
      }
    }

    // Compute the active index for the main destinations list
    // (which excludes Settings)
    final isSettingsActive = index == settingsIndex;
    var mainActiveIndex = 0;
    if (!isSettingsActive) {
      // Find which main destination corresponds to the full index
      var mainIdx = 0;
      for (var i = 0; i < destinations.length; i++) {
        if (destinations[i].kind == _AppNavigationDestinationKind.settings) {
          continue;
        }
        if (i == index) {
          mainActiveIndex = mainIdx;
          break;
        }
        mainIdx++;
      }
    }

    final paneWidths = ref.watch(paneWidthControllerProvider);
    final isCollapsed = paneWidths.sidebarCollapsed;

    return Scaffold(
      // Scaffold fills behind the outer ResizableDivider's 3 px reserved
      // SizedBox; without an explicit colour Flutter would paint the theme
      // default (canvas / near-black) there, which shows through as a darker
      // strip around the sidebar-↔-list divider. Using the list-pane token
      // (background.level01 = #181818) keeps the divider flanked by the
      // same surface on both visible edges, matching the right-side divider.
      backgroundColor: context.designTokens.colors.background.level01,
      body: Row(
        children: [
          DesktopNavigationSidebar(
            destinations: [
              for (final dest in mainDestinations)
                dest.toDesktopSidebarDestination(),
            ],
            activeIndex: mainActiveIndex,
            onDestinationSelected: (mainIdx) {
              // Map main destination index back to the full index
              var fullIdx = 0;
              var count = 0;
              for (var i = 0; i < destinations.length; i++) {
                if (destinations[i].kind ==
                    _AppNavigationDestinationKind.settings) {
                  continue;
                }
                if (count == mainIdx) {
                  fullIdx = i;
                  break;
                }
                count++;
              }
              navService.tapIndex(fullIdx);
            },
            settingsDestination: settingsDestination
                ?.toDesktopSidebarDestination(),
            onSettingsSelected: settingsIndex >= 0
                ? () => navService.tapIndex(settingsIndex)
                : null,
            isSettingsActive: isSettingsActive,
            width: paneWidths.sidebarWidth,
            collapsed: isCollapsed,
            onToggleCollapsed: () => ref
                .read(paneWidthControllerProvider.notifier)
                .toggleSidebarCollapsed(),
          ),
          ResizableDivider(
            enabled: !isCollapsed,
            onDrag: (delta) => ref
                .read(paneWidthControllerProvider.notifier)
                .updateSidebarWidth(delta),
          ),
          Expanded(
            child: Stack(
              children: [
                const IncomingVerificationWrapper(),
                IndexedStack(
                  index: index,
                  children: beamerChildren,
                ),
                const Positioned(
                  left: AppScreenConstants.navigationPadding,
                  bottom: AppScreenConstants.navigationTimeIndicatorBottom,
                  child: TimeRecordingIndicator(),
                ),
                if (!_isRunningInFlatpak())
                  const Positioned(
                    right: AppScreenConstants.navigationAudioIndicatorRight,
                    bottom: AppScreenConstants.navigationTimeIndicatorBottom,
                    child: AudioRecordingIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required int index,
    required List<_AppNavigationDestination> destinations,
    required List<Widget> beamerChildren,
  }) {
    final designSystemBottomNavigationBar = DesignSystemBottomNavigationBar(
      items: [
        for (var i = 0; i < destinations.length; i++)
          destinations[i].toDesignSystemItem(
            active: i == index,
            onTap: () => navService.tapIndex(i),
          ),
      ],
    );
    final overlayBottomInset =
        DesignSystemBottomNavigationBar.pillTopFromScreenBottom(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const IncomingVerificationWrapper(),
          IndexedStack(
            index: index,
            children: beamerChildren,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: designSystemBottomNavigationBar,
          ),
          Positioned(
            left: AppScreenConstants.navigationPadding,
            bottom:
                AppScreenConstants.navigationTimeIndicatorBottom +
                overlayBottomInset -
                AppScreenConstants.navigationIndicatorPillOverlap,
            child: const TimeRecordingIndicator(),
          ),
          // Only show AudioRecordingIndicator when not running in Flatpak
          // Flatpak builds have MediaKit compatibility issues
          if (!_isRunningInFlatpak())
            Positioned(
              right: AppScreenConstants.navigationAudioIndicatorRight,
              bottom:
                  AppScreenConstants.navigationTimeIndicatorBottom +
                  overlayBottomInset -
                  AppScreenConstants.navigationIndicatorPillOverlap,
              child: const AudioRecordingIndicator(),
            ),
        ],
      ),
    );
  }

  List<_AppNavigationDestination> _buildNavigationDestinations({
    required BuildContext context,
    required bool isProjectsPageEnabled,
    required bool isDailyOsPageEnabled,
    required bool isHabitsPageEnabled,
    required bool isDashboardsPageEnabled,
  }) {
    final allDestinations = <_AppNavigationDestination>[
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.tasks,
        label: context.messages.navTabTitleTasks,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.list_rounded : Icons.list_outlined),
        mobileIconWrapper: (icon) => TasksBadge(child: icon),
        trailingBuilder: ({required active}) => const TasksTrailingBadge(),
        expandedChildBuilder: () => const TasksSavedFiltersTree(),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.projects,
        label: context.messages.navTabTitleProjects,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.folder_rounded : Icons.folder_outlined),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.dailyOs,
        label: context.messages.navTabTitleCalendar,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.today_rounded : Icons.today_outlined),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.habits,
        label: context.messages.navTabTitleHabits,
        iconBuilder: ({required active}) => Icon(
          active ? Icons.checklist_rounded : Icons.checklist_outlined,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.dashboards,
        label: context.messages.navTabTitleInsights,
        iconBuilder: ({required active}) => Icon(
          active ? Icons.insert_chart_rounded : Icons.insert_chart_outlined,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.journal,
        label: context.messages.navTabTitleJournal,
        iconBuilder: ({required active}) => Icon(
          active ? Icons.menu_book_rounded : Icons.menu_book_outlined,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.settings,
        label: context.messages.navTabTitleSettings,
        iconBuilder: ({required active}) => const Icon(Icons.settings_rounded),
        mobileIconWrapper: (icon) => OutboxBadgeIcon(icon: icon),
        trailingBuilder: ({required active}) => const OutboxTrailingBadge(),
      ),
    ];

    return allDestinations
        .where((destination) {
          return switch (destination.kind) {
            _AppNavigationDestinationKind.tasks => true,
            _AppNavigationDestinationKind.projects => isProjectsPageEnabled,
            _AppNavigationDestinationKind.dailyOs => isDailyOsPageEnabled,
            _AppNavigationDestinationKind.habits => isHabitsPageEnabled,
            _AppNavigationDestinationKind.dashboards => isDashboardsPageEnabled,
            _AppNavigationDestinationKind.journal => true,
            _AppNavigationDestinationKind.settings => true,
          };
        })
        .toList(growable: false);
  }
}

class MyBeamerApp extends ConsumerStatefulWidget {
  const MyBeamerApp({
    super.key,
    this.navService,
    this.userActivityService,
    this.journalDb,
  });

  final NavService? navService;
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
          '*': (context, state, data) => AppScreen(journalDb: widget.journalDb),
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
    // Keep agent runtime wiring alive from app startup onward so sync can
    // apply and verify incoming agent payloads before the first entry view.
    ref.listen(agentInitializationProvider, (_, _) {});

    final themingState = ref.watch(themingControllerProvider);
    final enableTooltips = ref.watch(enableTooltipsProvider).value ?? true;

    if (themingState.darkTheme == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black87,
        ),
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
            onZoomIn: ref.watch(zoomControllerProvider.notifier).zoomIn,
            onZoomOut: ref.watch(zoomControllerProvider.notifier).zoomOut,
            onZoomReset: ref.watch(zoomControllerProvider.notifier).resetZoom,
            child: ZoomWrapper(
              scale: ref.watch(zoomControllerProvider),
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
