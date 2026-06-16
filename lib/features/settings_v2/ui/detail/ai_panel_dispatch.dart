import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

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

  /// Stable `AnimatedSwitcher` key for this selection. Distinct per
  /// surface kind and per detail id (e.g. `provider:<id>:fix`,
  /// `model:<id>`, `list`) so swapping between two detail pages
  /// cross-fades instead of reusing the previous element.
  final String modeKey;

  /// The resolved page to render in the AI panel slot.
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
