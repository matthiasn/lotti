part of 'panel_registry.dart';

// --- Step 9 builders --------------------------------------------------------
// AI Settings: list ↔ provider/model/profile detail dispatch.
//
// Unlike categories / labels / dashboards (each of which has ONE detail
// kind keyed off a single path parameter), the AI panel has three
// orthogonal detail surfaces — provider, model, inference profile —
// reachable from three different tab bodies in the list. The generic
// `DetailIdDispatch` only handles one id key, so the AI panel uses a
// custom `AiPanelDispatch` widget that reads all three keys off the
// route and picks whichever is present.
//
// URL space:
//   /settings/ai                        → list (AiSettingsBody)
//   /settings/ai/provider/<providerId>  → AiProviderDetailPage
//   /settings/ai/model/<modelId>        → InferenceModelEditPage
//   /settings/ai/profile/<profileId>    → InferenceProfileDetailPage
//                                          (resolves id → AiConfig via
//                                          Riverpod and hands the loaded
//                                          profile to InferenceProfileForm)
//
// The legacy `/settings/ai/profiles` leaf renders InferenceProfilePage
// directly and is unrelated — it's the seeded-profile list, not the
// per-profile edit form.
Widget _aiPanel(BuildContext context) => const AiPanelDispatch();

/// Multi-kind dispatcher for the AI Settings panel. Watches the
/// settings route ValueNotifier and renders one of:
///
/// - [AiSettingsBody] (the list) when no detail id is bound,
/// - [AiProviderDetailPage] (with `focusApiKey` from the route query)
///   when `providerId` is bound,
/// - [InferenceModelEditPage] when `modelId` is bound,
/// - [InferenceProfileDetailPage] when `profileId` is bound.
///
/// Wraps the swap in an [AnimatedSwitcher] tuned to the same 180 ms
/// cross-fade as `DetailIdDispatch` so the AI panel feels consistent
/// with the other Settings V2 panels.
class AiPanelDispatch extends StatelessWidget {
  const AiPanelDispatch({this.listenable, super.key});

  /// Test-only override for the route source. Production callers leave
  /// this `null` so the dispatcher reads from `getIt<NavService>()`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context) {
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, route, _) {
        final selection = aiPanelSelectionFor(route);
        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // Same layout choice as `DetailIdDispatch` — `StackFit.expand`
          // gives Scaffold-based children bounded constraints so their
          // FAB and bottom bar lay out correctly.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(
            key: ValueKey(selection.modeKey),
            child: selection.child,
          ),
        );
      },
    );
  }
}

/// Result of resolving the route → page mapping for the AI panel. The
/// dispatcher keys its [AnimatedSwitcher] by [modeKey] so swapping
/// between two distinct detail pages cross-fades (rather than reusing
/// the previous element) and keys each detail page by a stable
/// per-id [ValueKey] so successive detail rows tear down cleanly.
@immutable
class AiPanelSelection {
  const AiPanelSelection({required this.modeKey, required this.child});

  final String modeKey;
  final Widget child;
}

/// Pure route → child resolver for the AI panel.
///
/// Extracted so the registry tests can verify the multi-kind dispatch
/// (list / provider / model / profile) without pumping the heavy
/// destination pages — each carries its own Riverpod / Scaffold setup
/// and would force every dispatcher test to register a real
/// repository. The widget calls this helper from its builder; the
/// tests assert directly on the returned widget TYPE and `modeKey`.
AiPanelSelection aiPanelSelectionFor(DesktopSettingsRoute? route) {
  final params = route?.pathParameters ?? const <String, String>{};

  final providerId = params['providerId'];
  if (providerId != null && providerId.isNotEmpty) {
    final focusApiKey = route?.queryParameters['focusApiKey'] == 'true';
    return AiPanelSelection(
      modeKey: 'provider:$providerId:${focusApiKey ? 'fix' : 'view'}',
      child: AiProviderDetailPage(
        key: ValueKey('settings-v2-ai-provider-$providerId'),
        providerId: providerId,
        focusApiKey: focusApiKey,
      ),
    );
  }

  final modelId = params['modelId'];
  if (modelId != null && modelId.isNotEmpty) {
    return AiPanelSelection(
      modeKey: 'model:$modelId',
      child: InferenceModelEditPage(
        key: ValueKey('settings-v2-ai-model-$modelId'),
        configId: modelId,
      ),
    );
  }

  final profileId = params['profileId'];
  if (profileId != null && profileId.isNotEmpty) {
    return AiPanelSelection(
      modeKey: 'profile:$profileId',
      child: InferenceProfileDetailPage(
        key: ValueKey('settings-v2-ai-profile-$profileId'),
        profileId: profileId,
      ),
    );
  }

  // AI Settings parent landing on desktop. The page's
  // `AiSettingsFilterState.initial()` already defaults the active tab
  // to Providers, so hiding the TabBar here makes the parent row land
  // visually identical to the Providers leaf — both render the
  // providers list with no in-pane tabs. Mobile bypasses this panel
  // entirely (Beamer routes `/settings/ai` to `AiSettingsPage()`
  // directly, which keeps its TabBar because the sidebar doesn't
  // exist on phone-sized viewports).
  // `hideHeader: true` drops the in-pane "< AI Settings" strip on
  // desktop — the master/detail breadcrumb already names the panel,
  // so the duplicate header was just crowding the search bar.
  return const AiPanelSelection(
    modeKey: 'list',
    child: AiSettingsBody(hideTabBar: true, hideHeader: true),
  );
}

// Per-leaf desktop bodies for the AI sidebar children. Each renders
// `AiSettingsBody` pinned to one tab with the in-pane TabBar AND the
// page header hidden so the sidebar leaf / breadcrumb naming isn't
// duplicated above the list. The `ai-profiles` panel now points at
// the v3 profiles tab body — the legacy `InferenceProfilesBody` is
// still kept around for any direct `/settings/ai/profiles` deep-links
// in older bookmarks, but the v2 panel registry no longer uses it.
Widget _aiProvidersPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.providers,
  hideTabBar: true,
  hideHeader: true,
);
Widget _aiModelsPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.models,
  hideTabBar: true,
  hideHeader: true,
);
Widget _aiProfilesPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.profiles,
  hideTabBar: true,
  hideHeader: true,
);
Widget _agentsPanel(BuildContext context) => const AgentSettingsBody();

// Stats and pending-wakes are read-only views with no detail/create
// flow, so they reuse `AgentSettingsBody` directly. The body resolves
// its tab from the URL on desktop, so the explicit `initialTab`
// argument here is just a fallback for mobile / test contexts where
// `NavService` isn't desktop-driven.
Widget _agentsStatsPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.stats);
Widget _agentsPendingWakesPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.pendingWakes);

// Agent panels follow the same list ↔ detail/create pattern as the
// other dynamic-list panels (categories, labels, dashboards, …) — the
// floating "+" beams to `/settings/agents/<tab>/create`, list rows
// beam to `/settings/agents/<tab>/<id>`. Each tab has its own id key
// (`templateId` / `soulId` / `agentId`).
Widget _agentsTemplatesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'templateId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.templates),
  create: (_, _) => const AgentTemplateDetailPage(),
  detail: (_, id) => AgentTemplateDetailPage(
    key: ValueKey('settings-v2-agent-template-$id'),
    templateId: id,
  ),
);

Widget _agentsSoulsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'soulId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.souls),
  create: (_, _) => const AgentSoulDetailPage(),
  detail: (_, id) => AgentSoulDetailPage(
    key: ValueKey('settings-v2-agent-soul-$id'),
    soulId: id,
  ),
);

Widget _agentsInstancesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'agentId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.instances),
  // Instances are created indirectly (from a template) — there is no
  // `/settings/agents/instances/create` route in beamer, so the
  // create branch is structurally unreachable. Fall back to the list
  // defensively rather than crashing if a stray URL ever arrives.
  create: (_, _) =>
      const AgentSettingsBody(initialTab: AgentSettingsTab.instances),
  detail: (_, id) => AgentDetailPage(
    key: ValueKey('settings-v2-agent-instance-$id'),
    agentId: id,
  ),
);
