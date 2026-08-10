import 'package:flutter/material.dart';
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
/// and is flushed on every visible→hidden transition and on unmount.
/// Scroll-out within an active page is deliberately not tracked: the
/// strip sits at the top of its hosts, and per-frame viewport math would
/// buy little for this surface.
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
              child: _ExposureTracker(
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

/// Measures one visibility episode: stopwatch from mount, flushed on
/// unmount (page left, banner dismissed, list refreshed). Deliberately
/// coarse — a banner in a `Column` on a mounted page IS on screen, and
/// per-frame viewport math would buy little for a surface this small.
class _ExposureTracker extends ConsumerStatefulWidget {
  const _ExposureTracker({
    required this.nudgeId,
    required this.child,
    super.key,
  });

  final String nudgeId;
  final Widget child;

  @override
  ConsumerState<_ExposureTracker> createState() => _ExposureTrackerState();
}

class _ExposureTrackerState extends ConsumerState<_ExposureTracker> {
  final Stopwatch _visible = Stopwatch();
  GoalNudgeInteractionsFlush? _flush;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured while the element is live: `ref` must not be touched from
    // dispose, and the flush must survive the widget's death.
    _flush = ref.read(goalNudgeExposureFlushProvider);
    // The app shell keeps inactive tabs mounted (IndexedStack) with
    // their tickers disabled — TickerMode is therefore the "is this tab
    // actually on screen" signal. Each visible→hidden transition flushes
    // its own episode, so separate appearances never merge and
    // persistence doesn't wait for disposal.
    if (TickerMode.valuesOf(context).enabled) {
      _visible.start();
    } else if (_visible.isRunning) {
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
  Widget build(BuildContext context) => widget.child;
}
