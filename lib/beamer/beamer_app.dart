import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/beamer/chrome/mobile_activity_island.dart';
import 'package:lotti/beamer/chrome/sidebar_activity_summary.dart';
import 'package:lotti/beamer/desktop_menu.dart';
import 'package:lotti/beamer/drawer_first_back_button_dispatcher.dart';
import 'package:lotti/beamer/locations/events_location.dart';
import 'package:lotti/beamer/locations/goals_location.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/beamer/locations/projects_location.dart';
import 'package:lotti/beamer/locations/relationships_location.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/beamer/recent_search_opener.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_view_side_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/demo/ui/demo_mode_banner.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/journal/create/create_entry.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/command_palette.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_category_options.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/features/lockdown/ui/lockdown_logo_menu.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/profiles/service/profile_switch_chrome.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/ui/recent_searches_section.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/ui/pages/outbox/sync_queue_counts.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/sidebar_saved_task_filters.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/manual_language_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/uuid.dart';
import 'package:lotti/widgets/app_closing_overlay.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_drawer.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

part 'beamer_app_chrome_part.dart';
part 'beamer_app_routes_part.dart';
part 'beamer_app_layout_part.dart';
part 'beamer_app_root_part.dart';

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
// Assigned by tests outside DCM's `lib`-only usage graph.
// ignore: unused-code
bool? debugIsRunningInFlatpakOverride;

enum _AppNavigationDestinationKind {
  tasks,
  dailyOs,
  projects,
  goals,
  habits,
  dashboards,
  people,
  journal,
  events,
  settings,
}

class _AppNavigationDestination {
  const _AppNavigationDestination({
    required this.kind,
    required this.label,
    required this.iconBuilder,
    this.trailingBuilder,
    this.expandedChildBuilder,
  });

  final _AppNavigationDestinationKind kind;
  final String label;

  /// Icon for this destination, shared by the desktop sidebar rows, the
  /// mobile drawer's rows and the Recents section's surface marks.
  final Widget Function({required bool active}) iconBuilder;

  /// Optional trailing widget shown on the right side of the desktop sidebar
  /// row, such as a status or count indicator.
  final Widget Function({required bool active})? trailingBuilder;

  /// Optional builder for a subtree rendered immediately under the
  /// destination row when it is the active tab and the sidebar is expanded.
  /// The Tasks destination uses this to host the saved-filters treeview.
  final Widget Function()? expandedChildBuilder;

  /// [includeExpandedChild] drops the under-row subtree (saved filters, the
  /// month calendar) — lockdown uses this because those subtrees name things
  /// outside the locked category. [expandedChild] replaces this
  /// destination's own subtree when included: the mobile drawer hosts the
  /// saved filters with a callback that closes it.
  DesktopSidebarDestination toDesktopSidebarDestination({
    bool includeExpandedChild = true,
    Widget Function()? expandedChild,
  }) {
    return DesktopSidebarDestination(
      label: label,
      iconBuilder: iconBuilder,
      trailingBuilder: trailingBuilder,
      expandedChildBuilder: includeExpandedChild
          ? expandedChild ?? expandedChildBuilder
          : null,
    );
  }
}

/// The destinations that stay reachable while lockdown is active — exactly
/// those whose content is category-scoped at its source: Tasks and Logbook
/// through `JournalPageController`, Habits through `HabitsController`,
/// Insights through the dashboards providers, and Goals through the goal
/// identities' allowed categories. Every other tab (day plan, projects,
/// people, events, settings) is category-agnostic or lists definitions by
/// name, so it is hidden rather than partially filtered.
const Set<_AppNavigationDestinationKind> _lockdownVisibleKinds = {
  _AppNavigationDestinationKind.tasks,
  _AppNavigationDestinationKind.journal,
  _AppNavigationDestinationKind.habits,
  _AppNavigationDestinationKind.dashboards,
  _AppNavigationDestinationKind.goals,
};

/// The enabled destinations as a sidebar lays them out: Settings pinned
/// apart at the bottom, everything else in the scrolling list above it.
///
/// Shared by the desktop rail and the mobile drawer, which host the same
/// sidebar and must agree on which row is active.
class _SidebarDestinations {
  _SidebarDestinations(List<_AppNavigationDestination> all, int activeIndex)
    : main = [
        for (final destination in all)
          if (destination.kind != _AppNavigationDestinationKind.settings)
            destination,
      ],
      settingsIndex = all.indexWhere(
        (destination) =>
            destination.kind == _AppNavigationDestinationKind.settings,
      ) {
    settings = settingsIndex >= 0 ? all[settingsIndex] : null;
    isSettingsActive = activeIndex == settingsIndex;
    mainActiveIndex = isSettingsActive
        ? 0
        : math.max(0, main.indexOf(all[activeIndex]));
  }

  /// Every destination except Settings, in navigation order.
  final List<_AppNavigationDestination> main;

  /// Index of Settings in the full destination list, or -1 without one.
  final int settingsIndex;

  late final _AppNavigationDestination? settings;
  late final bool isSettingsActive;

  /// Index into [main] of the active destination; 0 while Settings is
  /// active, where the list highlights nothing (see [isSettingsActive]).
  late final int mainActiveIndex;
}

class AppScreen extends ConsumerStatefulWidget {
  const AppScreen({super.key});

  @override
  ConsumerState<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends ConsumerState<AppScreen> {
  late final DomainLogger _logger;

  NavService get navService => ref.read(navServiceProvider);

  /// Merged once: recreating the merge on every rebuild would make the
  /// enclosing [ListenableBuilder] resubscribe to the delegates each
  /// frame the nav-index stream emits.
  late final Listenable _routeChangeListenable = Listenable.merge([
    navService.tasksDelegate,
    navService.projectsDelegate,
    navService.settingsDelegate,
    navService.goalsDelegate,
    navService.habitsDelegate,
    navService.relationshipsDelegate,
    // So the launcher unmounts on an entry's page, where the page docks its
    // own action bar, and comes back when the page pops. See
    // [isLogbookEntryDetailRoute].
    navService.journalDelegate,
    // Not for hiding the bar — the events tab keeps it on an event's page —
    // but so the launcher drops the events tab's create action there. See
    // [isEventDetailRoute].
    navService.eventsDelegate,
  ]);

  /// Identity for the tab content across the desktop/mobile breakpoint.
  ///
  /// The two layouts are structurally different trees, so without a
  /// [GlobalKey] crossing the breakpoint UNMOUNTS every `Beamer` and inflates
  /// a fresh one. That is not merely wasteful: `BeamerState.dispose` nulls its
  /// delegate's `parent`, and the replacement's `didChangeDependencies` has
  /// already short-circuited on the parent it still had — so every nested
  /// delegate ends up orphaned from the root router, and every page stack,
  /// scroll offset and piece of in-flight state is thrown away. Keyed, the
  /// subtree is REPARENTED instead, and a resize keeps the user exactly where
  /// they were.
  ///
  /// The form-factor change still has to reach the delegates, since the
  /// locations branch on it — `NavService.isDesktopMode`'s setter does that.
  final GlobalKey _contentStackKey = GlobalKey(debugLabel: 'app-content-stack');

  /// Open state of the mobile sidebar navigation's drawer. Held outside the
  /// drawer's host so the launcher's menu button can open it and every choice
  /// made inside it can close it, and app-wide rather than here because the
  /// root back dispatcher in [MyBeamerApp] has to close it too.
  late final MobileNavigationDrawerController _mobileDrawer = ref.read(
    mobileNavigationDrawerControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    _logger = ref.read(domainLoggerProvider);
    _routeChangeListenable.addListener(_closeMobileDrawerOnRouteChange);
  }

  @override
  void dispose() {
    _routeChangeListenable.removeListener(_closeMobileDrawerOnRouteChange);
    super.dispose();
  }

  /// Any route change is a choice that has been made, so an open drawer
  /// gets out of its way. This is what closes the drawer behind the rows
  /// that navigate on their own — the running timer opening its task, an
  /// agent wake opening its agent — without each of them having to know a
  /// drawer exists.
  void _closeMobileDrawerOnRouteChange() {
    if (_mobileDrawer.isOpen) _mobileDrawer.close();
  }

  /// The one tab host, shared by both layouts. Only the active tab animates
  /// and can take focus or participate in Hero transitions; the rest stay
  /// mounted and offstage. Root navigation scans current nested routes even
  /// inside an IndexedStack, so offstage alone does not isolate their Heroes.
  Widget _buildContentStack({
    required int index,
    required List<Widget> beamerChildren,
  }) {
    return KeyedSubtree(
      key: _contentStackKey,
      child: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < beamerChildren.length; i++)
            TickerMode(
              enabled: i == index,
              child: ExcludeFocus(
                excluding: i != index,
                child: HeroMode(
                  enabled: i == index,
                  child: beamerChildren[i],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _notLoggedInToastShown = false;

  /// Guards against the FTUE welcome being shown more than once per
  /// [AppScreen] lifetime: [shouldAutoShowOnboardingProvider] can re-emit
  /// `data(true)` (e.g. when the What's New unseen→seen transition
  /// invalidates it) while the welcome is already open, which would otherwise
  /// stack a second modal and double-count the show.
  bool _onboardingWelcomeShown = false;

  /// Guards against the Daily OS onboarding walkthrough being armed more than
  /// once per [AppScreen] lifetime, mirroring [_onboardingWelcomeShown].
  bool _dailyOsOnboardingShown = false;

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

  /// Shows the FTUE welcome and records the show in its persisted cadence
  /// (see `onboarding_trigger_service.dart`) so the auto-show gate can bound
  /// how many times -- and for how long -- it keeps re-appearing.
  Future<void> _showOnboardingWelcome() async {
    if (!mounted) return;
    // `recordShown` / `markCompleted` log-and-swallow their own `SettingsDb`
    // failures (see `OnboardingWelcomeCadence`), so a bookkeeping hiccup never
    // surfaces here as an uncaught async error nor blocks the welcome — which
    // matters because this whole method runs via `unawaited(...)`.
    await ref.read(onboardingWelcomeCadenceProvider.notifier).recordShown();
    if (!mounted) return;
    unawaited(
      OnboardingWelcomeModal.show(
        context,
        // Connecting a provider retires the welcome for good; a plain skip
        // leaves the shown-count/window grace period to keep offering it.
        onCompleted: () => unawaited(
          ref.read(onboardingWelcomeCadenceProvider.notifier).markCompleted(),
        ),
        // The welcome no longer owns the slot on close — let the Daily OS
        // onboarding gate re-evaluate. (Provider-connect completion re-checks
        // too once the readiness seam is wired in a later phase; until then
        // Daily OS stays gated on `providerReady`.)
        onDismiss: () =>
            ref.invalidate(shouldAutoShowDailyOsOnboardingProvider),
      ),
    );
  }

  /// Arms the Daily OS onboarding walkthrough once it wins the auto-show slot
  /// (after What's New and the general FTUE welcome). Switches to the Daily OS
  /// tab so the spotlight has its surface, starts the session (which `DayPage`
  /// observes to mount the spotlight over the empty-Day CTA). The host records
  /// the show only once the spotlight is actually visible.
  Future<bool> _showDailyOsOnboarding() async {
    if (!mounted) return false;
    // Eligibility is asynchronous. Re-read it in the presentation callback so
    // a plan sync or date change between the original emission and this frame
    // cannot arm a stale walkthrough session.
    if (!await ref.read(shouldAutoShowDailyOsOnboardingProvider.future)) {
      return false;
    }
    if (!mounted) return false;
    final targetDate = ref.read(dailyOsNextSelectedDateProvider);
    // Eligibility already requires the Daily OS page flag, so only the
    // current tab gates the switch.
    if (navService.index != navService.calendarIndex) {
      navService.tapIndex(navService.calendarIndex);
    }
    ref
        .read(dailyOsOnboardingSessionControllerProvider.notifier)
        .start(
          targetDate: targetDate,
        );
    return true;
  }

  Future<void> _tryShowDailyOsOnboarding() async {
    try {
      final armed = await _showDailyOsOnboarding();
      if (!armed) _dailyOsOnboardingShown = false;
    } catch (error, stack) {
      _dailyOsOnboardingShown = false;
      _logger.error(
        LogDomain.onboarding,
        error,
        stackTrace: stack,
        subDomain: 'showDailyOsOnboarding',
      );
    }
  }

  /// The delegates of the tabs that stay reachable under lockdown — see
  /// [_lockdownVisibleKinds]. Delegates, not indices: an index shifts when a
  /// feature flag toggles a tab ahead of it, a delegate never does.
  Set<BeamerDelegate> _lockdownDelegates() => {
    navService.tasksDelegate,
    navService.journalDelegate,
    navService.habitsDelegate,
    navService.dashboardsDelegate,
    navService.goalsDelegate,
  };

  /// The guard on NavService is what keeps keyboard shortcuts, the command
  /// palette and path-based beams off hidden tabs for the whole active
  /// period; the rail cut alone only covers sidebar taps. Desktop-only —
  /// see the lockdown listener in [build].
  void _syncLockdownGuard({
    required bool isWide,
    required LockdownState lockdown,
  }) {
    navService.allowedTabDelegates = isWide && lockdown.isActive
        ? _lockdownDelegates()
        : null;
  }

  /// Brings the app onto a lockdown-safe tab and resets every surviving tab
  /// to its root — without activating any of them — so neither a foreign tab
  /// nor a detail pane opened before the lockdown began can stay on screen
  /// once it is active. Assumes the navigation guard is already set.
  void _enterLockdown() {
    if (!navService.isTabAllowed(navService.index)) {
      navService.setIndex(0);
    }
    _lockdownDelegates().forEach(navService.resetTabRootWithinTab);
  }

  @override
  Widget build(BuildContext context) {
    // Reset toast guard on login, and listen for login-gate events from outbox.
    ref
      ..listen(lockdownControllerProvider, (prev, next) {
        // Lockdown is a desktop feature: the mobile layout has no logo menu
        // to exit through — the experimental sidebar drawer shows the logo,
        // but inert — and shows every destination, so the navigation guard
        // (and the tab reset) apply only while the desktop layout is up.
        // `_syncLockdownGuard` re-evaluates on every build, which is how a
        // breakpoint crossing mid-lockdown lifts or re-applies the guard.
        final isWide = isDesktopLayout(context);
        _syncLockdownGuard(isWide: isWide, lockdown: next);
        if (next.isActive && isWide) _enterLockdown();
      })
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
            _logger.error(
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
            _logger.error(
              LogDomain.whatsNew,
              error,
              stackTrace: stack,
              subDomain: 'shouldAutoShowWhatsNew',
            );
          },
        );
      })
      // When What's New is dismissed, re-check whether either onboarding
      // surface should show.
      ..listen(whatsNewControllerProvider, (prev, next) {
        final prevHasUnseen = prev?.asData?.value.hasUnseenRelease ?? true;
        final nextHasUnseen = next.asData?.value.hasUnseenRelease ?? true;

        // If What's New transitioned from unseen to seen, re-check both
        // onboarding gates; both sequence behind What's New.
        if (prevHasUnseen && !nextHasUnseen) {
          ref
            ..invalidate(shouldAutoShowOnboardingProvider)
            ..invalidate(shouldAutoShowDailyOsOnboardingProvider);
        }
      })
      // Auto-show the FTUE welcome on first launch (and, within its
      // persisted grace budget, subsequent launches) once What's New is out
      // of the way. This is the only first-run setup path: the welcome owns
      // connecting a provider, and a user who never connects recovers via the
      // top-level Settings > Onboarding replay entry (and ordinary AI
      // settings).
      ..listen(shouldAutoShowOnboardingProvider, (prev, next) {
        next.when(
          data: (shouldShow) {
            if (shouldShow && mounted && !_onboardingWelcomeShown) {
              _onboardingWelcomeShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  unawaited(_showOnboardingWelcome());
                }
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            _logger.error(
              LogDomain.onboarding,
              error,
              stackTrace: stack,
              subDomain: 'shouldAutoShowOnboarding',
            );
          },
        );
      })
      // Auto-show the Daily OS onboarding walkthrough once it wins the slot.
      // Its own eligibility gate keeps it sequenced behind What's New and the
      // FTUE welcome, so being last in this chain does not race them.
      ..listen(shouldAutoShowDailyOsOnboardingProvider, (prev, next) {
        next.when(
          data: (shouldShow) {
            if (shouldShow && mounted && !_dailyOsOnboardingShown) {
              _dailyOsOnboardingShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  unawaited(_tryShowDailyOsOnboarding());
                }
              });
            }
          },
          loading: () {},
          error: (error, stack) {
            _logger.error(
              LogDomain.onboarding,
              error,
              stackTrace: stack,
              subDomain: 'shouldAutoShowDailyOsOnboarding',
            );
          },
        );
      });

    return StreamBuilder<int>(
      stream: navService.getIndexStream(),
      // Seeded from the service, not from 0: nav state is restored before
      // `runApp`, so by the time this subscribes the index has already been
      // set — and a stream delivers even a replayed value asynchronously.
      // Without this the FIRST frame renders Tasks and only then swaps to the
      // restored tab, which is the flash the restore exists to avoid.
      initialData: navService.index,
      builder: (context, snapshot) {
        final rawIndex = snapshot.data ?? navService.index;
        final isProjectsPageEnabled = navService.isProjectsPageEnabled;
        final isDailyOsPageEnabled = navService.isDailyOsPageEnabled;
        final isHabitsPageEnabled = navService.isHabitsPageEnabled;
        final isDashboardsPageEnabled = navService.isDashboardsPageEnabled;
        final isEventsPageEnabled = navService.isEventsPageEnabled;
        final isUnifiedGoalsPageEnabled = navService.isUnifiedGoalsPageEnabled;
        final isRelationshipsPageEnabled =
            navService.isRelationshipsPageEnabled;

        final destinations = _buildNavigationDestinations(
          context: context,
          isProjectsPageEnabled: isProjectsPageEnabled,
          isDailyOsPageEnabled: isDailyOsPageEnabled,
          isUnifiedGoalsPageEnabled: isUnifiedGoalsPageEnabled,
          isHabitsPageEnabled: isHabitsPageEnabled,
          isDashboardsPageEnabled: isDashboardsPageEnabled,
          isEventsPageEnabled: isEventsPageEnabled,
          isRelationshipsPageEnabled: isRelationshipsPageEnabled,
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
        _syncLockdownGuard(
          isWide: isWide,
          lockdown: ref.watch(lockdownControllerProvider),
        );

        final beamerChildren = [
          Beamer(routerDelegate: navService.tasksDelegate),
          if (isDailyOsPageEnabled)
            Beamer(routerDelegate: navService.calendarDelegate),
          if (isProjectsPageEnabled)
            Beamer(routerDelegate: navService.projectsDelegate),
          if (isUnifiedGoalsPageEnabled)
            Beamer(routerDelegate: navService.goalsDelegate),
          if (isHabitsPageEnabled)
            Beamer(routerDelegate: navService.habitsDelegate),
          if (isDashboardsPageEnabled)
            Beamer(routerDelegate: navService.dashboardsDelegate),
          if (isRelationshipsPageEnabled)
            Beamer(routerDelegate: navService.relationshipsDelegate),
          Beamer(routerDelegate: navService.journalDelegate),
          if (isEventsPageEnabled)
            Beamer(routerDelegate: navService.eventsDelegate),
          Beamer(routerDelegate: navService.settingsDelegate),
        ];

        // Listen to the tasks, journal, projects, settings, goals, habits
        // and relationships delegates so the mobile shell rebuilds when
        // their routes change (push to / pop from task, entry, project, goal
        // or person details, into / out of settings entity editors). That's
        // how we know whether to hide the mobile bottom nav. See
        // [_isTaskDetailRoute], [_isLogbookEntryDetailRoute],
        // [projectsRouteHidesBottomNav], [settingsRouteHidesBottomNav],
        // [goalsRouteHidesBottomNav], [habitsRouteHidesBottomNav] and
        // [peopleRouteHidesBottomNav].
        return ListenableBuilder(
          listenable: _routeChangeListenable,
          builder: (context, _) => _NudgeBannerTopLane(
            surface: _nudgeBannerSurfaceFor(destinations[index].kind),
            compact: !isWide,
            child: isWide
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
          ),
        );
      },
    );
  }
}

/// The enabled destination kinds in navigation order — the single source
/// of truth for how flags map to tab indices, shared by the destination
/// builder and the mobile drawer's tap-time index resolution.
List<_AppNavigationDestinationKind> _enabledDestinationKinds({
  required bool isProjectsPageEnabled,
  required bool isDailyOsPageEnabled,
  required bool isUnifiedGoalsPageEnabled,
  required bool isHabitsPageEnabled,
  required bool isDashboardsPageEnabled,
  required bool isEventsPageEnabled,
  required bool isRelationshipsPageEnabled,
}) {
  return [
    _AppNavigationDestinationKind.tasks,
    if (isDailyOsPageEnabled) _AppNavigationDestinationKind.dailyOs,
    if (isProjectsPageEnabled) _AppNavigationDestinationKind.projects,
    if (isUnifiedGoalsPageEnabled) _AppNavigationDestinationKind.goals,
    if (isHabitsPageEnabled) _AppNavigationDestinationKind.habits,
    if (isDashboardsPageEnabled) _AppNavigationDestinationKind.dashboards,
    if (isRelationshipsPageEnabled) _AppNavigationDestinationKind.people,
    _AppNavigationDestinationKind.journal,
    if (isEventsPageEnabled) _AppNavigationDestinationKind.events,
    _AppNavigationDestinationKind.settings,
  ];
}

/// Composer for the sidebar's `aboveSettings` slot, on the desktop rail and
/// in the mobile drawer alike.
///
/// All transient systems share one compact summary surface. Selecting it
/// expands the detailed recording, timer, and agent controls in place without
/// permanently letting those operational tools displace primary navigation.
class _SidebarAboveSettings extends StatelessWidget {
  const _SidebarAboveSettings();

  @override
  Widget build(BuildContext context) {
    return SidebarActivitySummary(showAudio: !_isRunningInFlatpak());
  }
}
