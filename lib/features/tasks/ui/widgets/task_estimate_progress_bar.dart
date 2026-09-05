import 'dart:math' as math;

import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:material_ui/material_ui.dart';

/// The small tracked-of-estimated bar shared by the task header's estimate
/// read-out and the details section's Estimate row: green while the tracked
/// time fits inside the estimate, red once it runs over.
///
/// Sized 36×6 verbatim from the header chip it descends from, so the read-out
/// stays visually continuous with what it replaced (no sizing token matches a
/// 6px bar height).
class TaskEstimateProgressBar extends StatelessWidget {
  const TaskEstimateProgressBar({
    required this.tracked,
    required this.estimate,
    super.key,
  });

  final Duration tracked;
  final Duration estimate;

  /// Whether [tracked] has run past [estimate].
  static bool isOvertime({
    required Duration tracked,
    required Duration estimate,
  }) => tracked > estimate;

  /// The filled fraction of the bar, clamped to `1` once the estimate is
  /// exceeded and `0` for a non-positive estimate.
  static double fraction({
    required Duration tracked,
    required Duration estimate,
  }) {
    if (estimate <= Duration.zero) return 0;
    if (tracked <= Duration.zero) return 0;
    return math.min(tracked.inSeconds / estimate.inSeconds, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final overtime = isOvertime(tracked: tracked, estimate: estimate);
    final barTrack = overtime
        ? TaskShowcasePalette.error(context).withValues(alpha: 0.2)
        : TaskShowcasePalette.lowText(context).withValues(alpha: 0.2);
    final barFill = overtime
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.success(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: SizedBox(
        width: 36,
        height: 6,
        child: LinearProgressIndicator(
          value: fraction(tracked: tracked, estimate: estimate),
          backgroundColor: barTrack,
          color: barFill,
        ),
      ),
    );
  }
}
