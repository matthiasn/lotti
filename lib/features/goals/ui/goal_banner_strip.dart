import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';

/// The banner mount: renders every active goal ad, newest first, and
/// shrinks to nothing when there are none (the `KnowledgeNudge`
/// contract — hosts mount it unconditionally).
///
/// Exposure accounting: each banner's on-screen time is measured from
/// mount to unmount and flushed as ONE episode per appearance, matching
/// the leave-viewport contract of `GoalNudgeInteractions.recordExposure`.
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
          for (final entry in entries)
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
    // actually on screen" signal, and the stopwatch only runs under it.
    if (TickerMode.valuesOf(context).enabled) {
      _visible.start();
    } else {
      _visible.stop();
    }
  }

  @override
  void dispose() {
    _visible.stop();
    if (_visible.elapsed > Duration.zero) {
      _flush?.call(widget.nudgeId, _visible.elapsed);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
