import 'package:beamer/beamer.dart';
import 'package:flutter/scheduler.dart';
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

  /// Mirror counter for the opposite direction: when a URL change
  /// drives a tree-path mutation, the resulting tree-path listener
  /// must NOT beam back to canonicalize the URL — that would erase
  /// panel-local trailing segments (`/create`, a detail UUID) that
  /// the user just navigated into. Bumped before
  /// `SettingsTreePath.syncFromUrl` runs, decremented post-frame so
  /// the suppression covers exactly the listener cascade triggered
  /// by that single URL update.
  int _urlDrivenSyncs = 0;
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
    final phase = SchedulerBinding.instance.schedulerPhase;
    // Beamer's `SettingsLocation.buildPages` mutates the
    // `desktopSelectedSettingsRoute` ValueNotifier *inside* the build
    // pass, which fires this listener synchronously. Riverpod forbids
    // mutating provider state during build, so when we land here while
    // a frame is in `persistentCallbacks` (build/layout/paint) we
    // defer the actual sync to the next frame. Outside the build pass
    // we run synchronously — that's the path most user-driven URL
    // changes take and keeps the visible behaviour unchanged.
    final inBuildPhase =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (inBuildPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runRouteSync();
      });
      return;
    }
    _runRouteSync();
  }

  void _runRouteSync() {
    if (_programmaticBeams > 0) return;
    final route = _navService.desktopSelectedSettingsRoute.value;
    final url = route?.path ?? settingsRootUrl;
    // Bump the URL-driven guard before mutating the tree path so the
    // resulting `_onPathChanged` listener cascade doesn't beam back
    // and erase panel-local URL extensions (e.g. tapping the FAB at
    // `/settings/agents` lands on `/settings/agents/templates/create`
    // — the URL → tree sync then promotes the tree path to
    // `[agents, agents/templates]`, which would otherwise canonicalize
    // the URL back to `/settings/agents/templates` and kill the
    // `/create` segment before the panel dispatcher observes it).
    _urlDrivenSyncs++;
    // syncFromUrl is already idempotent — it only mutates state when
    // the resolved path differs — so the extra early-out here is
    // purely a cycle-break belt. The `_onPathChanged` listener fires
    // synchronously inside this call when state changes, so the
    // increment above is what suppresses the beam-back; the
    // post-frame decrement just resets the guard for the next URL
    // change.
    ref.read(settingsTreePathProvider.notifier).syncFromUrl(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_urlDrivenSyncs > 0) _urlDrivenSyncs--;
    });
  }

  void _onPathChanged(List<String> next) {
    // Tree path changed *because* the URL changed (URL → tree sync) —
    // do not beam back to canonicalize, the URL already represents
    // the user's intent (often deeper than the bare leaf URL).
    if (_urlDrivenSyncs > 0) return;
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
