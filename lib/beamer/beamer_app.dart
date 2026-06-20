import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_provider_selection_modal.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_sidebar_entry.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
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
import 'package:lotti/widgets/nav_bar/mobile_nav_more_sheet.dart';
import 'package:matrix/matrix.dart';

/// Check if the app is running inside Flatpak sandbox
bool _isRunningInFlatpak() {
  final override = debugIsRunningInFlatpakOverride;
  if (override != null) return override;
  return Platform.isLinux &&
      (Platform.environment['FLATPAK_ID'] != null &&
          Platform.environment['FLATPAK_ID']!.isNotEmpty);
}

/// Test-only override for the Flatpak sandbox detection. `null` (default)
/// uses the real `Platform.environment` check; tests set true/false to pin
/// the branch regardless of host.
@visibleForTesting
bool? debugIsRunningInFlatpakOverride;

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

/// True when the settings beamer location points at a detail/editor surface
/// that docks its own action bar against the bottom edge — so the mobile
/// shell slides the bottom nav out of the way and the page owns the whole
/// bottom edge. Covers the entity-definition editors (categories, habits,
/// labels, dashboards, measurables, per-project), the agent template/soul
/// editors, and the sync conflict resolver. The list/browse pages keep the
/// bar: they are ordinary browse surfaces. Pure function of router state.
///
/// Editor surfaces that are *pushed* on top of another settings route rather
/// than being routes themselves (the AI provider connect form, the agent
/// template editor opened from an instance's internals, the evolution chat)
/// keep the URL of the page they were pushed from, so they can't be matched
/// here — they escape the nav by pushing onto the root navigator via
/// `bottomNavSafeNavigatorOf` instead.
bool settingsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! SettingsLocation) return false;
  final segments = location.state.uri.pathSegments;
  if (segments.length < 3 || segments.first != 'settings') return false;
  return switch (segments[1]) {
    'categories' || 'labels' || 'dashboards' || 'measurables' => true,
    // `/settings/habits/search/<term>` is the habits list with a filter
    // applied, not an editor — the bar stays. `by_id` only counts as an
    // editor with an actual id: the bare `/settings/habits/by_id` (e.g. a
    // truncated deep link) renders the list page.
    'habits' =>
      segments[2] == 'create' ||
          (segments[2] == 'by_id' && segments.length >= 4),
    // Projects has no list page under settings — only `/settings/projects/
    // <projectId>` editors. The reserved `create` slug is deliberately not
    // rendered by [SettingsLocation] (creation runs in a modal launched from
    // the Projects tab, with no route of its own), so a stale deep link to it
    // must not hide the bar over the bare settings root.
    'projects' => segments[2] != 'create',
    // Agent template/soul editors (`create` + per-id edit) dock a
    // `FormBottomBar`. The `/review` history surfaces and the read-only
    // instance detail keep the bar — they are browse surfaces; the evolution
    // chat pushed from a review page escapes the nav via the root navigator.
    'agents' =>
      (segments[2] == 'templates' || segments[2] == 'souls') &&
          segments.length >= 4 &&
          segments.last != 'review',
    // Sync conflict resolver detail (`/advanced/conflicts/<id>`) docks a
    // `ConflictFooter`. The conflicts list keeps the bar, and the entry
    // editor opened for a manual merge (`/edit`) is the journal editor — it
    // manages its own bottom inset, so it stays out.
    'advanced' =>
      segments[2] == 'conflicts' &&
          segments.length >= 4 &&
          segments.last != 'edit',
    _ => false,
  };
}

/// Clamps a raw navigation index into `[0, itemCount - 1]` so a stale index
/// from the nav stream cannot go out of bounds when feature flags shrink the
/// destinations list.
int clampNavigationIndex({required int rawIndex, required int itemCount}) {
  if (rawIndex < 0) return 0;
  return rawIndex > itemCount - 1 ? itemCount - 1 : rawIndex;
}

enum _AppNavigationDestinationKind {
  tasks,
  dailyOs,
  projects,
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

  /// Whether this destination is part of the mobile bar's base line-up —
  /// the slots that survive even the narrowest window. Tasks and Daily OS
  /// are the most important pages — Daily OS never overflows — and
  /// Journal keeps its slot alongside them. The remaining destinations
  /// start out behind the More sheet (which is also where newly toggled
  /// pages appear) and are promoted into their own slots as window width
  /// allows (see [DesignSystemFiveSlotNavBar.comfortableSlotWidth]); once
  /// everything fits, the More slot disappears.
  bool get isMobilePrimary => switch (kind) {
    _AppNavigationDestinationKind.tasks ||
    _AppNavigationDestinationKind.dailyOs ||
    _AppNavigationDestinationKind.journal => true,
    _AppNavigationDestinationKind.projects ||
    _AppNavigationDestinationKind.habits ||
    _AppNavigationDestinationKind.dashboards ||
    _AppNavigationDestinationKind.settings => false,
  };

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

  DesignSystemFiveSlotNavBarItem toFiveSlotItem({
    required bool active,
    required VoidCallback onTap,
  }) {
    return DesignSystemFiveSlotNavBarItem(
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

  /// Merged once: recreating the merge on every rebuild would make the
  /// enclosing [ListenableBuilder] resubscribe to both delegates each
  /// frame the nav-index stream emits.
  late final Listenable _routeChangeListenable = Listenable.merge([
    navService.tasksDelegate,
    navService.settingsDelegate,
  ]);

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
        final index = clampNavigationIndex(
          rawIndex: rawIndex,
          itemCount: itemCount,
        );

        final isWide = isDesktopLayout(context);
        navService.isDesktopMode = isWide;

        final beamerChildren = [
          Beamer(routerDelegate: navService.tasksDelegate),
          if (isDailyOsPageEnabled)
            Beamer(routerDelegate: navService.calendarDelegate),
          if (isProjectsPageEnabled)
            Beamer(routerDelegate: navService.projectsDelegate),
          if (isHabitsPageEnabled)
            Beamer(routerDelegate: navService.habitsDelegate),
          if (isDashboardsPageEnabled)
            Beamer(routerDelegate: navService.dashboardsDelegate),
          Beamer(routerDelegate: navService.journalDelegate),
          Beamer(routerDelegate: navService.settingsDelegate),
        ];

        // Listen to the tasks and settings delegates so the mobile shell
        // rebuilds when their routes change (push to / pop from task
        // details, into / out of settings entity editors). That's how we
        // know whether to hide the mobile bottom nav.
        // See [_isTaskDetailRoute] and [settingsRouteHidesBottomNav].
        return ListenableBuilder(
          listenable: _routeChangeListenable,
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

    // Settings detail/editor routes (category/habit/label/dashboard/
    // measurable/project editors, agent template & soul editors, the sync
    // conflict resolver — not the list pages) slide the bar away instead of
    // removing it: nothing replaces the bar there, so an instant unmount
    // would read as a jumpy glitch rather than a handoff to a page-owned
    // surface.
    final slideNavAway =
        destinations[index].kind == _AppNavigationDestinationKind.settings &&
        settingsRouteHidesBottomNav(
          navService.settingsDelegate.currentBeamLocation,
        );

    // The bar fills with as many destinations as fit comfortably at the
    // current window width and text scale. The base line-up is Tasks,
    // Daily OS (when enabled), Logbook, plus More for everything else —
    // that's also where newly toggled pages surface. As space grows,
    // overflow destinations are promoted out of the More sheet in nav
    // order, each landing in its canonical position with More pinned
    // last, so resizing only ever adds or removes slots — nothing
    // reshuffles. Once every destination fits, the More slot disappears
    // entirely. Entries carry their full destination index so taps route
    // through the same NavService indices the IndexedStack uses. Built
    // lazily: on routes that suppress the bar entirely the slot config
    // (and its per-slot closures) is never constructed.
    DesignSystemBottomNavigationBar buildBottomNavigationBar() {
      double slotWidth(String label) =>
          DesignSystemFiveSlotNavBar.comfortableSlotWidth(context, label);
      final availableWidth = DesignSystemFiveSlotNavBar.availableRowWidth(
        context,
      );
      final showAllDestinations = DesignSystemFiveSlotNavBar.allSlotsFit(
        context,
        [for (final destination in destinations) destination.label],
      );

      // Greedy promotion in nav order, stopping at the first destination
      // that no longer fits alongside the base line-up and the More slot.
      // Stopping (rather than skipping ahead to a narrower label) keeps
      // the promoted set a stable prefix: a given window width always
      // shows the same line-up regardless of how it was reached.
      final promoted = <int>{};
      if (!showAllDestinations) {
        var used = slotWidth(context.messages.navTabTitleMore);
        for (final destination in destinations) {
          if (destination.isMobilePrimary) {
            used += slotWidth(destination.label);
          }
        }
        for (var i = 0; i < destinations.length; i++) {
          if (destinations[i].isMobilePrimary) continue;
          final width = slotWidth(destinations[i].label);
          if (used + width > availableWidth) break;
          promoted.add(i);
          used += width;
        }
      }

      final primaryEntries = <(int, _AppNavigationDestination)>[];
      final overflowEntries = <(int, _AppNavigationDestination)>[];
      for (var i = 0; i < destinations.length; i++) {
        (showAllDestinations ||
                    destinations[i].isMobilePrimary ||
                    promoted.contains(i)
                ? primaryEntries
                : overflowEntries)
            .add((i, destinations[i]));
      }

      // Only a destination actually living behind More may lend the More
      // slot its name — a promoted destination lights up its own slot.
      final activeOverflowDestination =
          overflowEntries.any(
            (entry) => entry.$1 == index,
          )
          ? destinations[index]
          : null;

      return DesignSystemBottomNavigationBar(
        items: [
          for (final (i, destination) in primaryEntries)
            destination.toFiveSlotItem(
              active: i == index,
              onTap: () => navService.tapIndex(i),
            ),
          if (overflowEntries.isNotEmpty)
            DesignSystemFiveSlotNavBarItem(
              // While an overflow destination is on screen the More slot
              // takes its name and the active tint so the bar reflects
              // location even though the destination has no own slot. For
              // screen readers the slot keeps announcing the More
              // affordance alongside the destination name — activating it
              // still opens the sheet, not the destination.
              label:
                  activeOverflowDestination?.label ??
                  context.messages.navTabTitleMore,
              icon: const Icon(Icons.more_horiz_rounded),
              active: activeOverflowDestination != null,
              semanticsLabel: activeOverflowDestination != null
                  ? '${activeOverflowDestination.label} — '
                        '${context.messages.navTabMoreSemanticsLabel(overflowEntries.length)}'
                  : context.messages.navTabMoreSemanticsLabel(
                      overflowEntries.length,
                    ),
              onTap: () => showMobileNavMoreSheet(
                context: context,
                items: [
                  for (final (i, destination) in overflowEntries)
                    MobileNavMoreSheetItem(
                      label: destination.label,
                      // The bare icon, not the badge-wrapped mobile one:
                      // sheet rows have a trailing slot (like the desktop
                      // sidebar), so a count pill there beats a badge
                      // cramped over the icon.
                      icon: destination.iconBuilder(active: i == index),
                      trailing: destination.trailingBuilder?.call(
                        active: i == index,
                      ),
                      active: i == index,
                      // The index is resolved at tap time, not captured: a
                      // flag change (e.g. synced from another device) while
                      // the sheet is open re-numbers the destinations, and a
                      // stale index would route the tap to the wrong tab.
                      onSelected: () {
                        final tapIndex = _currentDestinationIndex(
                          destination.kind,
                        );
                        if (tapIndex != null) navService.tapIndex(tapIndex);
                      },
                    ),
                ],
              ),
            ),
        ],
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const IncomingVerificationWrapper(),
          // The scope keeps `occupiedHeight` (and every page padding by it)
          // in sync with the indicator row riding above the bar, so the
          // indicators never cover scroll content or floating actions.
          _MobileNavOverlayHeightScope(
            navBarVisible: showBottomNav,
            child: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < beamerChildren.length; i++)
                  TickerMode(
                    enabled: i == index,
                    child: beamerChildren[i],
                  ),
              ],
            ),
          ),
          if (showBottomNav) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SlideAwayBottomNav(
                hidden: slideNavAway,
                child: buildBottomNavigationBar(),
              ),
            ),
            // The time/audio recording indicators ride above the bar but
            // are deliberately not part of the slide-away subtree: a
            // running timer or recording must stay visible inside settings
            // definition surfaces. When the bar slides away they animate
            // down to the bottom safe-area edge in the same motion.
            AnimatedPositioned(
              duration: reduceMotion
                  ? Duration.zero
                  : _SlideAwayBottomNav.slideDuration,
              curve: _SlideAwayBottomNav.slideCurve,
              left: 0,
              right: 0,
              bottom: slideNavAway
                  ? MediaQuery.paddingOf(context).bottom
                  : DesignSystemFiveSlotNavBar.barHeight(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const TimeRecordingIndicator(),
                  // Audio indicator is omitted on Flatpak builds (MediaKit
                  // compatibility issues). Spacer lives inside the same
                  // conditional so it doesn't dangle when only the time
                  // indicator is visible.
                  if (!_isRunningInFlatpak()) ...[
                    const SizedBox(width: 4),
                    const AudioRecordingIndicator(),
                  ],
                ],
              ),
            ),
          ],
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
        kind: _AppNavigationDestinationKind.dailyOs,
        label: context.messages.navTabTitleCalendar,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.today_rounded : Icons.today_outlined),
        // Month calendar (design handoff sidebar spec) renders beneath
        // the row only while Daily OS is the active tab — same slot the
        // Tasks destination uses for its saved-filters tree. The Time
        // Analysis sub-entry sits under the calendar and opens the
        // full-screen analytics surface at /calendar/time.
        expandedChildBuilder: () => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DailyOsSidebarCalendar(),
            InsightsSidebarEntry(),
          ],
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.projects,
        label: context.messages.navTabTitleProjects,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.folder_rounded : Icons.folder_outlined),
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

    final enabledKinds = _enabledDestinationKinds(
      isProjectsPageEnabled: isProjectsPageEnabled,
      isDailyOsPageEnabled: isDailyOsPageEnabled,
      isHabitsPageEnabled: isHabitsPageEnabled,
      isDashboardsPageEnabled: isDashboardsPageEnabled,
    );
    final result = allDestinations
        .where((destination) => enabledKinds.contains(destination.kind))
        .toList(growable: false);
    // The More sheet resolves tap indices from _enabledDestinationKinds
    // while this list (ordered by `allDestinations`) drives the
    // IndexedStack — a reorder of one without the other silently
    // misroutes taps, so pin their agreement.
    assert(
      listEquals(
        result.map((destination) => destination.kind).toList(),
        enabledKinds,
      ),
      'allDestinations order must match _enabledDestinationKinds',
    );
    return result;
  }

  /// Destination index of [kind] as enabled *right now*, read directly
  /// from the NavService flag getters — the same ordering
  /// [_buildNavigationDestinations] uses via [_enabledDestinationKinds].
  /// Resolved at tap time by the More sheet so a flag change while the
  /// sheet is open cannot route a tap through a stale index. Null when
  /// [kind] got disabled in the meantime.
  int? _currentDestinationIndex(_AppNavigationDestinationKind kind) {
    final index = _enabledDestinationKinds(
      isProjectsPageEnabled: navService.isProjectsPageEnabled,
      isDailyOsPageEnabled: navService.isDailyOsPageEnabled,
      isHabitsPageEnabled: navService.isHabitsPageEnabled,
      isDashboardsPageEnabled: navService.isDashboardsPageEnabled,
    ).indexOf(kind);
    return index == -1 ? null : index;
  }
}

/// Feeds [DesignSystemBottomNavigationOverlayHeight] with the rendered
/// height of the indicator row riding above the mobile nav bar, mirroring
/// the indicators' own visibility rules: the time indicator shows while
/// [TimeService] streams a running entry, the audio indicator while a
/// recording runs outside its modal (and outside the Flatpak sandbox,
/// which omits the indicator entirely). While the shell hides the bar —
/// task-detail routes — the overlay is hidden with it, so no height
/// applies. [child] is a prebuilt subtree; only widgets depending on the
/// inherited height rebuild when an indicator appears or disappears.
class _MobileNavOverlayHeightScope extends ConsumerWidget {
  const _MobileNavOverlayHeightScope({
    required this.navBarVisible,
    required this.child,
  });

  final bool navBarVisible;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same guard as AudioRecordingIndicator: if the recorder controller
    // fails to build (MediaKit/audio issues), the indicator renders
    // nothing, so no height applies either.
    bool audioIndicatorVisible;
    try {
      audioIndicatorVisible =
          !_isRunningInFlatpak() &&
          ref.watch(
            audioRecorderControllerProvider.select(
              (state) =>
                  state.status == AudioRecorderStatus.recording &&
                  !state.modalVisible,
            ),
          );
    } catch (_) {
      audioIndicatorVisible = false;
    }

    return StreamBuilder<JournalEntity?>(
      stream: getIt<TimeService>().getStream(),
      builder: (context, snapshot) {
        final timeIndicatorVisible = snapshot.data != null;
        var height = 0.0;
        if (navBarVisible) {
          // Mirror the rendered indicator heights: the time indicator is
          // AudioRecordingIndicatorConstants.indicatorHeight tall, the
          // audio indicator spacing.step6 — the row is as tall as the
          // tallest visible one.
          height = math.max(
            timeIndicatorVisible
                ? AudioRecordingIndicatorConstants.indicatorHeight
                : 0,
            audioIndicatorVisible ? context.designTokens.spacing.step6 : 0,
          );
        }
        return DesignSystemBottomNavigationOverlayHeight(
          height: height,
          child: child,
        );
      },
    );
  }
}

/// Slides the docked bottom nav bar below the screen edge when [hidden],
/// and back up when shown again. The bar stays mounted throughout so both
/// directions animate; while hidden it is inert for pointers and screen
/// readers. When the platform asks for reduced motion the slide snaps.
class _SlideAwayBottomNav extends StatelessWidget {
  const _SlideAwayBottomNav({required this.hidden, required this.child});

  static const Duration slideDuration = Duration(milliseconds: 450);

  /// Matches the five-slot bar's tint ease so nav transitions share one
  /// motion language (`cubic-bezier(0.25, 1, 0.5, 1)` — easeOutQuart).
  static const Curve slideCurve = DesignSystemFiveSlotNavBar.tintCurve;

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      excluding: hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedSlide(
          // Offset is in multiples of the child's own size, so (0, 1)
          // moves the bar down by exactly its rendered height — flush
          // off-screen, since it docks at the bottom edge.
          offset: hidden ? const Offset(0, 1) : Offset.zero,
          duration: reduceMotion ? Duration.zero : slideDuration,
          curve: slideCurve,
          child: child,
        ),
      ),
    );
  }
}

/// The enabled destination kinds in navigation order — the single source
/// of truth for how flags map to tab indices, shared by the destination
/// builder and the More sheet's tap-time index resolution.
List<_AppNavigationDestinationKind> _enabledDestinationKinds({
  required bool isProjectsPageEnabled,
  required bool isDailyOsPageEnabled,
  required bool isHabitsPageEnabled,
  required bool isDashboardsPageEnabled,
}) {
  return [
    _AppNavigationDestinationKind.tasks,
    if (isDailyOsPageEnabled) _AppNavigationDestinationKind.dailyOs,
    if (isProjectsPageEnabled) _AppNavigationDestinationKind.projects,
    if (isHabitsPageEnabled) _AppNavigationDestinationKind.habits,
    if (isDashboardsPageEnabled) _AppNavigationDestinationKind.dashboards,
    _AppNavigationDestinationKind.journal,
    _AppNavigationDestinationKind.settings,
  ];
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
/// active-status surfaces as a family of distinct cards, ordered live-first:
/// the active audio recording (red), the running timer (teal), then the
/// optional inline agent queue (a quieter neutral card). Each card carries its
/// own surface and self-collapses when inactive; animated gaps appear only
/// between cards that are both visible, so the stack grows and shrinks
/// smoothly without leaving phantom spacing.
class _DesktopSidebarAboveSettings extends ConsumerWidget {
  const _DesktopSidebarAboveSettings({required this.showWakeQueue});

  final bool showWakeQueue;

  Widget _gap(BuildContext context, {required bool visible}) {
    final tokens = context.designTokens;
    return AnimatedSize(
      duration: SidebarAudioRecordingSection.animationDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: SizedBox(height: visible ? tokens.spacing.step4 : 0),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakesVisible =
        showWakeQueue && sidebarWakeQueueHasVisibleContent(ref);
    final audioVisible =
        !_isRunningInFlatpak() && sidebarAudioRecordingHasVisibleContent(ref);

    return StreamBuilder<JournalEntity?>(
      stream: getIt<TimeService>().getStream(),
      builder: (context, snapshot) {
        final hasTimer = snapshot.data != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isRunningInFlatpak()) const SidebarAudioRecordingSection(),
            _gap(context, visible: audioVisible && (hasTimer || wakesVisible)),
            const SidebarTimerSection(),
            _gap(context, visible: hasTimer && wakesVisible),
            if (showWakeQueue) const SidebarWakeQueue(),
          ],
        );
      },
    );
  }
}
