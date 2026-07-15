import 'dart:async';
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
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/command_palette.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
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
import 'package:lotti/logic/create/create_entry.dart';
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

/// True when the settings beamer location points at a *detail* surface — a
/// terminal page you navigate to, rather than a menu you navigate from — so
/// the mobile shell slides the bottom nav out of the way and the page owns
/// the whole bottom edge. Pure function of router state.
///
/// The split follows the settings tree: the pure navigation menus keep the
/// bar, everything terminal hides it.
///
/// Keeps the bar (menus + browse lists that drill into their own editors):
///   * the settings root `/settings`
///   * the menu hubs `/settings/advanced`, `/settings/sync`,
///     `/settings/definitions` — branch nodes with no page of their own
///   * the entity **list** pages `/settings/{categories,labels,dashboards,
///     measurables,habits}` (incl. the habits `search`/bare-`by_id` list
///     variants)
///   * the sync **conflicts list** `/settings/advanced/conflicts`, and the
///     manual-merge entry editor `/edit` (the journal editor manages its own
///     bottom inset)
///
/// Hides the bar (terminal destinations):
///   * the whole **AI** and **Agents** sections — they are real settings
///     pages (their tree nodes carry a `panel`), and on mobile their tabs
///     swap in place without changing the URL, so the bar hides across the
///     entire section instead of flickering per tab
///   * every **Sync** leaf (`provisioned`, `node-profile`, `backfill`,
///     `stats`, `outbox`, `matrix/maintenance`)
///   * every **Advanced** leaf (`flags` via its own top-level route,
///     `animations`, `logging_domains`, `maintenance`, `onboarding_metrics`,
///     `about`, `health_import`) and the conflict **detail**
///     `/settings/advanced/conflicts/<id>`
///   * the top-level leaves `theming`, `recording-style`, `daily-os`,
///     `speech`, `onboarding`
///   * the entity **editors** (`.../<id>` or `.../create`) for categories,
///     labels, dashboards, measurables, habits, and projects
///
/// Editor surfaces that are *pushed* on top of another settings route rather
/// than being routes themselves (the AI provider connect form, the evolution
/// chat) keep the URL of the page they were pushed from, so they can't be
/// matched here — they escape the nav by pushing onto the root navigator via
/// `bottomNavSafeNavigatorOf` instead.
bool settingsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! SettingsLocation) return false;
  final segments = location.state.uri.pathSegments;
  // The bare `/settings` root is the top-level menu — keep the bar.
  if (segments.length < 2 || segments.first != 'settings') return false;
  return switch (segments[1]) {
    // AI and Agents are full settings pages, not menus: hide the bar across
    // the entire section (landing, per-tab lists, and editors alike).
    'ai' || 'agents' => true,
    // Sync is a menu hub (`/settings/sync`, kept); every child is a terminal
    // detail page (backfill, stats, outbox, node-profile, provisioned,
    // matrix/maintenance) that hides the bar.
    'sync' => segments.length >= 3,
    // Advanced is a menu hub (kept). Its leaves hide, except the conflicts
    // *list* — only the conflict *detail* hides, and the manual-merge entry
    // editor (`/edit`) keeps the bar (it manages its own bottom inset).
    'advanced' =>
      segments.length >= 3 &&
          (segments[2] != 'conflicts' ||
              (segments.length >= 4 && segments.last != 'edit')),
    // Entity-definition **list** pages are browse surfaces (kept); only the
    // per-entity editor / `create` route hides.
    'categories' ||
    'labels' ||
    'dashboards' ||
    'measurables' => segments.length >= 3,
    // `/settings/habits/search/<term>` is the list with a filter applied, and
    // bare `/settings/habits/by_id` (a truncated deep link) renders the list
    // — both keep the bar. Only `create` and a real `by_id/<id>` are editors.
    'habits' =>
      segments.length >= 3 &&
          (segments[2] == 'create' ||
              (segments[2] == 'by_id' && segments.length >= 4)),
    // Projects has no list under settings — only `/settings/projects/<id>`
    // editors. The reserved `create` slug is not routed (creation runs in a
    // modal from the Projects tab), so it must not hide over the settings root.
    'projects' => segments.length >= 3 && segments[2] != 'create',
    // Top-level leaf pages — terminal destinations reached from a menu.
    // `maintenance` is the legacy `/settings/maintenance` alias.
    'flags' ||
    'theming' ||
    'recording-style' ||
    'daily-os' ||
    'speech' ||
    'onboarding' ||
    'health_import' ||
    'maintenance' => true,
    // Everything else — notably the `/settings/definitions` menu hub — keeps
    // the bar.
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
  events,
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
    _AppNavigationDestinationKind.events ||
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

  Future<void> _showAiSetupPrompt() async {
    if (!mounted) return;
    void dismiss() =>
        ref.read(aiSetupPromptServiceProvider.notifier).dismissPrompt();

    // The new onboarding (FTUE) flow is gated behind a config flag while it's
    // still being built. Until it's enabled, first-run AI setup falls back to
    // the provider-selection modal (the pre-FTUE behaviour). A one-shot DB read
    // (not the stream provider) avoids a load-state race on this single check.
    // This method is fire-and-forget, so a read failure must default to the
    // fallback rather than surfacing as an uncaught async error.
    var ftueEnabled = false;
    try {
      ftueEnabled = await ref
          .read(journalDbProvider)
          .getConfigFlag(enableOnboardingFtueFlag);
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.onboarding,
        error,
        stackTrace: stackTrace,
        subDomain: 'aiSetupPromptFtueFlag',
      );
    }
    if (!mounted) return;

    if (ftueEnabled) {
      // The dedicated `shouldAutoShowOnboardingProvider` listener now owns
      // showing the FTUE welcome (with its own persisted re-show cadence) --
      // returning here (rather than opening it inline) avoids stacking that
      // welcome on top of this legacy modal on the same cold start.
      //
      // Deliberate: when the FTUE flag is on, this legacy provider-selection
      // modal is fully superseded -- even once the welcome's re-show budget is
      // exhausted (max shows / window elapsed) it does NOT fall back to this
      // prompt. A user who never connects a provider recovers via the
      // top-level Settings > Onboarding replay entry (and ordinary AI
      // settings), so onboarding is a single, coherent front door rather than
      // two prompts competing for the first run.
      return;
    }

    unawaited(
      AiProviderSelectionModal.show(
        context,
        onProviderSelected: (providerType) {
          const AiSettingsNavigationService().navigateToCreateProvider(
            context,
            preselectedType: providerType,
          );
        },
        onDismiss: dismiss,
      ),
    );
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
    // Daily OS is always available (no config flag), so only the current tab
    // gates the switch.
    if (navService.index != navService.calendarIndex) {
      navService.tapIndex(navService.calendarIndex);
    }
    ref
        .read(dailyOsOnboardingSessionControllerProvider.notifier)
        .start(
          origin: DailyOsOnboardingOrigin.auto,
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
      getIt<DomainLogger>().error(
        LogDomain.onboarding,
        error,
        stackTrace: stack,
        subDomain: 'showDailyOsOnboarding',
      );
    }
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
      // When What's New is dismissed, re-check if AI setup prompt / the FTUE
      // welcome should show
      ..listen(whatsNewControllerProvider, (prev, next) {
        final prevHasUnseen = prev?.asData?.value.hasUnseenRelease ?? true;
        final nextHasUnseen = next.asData?.value.hasUnseenRelease ?? true;

        // If What's New transitioned from unseen to seen, re-check both --
        // they are otherwise independent gates, but both sequence behind
        // What's New the same way.
        if (prevHasUnseen && !nextHasUnseen) {
          ref
            ..invalidate(aiSetupPromptServiceProvider)
            ..invalidate(shouldAutoShowOnboardingProvider)
            ..invalidate(shouldAutoShowDailyOsOnboardingProvider);
        }
      })
      // Auto-show AI setup prompt for new users without AI providers
      ..listen(aiSetupPromptServiceProvider, (prev, next) {
        next.when(
          data: (shouldShow) {
            if (shouldShow && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  unawaited(_showAiSetupPrompt());
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
      })
      // Auto-show the FTUE welcome on first launch (and, within its
      // persisted grace budget, subsequent launches) once What's New is out
      // of the way. Independent of `aiSetupPromptServiceProvider` -- see
      // `_showAiSetupPrompt`'s early return when the FTUE flag is on, which
      // keeps the two mutually exclusive.
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
            getIt<DomainLogger>().error(
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
            getIt<DomainLogger>().error(
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
      builder: (context, snapshot) {
        final rawIndex = snapshot.data ?? 0;
        final isProjectsPageEnabled = navService.isProjectsPageEnabled;
        final isDailyOsPageEnabled = navService.isDailyOsPageEnabled;
        final isHabitsPageEnabled = navService.isHabitsPageEnabled;
        final isDashboardsPageEnabled = navService.isDashboardsPageEnabled;
        final isEventsPageEnabled = navService.isEventsPageEnabled;

        final destinations = _buildNavigationDestinations(
          context: context,
          isProjectsPageEnabled: isProjectsPageEnabled,
          isDailyOsPageEnabled: isDailyOsPageEnabled,
          isHabitsPageEnabled: isHabitsPageEnabled,
          isDashboardsPageEnabled: isDashboardsPageEnabled,
          isEventsPageEnabled: isEventsPageEnabled,
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
          if (isEventsPageEnabled)
            Beamer(routerDelegate: navService.eventsDelegate),
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
          KeyboardFocusRegion(
            debugLabel: 'app-navigation',
            child: DesktopNavigationSidebar(
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
          ),
          ResizableDivider(
            enabled: !isCollapsed,
            onDrag: (delta) => ref
                .read(paneWidthControllerProvider.notifier)
                .updateSidebarWidth(delta),
          ),
          Expanded(
            child: KeyboardFocusRegion(
              debugLabel: 'app-content',
              child: Stack(
                children: [
                  const IncomingVerificationWrapper(),
                  IndexedStack(
                    index: index,
                    children: [
                      for (var i = 0; i < beamerChildren.length; i++)
                        TickerMode(
                          enabled: i == index,
                          child: ExcludeFocus(
                            excluding: i != index,
                            child: beamerChildren[i],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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

    // Settings *detail* routes — terminal pages you navigate to rather than
    // menus you navigate from (the whole AI & Agents sections, every Sync and
    // Advanced leaf, the top-level leaves like flags/theming, and the entity
    // editors — but not the menu hubs or browse lists) — slide the bar away
    // instead of removing it: nothing replaces the bar there, so an instant
    // unmount would read as a jumpy glitch rather than a handoff to a
    // page-owned surface. See [settingsRouteHidesBottomNav].
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
    required bool isEventsPageEnabled,
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
        expandedChildBuilder: () => const DailyOsSidebarSection(),
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
        expandedChildBuilder: () => const ImpactSidebarEntry(),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.journal,
        label: context.messages.navTabTitleJournal,
        iconBuilder: ({required active}) => Icon(
          active ? Icons.menu_book_rounded : Icons.menu_book_outlined,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.events,
        label: context.messages.navTabTitleEvents,
        iconBuilder: ({required active}) =>
            Icon(active ? Icons.event_rounded : Icons.event_outlined),
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
      isEventsPageEnabled: isEventsPageEnabled,
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
      isEventsPageEnabled: navService.isEventsPageEnabled,
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
  required bool isEventsPageEnabled,
}) {
  return [
    _AppNavigationDestinationKind.tasks,
    if (isDailyOsPageEnabled) _AppNavigationDestinationKind.dailyOs,
    if (isProjectsPageEnabled) _AppNavigationDestinationKind.projects,
    if (isHabitsPageEnabled) _AppNavigationDestinationKind.habits,
    if (isDashboardsPageEnabled) _AppNavigationDestinationKind.dashboards,
    _AppNavigationDestinationKind.journal,
    if (isEventsPageEnabled) _AppNavigationDestinationKind.events,
    _AppNavigationDestinationKind.settings,
  ];
}

typedef GlobalCommandLinkedIdResolver = Future<String?> Function();
typedef GlobalCommandCreationAction =
    Future<Object?> Function({String? linkedId});

class MyBeamerApp extends ConsumerStatefulWidget {
  const MyBeamerApp({
    super.key,
    this.navService,
    this.userActivityService,
    this.linkedIdResolver = getIdFromSavedRoute,
    this.createTextEntryAction = createTextEntry,
    this.createTaskAction = createTask,
    this.captureScreenshotAction = createScreenshot,
  });

  final NavService? navService;
  final UserActivityService? userActivityService;

  /// Testable boundary around route lookup and side-effectful creation.
  final GlobalCommandLinkedIdResolver linkedIdResolver;
  final GlobalCommandCreationAction createTextEntryAction;
  final GlobalCommandCreationAction createTaskAction;
  final GlobalCommandCreationAction captureScreenshotAction;

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
            builder: (context, child) {
              final zoomController = ref.watch(
                zoomControllerProvider.notifier,
              );
              return AppCommandHost(
                handlers: _globalCommandHandlers(),
                onActivity: updateActivity,
                onError: (id, error, stackTrace) {
                  getIt<DomainLogger>().error(
                    LogDomain.general,
                    error,
                    stackTrace: stackTrace,
                    subDomain: 'keyboardCommand:${id.name}',
                  );
                },
                child: DesktopMenuWrapper(
                  onZoomIn: zoomController.zoomIn,
                  onZoomOut: zoomController.zoomOut,
                  onZoomReset: zoomController.resetZoom,
                  child: ZoomWrapper(
                    scale: ref.watch(zoomControllerProvider),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<AppCommandId, AppCommandHandler> _globalCommandHandlers() {
    final navService = getIt<NavService>();
    final zoomController = ref.read(zoomControllerProvider.notifier);
    final handlers = <AppCommandId, AppCommandHandler>{
      AppCommandId.openCommandPalette: AppCommandHandler(
        invoke: (invocation) {
          final modalContext =
              routerDelegate.navigatorKey.currentContext ?? invocation.context;
          return showAppCommandPalette(modalContext, invocation.snapshot);
        },
      ),
      AppCommandId.openShortcutHelp: AppCommandHandler(
        invoke: (invocation) {
          final modalContext =
              routerDelegate.navigatorKey.currentContext ?? invocation.context;
          return showKeyboardShortcutsOverlay(modalContext);
        },
      ),
      AppCommandId.createTextEntry: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          await widget.createTextEntryAction(linkedId: linkedId);
        },
      ),
      AppCommandId.createTask: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          await widget.createTaskAction(linkedId: linkedId);
        },
      ),
      AppCommandId.captureScreenshot: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          await widget.captureScreenshotAction(linkedId: linkedId);
        },
      ),
      AppCommandId.navigateTasks: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.tasksIndex),
      ),
      AppCommandId.navigateDailyOs: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.calendarIndex),
      ),
      if (navService.isProjectsPageEnabled)
        AppCommandId.navigateProjects: AppCommandHandler(
          invoke: (_) => navService.tapIndex(navService.projectsIndex),
        ),
      if (navService.isHabitsPageEnabled)
        AppCommandId.navigateHabits: AppCommandHandler(
          invoke: (_) => navService.tapIndex(navService.habitsIndex),
        ),
      if (navService.isDashboardsPageEnabled)
        AppCommandId.navigateDashboards: AppCommandHandler(
          invoke: (_) => navService.tapIndex(navService.dashboardsIndex),
        ),
      AppCommandId.navigateJournal: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.journalIndex),
      ),
      if (navService.isEventsPageEnabled)
        AppCommandId.navigateEvents: AppCommandHandler(
          invoke: (_) => navService.tapIndex(navService.eventsIndex),
        ),
      AppCommandId.navigateSettings: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.settingsIndex),
      ),
      AppCommandId.zoomIn: AppCommandHandler(
        invoke: (_) => zoomController.zoomIn(),
      ),
      AppCommandId.zoomOut: AppCommandHandler(
        invoke: (_) => zoomController.zoomOut(),
      ),
      AppCommandId.resetZoom: AppCommandHandler(
        invoke: (_) => zoomController.resetZoom(),
      ),
    };
    return handlers;
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
      initialData: getIt<TimeService>().getCurrent(),
      builder: (context, snapshot) {
        final hasTimer = snapshot.data != null;
        final hasActiveStatus = audioVisible || hasTimer || wakesVisible;
        final tokens = context.designTokens;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasActiveStatus) ...[
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.spacing.step1,
                  bottom: tokens.spacing.step2,
                ),
                child: Text(
                  context.messages.sidebarActiveSectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
