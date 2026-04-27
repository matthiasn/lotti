import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Signature for the bridge's "navigate the app" hook. Injected by
/// the widget so tests can substitute a plain function spy without
/// standing up a full Beamer tree.
typedef BeamToReplacementNamed =
    void Function(
      BuildContext context,
      String uri,
    );

void _defaultBeamTo(BuildContext context, String uri) {
  Beamer.of(context).beamToReplacementNamed(uri);
}

/// Invisible bridge (plan §1) that keeps the tree's
/// [settingsTreePathProvider] and the Beamer-owned settings URL in
/// sync in both directions:
///
/// - **URL → tree.** Listens to `NavService.desktopSelectedSettingsRoute`
///   and calls `syncFromUrl` whenever it changes, so a deep-link
///   into `/settings/sync/backfill` seeds
///   `['sync', 'sync/backfill']` on mount.
/// - **Tree → URL.** `ref.listen`s the path provider; when the tree
///   moves to a node whose [pathToBeamUrl] differs from the current
///   Beamer location, beams to the new URL with replacement so the
///   router state reflects the selection.
///
/// A small `_programmaticBeams` counter breaks the feedback loop:
/// while one or more tree-triggered beams are in flight the inbound
/// listener is suppressed. Each programmatic beam increments the
/// counter and schedules a post-frame decrement, so overlapping
/// rapid taps don't prematurely release the guard before every
/// in-flight beam has settled.
///
/// This widget must be mounted inside a Beamer context (it is
/// invoked from `SettingsV2Page`, which lives under the
/// `SettingsLocation` beam tree). It is intentionally layout-neutral
/// — parent can ignore its child size entirely.
class SettingsTreeUrlSync extends ConsumerStatefulWidget {
  const SettingsTreeUrlSync({
    this.beamToReplacementNamed = _defaultBeamTo,
    super.key,
  });

  /// Override for tests — swap in a spy instead of calling
  /// `Beamer.of(context).beamToReplacementNamed` directly.
  final BeamToReplacementNamed beamToReplacementNamed;

  @override
  ConsumerState<SettingsTreeUrlSync> createState() =>
      _SettingsTreeUrlSyncState();
}

class _SettingsTreeUrlSyncState extends ConsumerState<SettingsTreeUrlSync> {
  /// Number of tree-driven beams whose resulting route-notifier
  /// notification has not yet been observed. Strictly non-negative.
  /// Using a counter (rather than a bool) keeps the guard correct
  /// when a user clicks several tree rows within the same frame —
  /// each beam's post-frame decrement pairs with its own increment,
  /// so the earliest-scheduled callback can't release the guard
  /// while later beams are still settling.
  int _programmaticBeams = 0;
  late final NavService _navService;

  @override
  void initState() {
    super.initState();
    _navService = getIt<NavService>();
    _navService.desktopSelectedSettingsRoute.addListener(_onRouteChanged);
    // Seed from whatever is already in the route notifier — handles
    // the deep-link-on-mount case where the path is already set
    // before we attach the listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onRouteChanged();
    });
  }

  @override
  void dispose() {
    _navService.desktopSelectedSettingsRoute.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (_programmaticBeams > 0) return;
    final route = _navService.desktopSelectedSettingsRoute.value;
    final url = route?.path ?? settingsRootUrl;
    // syncFromUrl is already idempotent — it only mutates state when
    // the resolved path differs — so the extra early-out here is
    // purely a cycle-break belt.
    ref.read(settingsTreePathProvider.notifier).syncFromUrl(url);
  }

  void _onPathChanged(List<String> next) {
    final target = pathToBeamUrl(next);
    final currentUrl =
        _navService.desktopSelectedSettingsRoute.value?.path ?? settingsRootUrl;
    if (target == currentUrl) return;

    // The guard is one-way: it only suppresses the `URL → tree`
    // direction while a tree-driven beam is settling. Multiple
    // consecutive tree mutations each get to beam on their own —
    // otherwise opening `sync` and then `sync/backfill` back-to-back
    // would publish only the first URL. The counter pairs each
    // increment with exactly one post-frame decrement so overlapping
    // taps can't leave the flag stuck above zero.
    _programmaticBeams++;
    widget.beamToReplacementNamed(context, target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_programmaticBeams > 0) _programmaticBeams--;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(settingsTreePathProvider, (_, next) {
      _onPathChanged(next);
    });
    return const SizedBox.shrink();
  }
}
