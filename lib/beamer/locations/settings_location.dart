import 'package:beamer/beamer.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/settings_urls.dart';
import 'package:material_ui/material_ui.dart';

/// Every `/settings/**` URL, built from the settings route registry
/// ([settingsRoutes]).
///
/// The location holds no routing knowledge of its own: which pages a URL
/// stacks, what each one pops back to, and which detail a URL opens are all
/// read from the registry, so a settings page is wired up in exactly one
/// place.
class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => settingsRoutes.patterns;

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final match = settingsRoutes.resolve(state.uri);
    final navService = getIt<NavService>();

    // Desktop pushes exactly one page — the tree beside its detail pane —
    // and hands the URL to that pane through the route notifier instead of
    // stacking pages.
    if (navService.isDesktopMode) {
      navService.desktopSelectedSettingsRoute.value =
          state.uri.path == settingsRootUrl
          ? null
          : (
              path: state.uri.path,
              pathParameters: match.pathParameters,
              queryParameters: Map<String, String>.of(
                state.uri.queryParameters,
              ),
            );
      return const [
        BeamPage(
          key: ValueKey('settings-desktop'),
          title: 'Settings',
          child: SettingsRootPage(),
        ),
      ];
    }

    // Mobile: the drill-down stack. Each page keeps its key at every URL that
    // shows it, so a back gesture uncovers the page beneath instead of
    // swapping it, and names its pop target outright rather than trusting
    // Beamer to strip one URL segment.
    return [
      for (final (index, entry) in match.stack.indexed)
        BeamPage(
          key: ValueKey(entry.key),
          popToNamed: index == 0 ? null : entry.popUrl,
          child: entry.build(context, match),
        ),
    ];
  }
}
