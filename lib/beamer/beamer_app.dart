import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_provider_selection_modal.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_activity_indicator.dart';
import 'package:lotti/features/tasks/ui/saved_filters/tasks_saved_filters_tree.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/uuid.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:matrix/matrix.dart';

/// Check if the app is running inside Flatpak sandbox
bool _isRunningInFlatpak() {
  return Platform.isLinux &&
      (Platform.environment['FLATPAK_ID'] != null &&
          Platform.environment['FLATPAK_ID']!.isNotEmpty);
}

/// True when the tasks tab is active and the tasks beamer location points
/// at a `/tasks/<uuid>` task detail. Used by both shells: the mobile shell
/// hides the bottom nav pill so the page-owned `TaskActionBar` can dock
/// flush against the home indicator. Pure function of router state, no
/// widget-lifecycle race.
bool isTaskDetailRoute(BeamLocation<dynamic>? location, int activeTabIndex) {
  // Tasks is always the first destination; if any other tab is active
  // the tasks delegate's current path is irrelevant.
  if (activeTabIndex != 0) return false;
  if (location is! TasksLocation) return false;
  return isUuid(location.state.pathParameters['taskId']);
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

  /// Base icon for this destination. The desktop sidebar uses this directly;
  /// compact navigation may decorate it through [mobileIconWrapper].
  final Widget Function({required bool active}) iconBuilder;

  /// Optional wrapper applied to the icon in compact (mobile) contexts.
  final Widget Function(Widget icon)? mobileIconWrapper;

  /// Optional trailing widget shown on the right side of the desktop sidebar
  /// row, such as a status or count indicator.
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
  const AppScreen({super.key});

  @override
  ConsumerState<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends ConsumerState<AppScreen> {
  final NavService navService = getIt<NavService>();
  bool _notLoggedInToastShown = false;

  void _showNotLoggedInToast(BuildContext context) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.syncNotLoggedInToast,
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
            getIt<DomainLogger>().error(
              LogDomain.sync,
              error,
              stackTrace: stack,
              subDomain: 'notLoggedInGateStream',
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
            getIt<DomainLogger>().error(
              LogDomain.whatsNew,
              error,
              stackTrace: stack,
              subDomain: 'shouldAutoShowWhatsNew',
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
            getIt<DomainLogger>().error(
              LogDomain.ai,
              error,
              stackTrace: stack,
              subDomain: 'aiSetupPromptService',
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

        // Listen to the tasks delegate so the mobile shell rebuilds when the
        // tasks route changes (push to / pop from task details). That's how
        // we know whether to hide the mobile bottom nav pill.
        // See [_isTaskDetailRoute].
        return ListenableBuilder(
          listenable: navService.tasksDelegate,
          builder: (context, _) => isWide
              ? _buildDesktopLayout(
                  context: context,
                  index: index,
                  destinations: destinations,
                  beamerChildren: beamerChildren,
                )
              : _buildMobileLayout(
                  context: context,
                  index: index,
                  destinations: destinations,
                  beamerChildren: beamerChildren,
                ),
        );
      },
    );
  }

  bool _isTaskDetailRoute(int activeTabIndex) => isTaskDetailRoute(
    navService.tasksDelegate.currentBeamLocation,
    activeTabIndex,
  );

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
    final showSyncIndicator =
        ref.watch(configFlagProvider(showSyncActivityIndicatorFlag)).value ??
        false;
    final showSidebarWakeQueue =
        ref.watch(configFlagProvider(showSidebarWakeQueueFlag)).value ?? false;

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
            aboveSettings: _DesktopSidebarAboveSettings(
              showWakeQueue: showSidebarWakeQueue,
            ),
            belowSettings: showSyncIndicator
                ? const SyncActivityIndicator()
                : SizedBox(height: context.designTokens.spacing.step3),
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
                  children: [
                    for (var i = 0; i < beamerChildren.length; i++)
                      TickerMode(
                        enabled: i == index,
                        child: beamerChildren[i],
                      ),
                  ],
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
    // Visibility is a pure function of the active beamer route. Routes
    // that take over the bottom edge with their own sticky surface
    // (e.g. `/tasks/<uuid>` with TaskActionBar) suppress the nav pill —
    // including the time/audio recording indicators that ride above it
    // — so the page-owned bar can dock flush against the home
    // indicator. The enclosing ListenableBuilder ensures we rebuild on
    // every route change.
    final showBottomNav = !_isTaskDetailRoute(index);

    final designSystemBottomNavigationBar = DesignSystemBottomNavigationBar(
      items: [
        for (var i = 0; i < destinations.length; i++)
          destinations[i].toDesignSystemItem(
            active: i == index,
            onTap: () => navService.tapIndex(i),
          ),
      ],
      overlay: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const TimeRecordingIndicator(),
          // Audio indicator is omitted on Flatpak builds (MediaKit
          // compatibility issues). Spacer lives inside the same conditional
          // so it doesn't dangle when only the time indicator is visible.
          if (!_isRunningInFlatpak()) ...[
            const SizedBox(width: 4),
            const AudioRecordingIndicator(),
          ],
        ],
      ),
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const IncomingVerificationWrapper(),
          IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < beamerChildren.length; i++)
                TickerMode(
                  enabled: i == index,
                  child: beamerChildren[i],
                ),
            ],
          ),
          if (showBottomNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: designSystemBottomNavigationBar,
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
  });

  final NavService? navService;
  final UserActivityService? userActivityService;

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
          '*': (context, state, data) => const AppScreen(),
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
    // Keep long-lived runtime wiring alive from app startup onward.
    // - agentInitializationProvider: sync can apply and verify incoming agent
    //   payloads before the first entry view.
    // - syncedAudioInferenceListenerProvider: auto-trigger local AI inference
    //   on synced audio for pinned profiles (keepAlive — this listen just
    //   forces construction so the listener subscribes to syncUpdateStream).
    ref
      ..listen(agentInitializationProvider, (_, _) {})
      ..listen(syncedAudioInferenceListenerProvider, (_, _) {});

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

/// Composer for the desktop sidebar's `aboveSettings` slot. Stacks the
/// optional inline Wake Queue (when its config flag is enabled), audio
/// recording panel, and running-timer panel, so the running timer still sits
/// closest to the Settings entry below. Separators are rendered only between
/// sections that are actually visible.
class _DesktopSidebarAboveSettings extends ConsumerWidget {
  const _DesktopSidebarAboveSettings({required this.showWakeQueue});

  final bool showWakeQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final wakesVisible =
        showWakeQueue && sidebarWakeQueueHasVisibleContent(ref);
    final audioVisible =
        !_isRunningInFlatpak() && sidebarAudioRecordingHasVisibleContent(ref);

    return StreamBuilder<JournalEntity?>(
      stream: getIt<TimeService>().getStream(),
      builder: (context, snapshot) {
        final hasTimer = snapshot.data != null;
        final hasBelowWake = audioVisible || hasTimer;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showWakeQueue) const SidebarWakeQueue(),
            // Animate the gap height so it grows/collapses in sync with
            // the wake card's own AnimatedSize transition; a static
            // SizedBox would otherwise pop in or out the instant either
            // side's visibility flipped.
            AnimatedSize(
              duration: SidebarWakeQueue.animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: (wakesVisible && hasBelowWake)
                    ? tokens.spacing.step3
                    : 0,
              ),
            ),
            if (!_isRunningInFlatpak()) const SidebarAudioRecordingSection(),
            AnimatedSize(
              duration: SidebarAudioRecordingSection.animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: (audioVisible && hasTimer) ? tokens.spacing.step3 : 0,
              ),
            ),
            const SidebarTimerSection(),
          ],
        );
      },
    );
  }
}
