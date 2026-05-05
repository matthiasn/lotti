import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/agent_pending_wakes_page.dart';
import 'package:lotti/features/agents/ui/souls/agent_souls_page.dart';
import 'package:lotti/features/agents/ui/templates/agent_templates_page.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Tabs available on [AgentSettingsPage]. Exposed as a public enum
/// so Settings V2 leaf panels (plan step 9) can deep-link into a
/// specific tab via [AgentSettingsPage.initialTab].
enum AgentSettingsTab {
  stats,
  templates,
  instances,
  souls,
  pendingWakes,
}

/// Landing page for Settings > Agents.
///
/// Contains five tabs (mirrored by the `agents/<segment>` leaves in
/// the Settings V2 tree):
/// - **Stats**: token usage and recent activity.
/// - **Templates**: inline list of agent templates (extracted from
///   the former `AgentTemplateListPage`).
/// - **Instances**: filterable list of agent instances.
/// - **Souls**: long-lived agent personalities.
/// - **Pending Wakes**: live list of scheduled and deferred wake
///   timers.
class AgentSettingsPage extends ConsumerStatefulWidget {
  const AgentSettingsPage({this.initialTab, super.key});

  /// Tab to pre-select on mount. Defaults to [AgentSettingsTab.stats]
  /// so the legacy beamer entry-point lands on the overview.
  final AgentSettingsTab? initialTab;

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

/// Body alias for Settings V2: shows [AgentSettingsPage] with a
/// pre-selected tab so `agents/templates`, `agents/souls` and
/// `agents/instances` each open on the right tab. Plan step 10
/// will give the page a headerless embedded mode to drop the
/// minor duplicate app-bar.
class AgentSettingsBody extends StatelessWidget {
  const AgentSettingsBody({this.initialTab, super.key});

  final AgentSettingsTab? initialTab;

  @override
  Widget build(BuildContext context) =>
      AgentSettingsPage(initialTab: initialTab);
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage> {
  /// Selection used when the URL doesn't drive the tab — i.e. mobile
  /// (legacy push-stack navigation) and tests where `NavService`
  /// isn't registered. On desktop the selected tab is derived from
  /// the current Settings URL via [_resolveTabFromRoute].
  late AgentSettingsTab _localFallback;

  /// `null` when no `NavService` is registered (test path) — the
  /// widget then unconditionally falls back to [_localFallback]. When
  /// non-null, [_isUrlDriven] further requires the app to be in
  /// desktop mode before treating the URL as authoritative.
  NavService? _navService;

  @override
  void initState() {
    super.initState();
    _localFallback = widget.initialTab ?? AgentSettingsTab.stats;
    if (getIt.isRegistered<NavService>()) {
      _navService = getIt<NavService>();
    }
  }

  @override
  void didUpdateWidget(covariant AgentSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mobile / push-stack callers may swap [initialTab] in place
    // without remounting; mirror that into the local fallback so the
    // rebuild lands on the requested tab. Desktop callers leave
    // [initialTab] null and the URL drives selection — skip the write
    // so we don't churn `_localFallback` no one is reading.
    if (_isUrlDriven) return;
    final previous = oldWidget.initialTab ?? AgentSettingsTab.stats;
    final next = widget.initialTab ?? AgentSettingsTab.stats;
    if (previous != next) {
      _localFallback = next;
    }
  }

  /// Whether the tab bar should beam URL changes (desktop V2) or
  /// keep the legacy local-`setState` behavior (mobile + tests).
  /// `NavService.isDesktopMode` is set by `AppScreen` based on
  /// breakpoint; tests can opt in by flipping it to `true`.
  ///
  /// Note: `isDesktopMode` is a plain `bool` rather than a notifier,
  /// so this getter does *not* react to mid-mount breakpoint flips
  /// on its own. The page relies on `AppScreen` (which owns the
  /// LayoutBuilder) to rebuild the subtree when the layout flips —
  /// at that point the next `build()` re-evaluates this getter and
  /// picks the correct branch.
  bool get _isUrlDriven => _navService?.isDesktopMode == true;

  /// Maps a settings URL onto the tab the body should show. Each
  /// tab has its own tree leaf and URL under `/settings/agents/`
  /// (see `settingsNodeUrls` and the per-tab patterns in
  /// `SettingsLocation`); the bare `/settings/agents` landing falls
  /// through to Stats so the parent tree row stays clickable.
  AgentSettingsTab _resolveTabFromRoute(DesktopSettingsRoute? route) {
    if (route == null) return _localFallback;
    return _tabFromPath(route.path);
  }

  /// Shared tab-click handler. On desktop, beam to the URL that
  /// represents the chosen tab so the V2 detail pane swaps to the
  /// per-tab leaf with its working `DetailIdDispatch` (and FAB).
  /// On mobile / tests, fall back to local `setState` so the legacy
  /// page-stack navigation isn't disturbed.
  void _onTabSelected(AgentSettingsTab tab) {
    if (_isUrlDriven) {
      beamToNamed(_urlForTab(tab));
      return;
    }
    if (_localFallback == tab) return;
    setState(() => _localFallback = tab);
  }

  @override
  Widget build(BuildContext context) {
    // Read the route notifier only inside the URL-driven branch.
    // Mobile / test contexts often supply a `MockNavService` whose
    // `desktopSelectedSettingsRoute` getter isn't stubbed (its return
    // type is non-nullable, so unstubbed access throws under
    // mocktail) — keep the read behind the desktop-mode gate.
    if (!_isUrlDriven) {
      return _buildContent(context, _localFallback);
    }
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: _navService!.desktopSelectedSettingsRoute,
      builder: (context, route, _) =>
          _buildContent(context, _resolveTabFromRoute(route)),
    );
  }

  Widget _buildContent(BuildContext context, AgentSettingsTab selectedTab) {
    final tokens = context.designTokens;
    final pendingWakeCount = ref.watch(
      pendingWakeRecordsProvider.select((value) => value.value?.length ?? 0),
    );
    final floatingActionButton = switch (selectedTab) {
      AgentSettingsTab.templates => DesignSystemFloatingActionButton(
        semanticLabel: context.messages.agentTemplateCreateTitle,
        onPressed: () => beamToNamed('/settings/agents/templates/create'),
      ),
      AgentSettingsTab.souls => DesignSystemFloatingActionButton(
        semanticLabel: context.messages.agentSoulCreateTitle,
        onPressed: () => beamToNamed('/settings/agents/souls/create'),
      ),
      _ => null,
    };

    final appBarTitle = switch (selectedTab) {
      AgentSettingsTab.instances => context.messages.agentInstancesPageTitle,
      _ => context.messages.agentSettingsTitle,
    };
    return Scaffold(
      // Desktop V2 already names the page via the breadcrumb in the
      // shell header; an AppBar here would just stack a second darker
      // chrome strip on top of it. Mobile / push-stack contexts keep
      // the AppBar so the back button and title stay reachable.
      appBar: _isUrlDriven
          ? null
          : AppBar(
              leading: agentBackButton(context),
              title: Text(
                appBarTitle,
                style: appBarTextStyleNewLarge.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
      body: Column(
        children: [
          // Hide the in-page tab strip on desktop V2 — every tab now
          // has its own tree leaf under `agents` in the sidebar, and
          // exposing both navigation surfaces caused two interlocked
          // bugs: (1) the URL → tree → URL feedback guard could leak
          // across rapid tab clicks and silently swallow subsequent
          // sidebar / FAB / row beams, and (2) a top-tab click never
          // expanded the parent branch in the sidebar so the visible
          // selection drifted out of sync. The body still resolves
          // its content from the URL, so the tab bar is purely a
          // mobile / push-stack affordance now.
          if (!_isUrlDriven)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step4,
                tokens.spacing.step4,
                tokens.spacing.step4,
                tokens.spacing.step2,
              ),
              child: _AgentSettingsTabBar(
                selectedTab: selectedTab,
                pendingWakeCount: pendingWakeCount,
                onSelected: _onTabSelected,
              ),
            ),
          Expanded(
            child: _AgentSettingsTabBody(
              selectedTab: selectedTab,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton == null
          ? null
          : DesignSystemBottomNavigationFabPadding(
              child: floatingActionButton,
            ),
    );
  }
}

/// Single source of truth for the URL segment that represents each
/// tab under `/settings/agents/`. Both directions of the URL ↔ tab
/// mapping (`_urlForTab` and `_tabFromPath`) are derived from this
/// table, so adding or renaming a tab is a one-line change.
const String _kAgentsRoot = '/settings/agents';
const Map<AgentSettingsTab, String> _kTabUrlSegments = {
  AgentSettingsTab.stats: 'stats',
  AgentSettingsTab.templates: 'templates',
  AgentSettingsTab.instances: 'instances',
  AgentSettingsTab.souls: 'souls',
  AgentSettingsTab.pendingWakes: 'pending-wakes',
};

/// Canonical URL for each tab. Each tab has a dedicated tree leaf
/// under `agents` so clicking a tab in the bar matches clicking the
/// corresponding leaf in the sidebar.
String _urlForTab(AgentSettingsTab tab) =>
    '$_kAgentsRoot/${_kTabUrlSegments[tab]!}';

/// Inverse of [_urlForTab]: matches the first path segment after
/// `/settings/agents/` against [_kTabUrlSegments]. Bare
/// `/settings/agents` (or an unknown segment) falls through to
/// `Stats` so the parent tree row stays a usable landing. Segment-
/// aware so a future leaf like `templates-archive` can't accidentally
/// hijack the Templates tab via prefix-only matching.
AgentSettingsTab _tabFromPath(String path) {
  if (!path.startsWith('$_kAgentsRoot/')) return AgentSettingsTab.stats;
  final segment = path.substring(_kAgentsRoot.length + 1).split('/').first;
  for (final entry in _kTabUrlSegments.entries) {
    if (entry.value == segment) return entry.key;
  }
  return AgentSettingsTab.stats;
}

class _AgentSettingsTabBar extends StatelessWidget {
  const _AgentSettingsTabBar({
    required this.selectedTab,
    required this.pendingWakeCount,
    required this.onSelected,
  });

  final AgentSettingsTab selectedTab;
  final int pendingWakeCount;
  final ValueChanged<AgentSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tabs = [
      (
        tab: AgentSettingsTab.stats,
        label: context.messages.agentStatsTabTitle,
        counter: null as String?,
      ),
      (
        tab: AgentSettingsTab.templates,
        label: context.messages.agentTemplatesTitle,
        counter: null as String?,
      ),
      (
        tab: AgentSettingsTab.instances,
        label: context.messages.agentInstancesTitle,
        counter: null as String?,
      ),
      (
        tab: AgentSettingsTab.souls,
        label: context.messages.agentSoulsTitle,
        counter: null as String?,
      ),
      (
        tab: AgentSettingsTab.pendingWakes,
        label: context.messages.agentPendingWakesTitle,
        counter: '$pendingWakeCount',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _segmentWidths(
          context,
          constraints.maxWidth,
          tabs,
        );
        final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);

        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radii.m),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: DesignSystemTab(
                        selected: selectedTab == tabs[i].tab,
                        shape: DesignSystemTabShape.rectangular,
                        label: tabs[i].label,
                        counter: tabs[i].counter,
                        onPressed: () => onSelected(tabs[i].tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<double> _segmentWidths(
    BuildContext context,
    double availableWidth,
    List<({String? counter, String label, AgentSettingsTab tab})> tabs,
  ) {
    final naturalWidths = tabs
        .map(
          (tab) => DesignSystemTab.preferredWidth(
            context,
            label: tab.label,
            counter: tab.counter,
          ),
        )
        .toList();
    final totalNaturalWidth = naturalWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );

    if (totalNaturalWidth >= availableWidth) {
      return naturalWidths;
    }

    final extraPerTab = (availableWidth - totalNaturalWidth) / tabs.length;
    return naturalWidths.map((width) => width + extraPerTab).toList();
  }
}

class _AgentSettingsTabBody extends ConsumerWidget {
  const _AgentSettingsTabBody({
    required this.selectedTab,
  });

  final AgentSettingsTab selectedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IndexedStack(
      index: selectedTab.index,
      children: const [
        TokenStatsTab(),
        AgentTemplatesPage(),
        AgentInstancesList(),
        AgentSoulsPage(),
        AgentPendingWakesPage(),
      ],
    );
  }
}
