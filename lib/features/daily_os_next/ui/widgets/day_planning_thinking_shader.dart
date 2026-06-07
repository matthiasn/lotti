import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';

/// Day-planning variant of the Task Details "AI is thinking" decoder-bars
/// shader.
///
/// Reuses [AiThinkingShaderPresence] — the exact same shader visual and
/// fade/scale presence envelope used on the Task Details action bar — but
/// is driven by the planner's own busy signal (capture transcribing,
/// reconcile loading, drafting, or refine "thinking") rather than the
/// per-entry inference provider that [AiRunningDecoderBars] watches.
///
/// Designed to sit in the `topSlot` of the day-planning glass action bar so
/// the shader rides the top edge of the bar, mirroring Task Details.
class DayPlanningThinkingShader extends StatelessWidget {
  const DayPlanningThinkingShader({required this.isThinking, super.key});

  /// Whether the day agent is currently working. Drives the presence
  /// envelope: true fades/scales the shader in, false reverses it out.
  final bool isThinking;

  /// Stable key on the animated reserved-height box, for presence asserts.
  @visibleForTesting
  static const Key indicatorKey = ValueKey('day-planning-thinking-shader');

  @override
  Widget build(BuildContext context) {
    return AiThinkingShaderPresence(
      isRunning: isThinking,
      indicatorKey: indicatorKey,
    );
  }
}
