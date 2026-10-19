import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/motion/on_screen_ticker_mode.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Measures visibility episodes for one banner: the stopwatch runs while
/// the banner is on screen — its tab visible, the app foregrounded, and
/// the banner intersecting its enclosing viewport ([OnScreenTickerMode]'s
/// verdict) — so scrolled-away time and pocket time never count. Every
/// visible→hidden transition flushes its own episode, so separate
/// appearances never merge and persistence doesn't wait for disposal.
///
/// Shared by every banner surface: the shell dock (where a docked tenant
/// is visible whenever the app is foregrounded) and the uncapped list on
/// the goal detail page (where scroll position matters).
///
/// The same verdict gates a [TickerMode] around the child: the detail page
/// builds its banners eagerly, and a below-the-fold banner with a repeating
/// headline animation would otherwise burn frame work the user cannot see.
class NudgeBannerExposureTracker extends ConsumerStatefulWidget {
  const NudgeBannerExposureTracker({
    required this.nudgeId,
    required this.child,
    super.key,
  });

  final String nudgeId;
  final Widget child;

  @override
  ConsumerState<NudgeBannerExposureTracker> createState() =>
      _ExposureTrackerState();
}

class _ExposureTrackerState extends ConsumerState<NudgeBannerExposureTracker> {
  final Stopwatch _visible = Stopwatch();
  NudgeInteractionsFlush? _flush;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured while the element is live: `ref` must not be touched from
    // dispose, and the flush must survive the widget's death.
    _flush = ref.read(nudgeExposureFlushProvider);
  }

  void _onVisibilityChanged(bool visible) {
    if (visible) {
      _visible.start();
    } else {
      _flushEpisode();
    }
  }

  void _flushEpisode() {
    _visible.stop();
    if (_visible.elapsed > Duration.zero) {
      _flush?.call(widget.nudgeId, _visible.elapsed);
    }
    _visible.reset();
  }

  @override
  void dispose() {
    _flushEpisode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnScreenTickerMode(
    onVisibilityChanged: _onVisibilityChanged,
    child: widget.child,
  );
}
