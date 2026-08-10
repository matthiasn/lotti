import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';

/// How many banners a host surface shows at once: the newest render,
/// the rest stay reachable on their goal's detail page.
const goalBannerStripMaxVisible = 2;

/// The banner mount: renders the newest active goal ads (bounded by
/// [goalBannerStripMaxVisible]) and shrinks to nothing when there are
/// none (the `KnowledgeNudge` contract — hosts mount it unconditionally).
///
/// Exposure accounting: an episode runs while the banner's TAB is the
/// visible one (TickerMode — the app shell keeps inactive tabs mounted)
/// AND the banner itself intersects its enclosing viewport; every
/// visible→hidden transition (tab switch, scroll-out, unmount) flushes
/// its own episode. Viewport checks run on scroll events, not per frame.
class GoalBannerStrip extends ConsumerWidget {
  const GoalBannerStrip({this.padded = true, super.key});

  /// Whether the strip applies its own horizontal page padding (the day
  /// page nudge column) or the host already pads (the habits sliver).
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final entries =
        ref.watch(activeGoalNudgesProvider).value ?? const <GoalBannerEntry>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(
        left: padded ? tokens.spacing.step5 : 0,
        right: padded ? tokens.spacing.step5 : 0,
        bottom: tokens.spacing.step3,
      ),
      child: Column(
        children: [
          // Bounded: the strip sits above non-scrolling page content, so
          // an unbounded stack could overflow the viewport. The rest stay
          // reachable on their goal's detail page.
          for (final entry in entries.take(goalBannerStripMaxVisible))
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
              child: GoalBannerExposureTracker(
                key: ValueKey(
                  '${entry.nudge.id}:${entry.nudge.activationCount}',
                ),
                nudgeId: entry.nudge.id,
                child: GoalBannerCard(entry: entry),
              ),
            ),
        ],
      ),
    );
  }
}

/// Measures visibility episodes: the stopwatch runs while the host tab
/// is on screen (TickerMode) AND the banner intersects its enclosing
/// viewport — scrolled-away time on the habits page or the goal detail
/// list never counts. Rechecks happen on scroll events and dependency
/// changes, not per frame. Public because EVERY banner mount must
/// account exposure the same way — the strips here and the uncapped
/// list on the goal detail page.
class GoalBannerExposureTracker extends ConsumerStatefulWidget {
  const GoalBannerExposureTracker({
    required this.nudgeId,
    required this.child,
    super.key,
  });

  final String nudgeId;
  final Widget child;

  @override
  ConsumerState<GoalBannerExposureTracker> createState() =>
      _ExposureTrackerState();
}

class _ExposureTrackerState extends ConsumerState<GoalBannerExposureTracker> {
  final Stopwatch _visible = Stopwatch();
  GoalNudgeInteractionsFlush? _flush;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured while the element is live: `ref` must not be touched from
    // dispose, and the flush must survive the widget's death.
    _flush = ref.read(goalNudgeExposureFlushProvider);
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_recheck);
      _position = position?..addListener(_recheck);
    }
    _recheck();
    _recheckAfterFrame();
  }

  @override
  void didUpdateWidget(GoalBannerExposureTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sibling banner inserted or removed above this one moves it across
    // the viewport boundary with no scroll event — the rebuild that
    // reflowed the list is the signal.
    _recheckAfterFrame();
  }

  /// On the FIRST build the render box has no layout yet (and after a
  /// rebuild the new layout isn't in yet), so visibility is confirmed
  /// once the frame is out.
  void _recheckAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recheck();
    });
  }

  /// The app shell keeps inactive tabs mounted (IndexedStack) with their
  /// tickers disabled — TickerMode is the "is this tab on screen" signal
  /// — and scrollable hosts keep off-screen banners mounted too, so the
  /// enclosing viewport must actually show the banner. Each
  /// visible→hidden transition flushes its own episode, so separate
  /// appearances never merge and persistence doesn't wait for disposal.
  void _recheck() {
    final visible = TickerMode.valuesOf(context).enabled && _inViewport();
    if (visible) {
      if (!_visible.isRunning) _visible.start();
    } else if (_visible.isRunning) {
      _flushEpisode();
    }
  }

  bool _inViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = _position;
    if (viewport == null ||
        position == null ||
        !position.hasPixels ||
        !position.hasViewportDimension) {
      // No scrollable ancestor (the day page nudge column): mounted on a
      // visible tab means on screen.
      return true;
    }
    final leadingEdge = viewport.getOffsetToReveal(box, 0).offset;
    return leadingEdge < position.pixels + position.viewportDimension &&
        leadingEdge + box.size.height > position.pixels;
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
    _position?.removeListener(_recheck);
    _flushEpisode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
