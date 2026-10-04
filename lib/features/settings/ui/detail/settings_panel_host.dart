import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/settings/routing/settings_route.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Cross-fade between a panel's body and the detail surfaces below it.
const Duration kSettingsPanelSwapDuration = Duration(milliseconds: 180);

/// The desktop detail-pane content for one settings node.
///
/// Shows the node's headerless panel body, or — when the current settings
/// URL opens one of the node's sub-routes (`/settings/categories/<id>`,
/// `/settings/agents/templates/<id>/review`, …) — that detail surface in its
/// place. Both come from the node's `settingsRoutes` entry, which also builds
/// the mobile stack, so a detail is wired once for both platforms.
///
/// Listens to [NavService.desktopSelectedSettingsRoute], which
/// `SettingsLocation` updates on every desktop settings URL change. A route
/// that belongs to another node leaves this host on its own body, so a body
/// cached for a sibling leaf is unaffected.
class SettingsPanelHost extends StatelessWidget {
  const SettingsPanelHost({
    required this.nodeId,
    this.listenable,
    this.table,
    super.key,
  });

  /// Tree node id whose panel this hosts. Must have a panel in the table.
  final String nodeId;

  /// Test-only override for the route source. Production leaves it `null`
  /// so the host reads from `ref.read(navServiceProvider)`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  /// Test-only override for the registry.
  @visibleForTesting
  final SettingsRouteTable? table;

  @override
  Widget build(BuildContext context) {
    final routes = table ?? settingsRoutes;
    final route = routes.routes[nodeId]!;
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, current, _) {
        final match = routes.resolve(
          Uri(
            path: current?.path ?? route.url,
            queryParameters: (current?.queryParameters.isEmpty ?? true)
                ? null
                : current!.queryParameters,
          ),
        );
        final sub = match.nodePath.lastOrNull == nodeId ? match.subRoute : null;

        final String modeKey;
        final Widget child;
        if (sub != null) {
          // The stack key names the sub-route, its captured ids and its
          // query, so moving between two details cross-fades into a fresh
          // page instead of reusing the previous one's state.
          modeKey = match.stack.last.key;
          child = (sub.panel ?? sub.build)(context, match);
        } else {
          modeKey = 'panel';
          final body = route.panel!(context, match);
          child = route.scrollable ? SingleChildScrollView(child: body) : body;
        }

        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // `StackFit.expand` hands Scaffold-based details bounded
          // constraints, so their floating action buttons and bottom bars
          // lay out as they would unwrapped.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(key: ValueKey(modeKey), child: child),
        );
      },
    );
  }
}
