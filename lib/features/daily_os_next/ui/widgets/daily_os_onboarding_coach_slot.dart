import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_coach_strip.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';

/// Session-aware slot that renders a [DailyOsOnboardingCoachStrip] at one beat
/// of the create modal — but only while a Daily OS onboarding walkthrough
/// session is active. For every other (normal) user it collapses to nothing.
///
/// When [recordStage] is set, the slot records that stage event exactly once
/// per session the first time the beat mounts (the once-guard lives in the
/// session, so a rebuild or a Wolt page recreation cannot double-count). The
/// Capture beat passes no stage — reaching Capture is the walkthrough opening,
/// already recorded as `Shown` by the arming layer.
class DailyOsOnboardingCoachSlot extends ConsumerStatefulWidget {
  const DailyOsOnboardingCoachSlot({
    required this.message,
    this.recordStage,
    super.key,
  });

  /// The one-line coaching sentence for this beat.
  final String message;

  /// Stage event to record once when this beat first mounts during a session.
  final OnboardingEventName? recordStage;

  @override
  ConsumerState<DailyOsOnboardingCoachSlot> createState() =>
      _DailyOsOnboardingCoachSlotState();
}

class _DailyOsOnboardingCoachSlotState
    extends ConsumerState<DailyOsOnboardingCoachSlot> {
  @override
  void initState() {
    super.initState();
    final stage = widget.recordStage;
    if (stage == null) return;
    // Record after the first frame so a metrics write never happens during
    // build. `recordStageOnce` is idempotent, so an absent session (no
    // walkthrough) is simply skipped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(dailyOsOnboardingSessionControllerProvider)
          ?.recordStageOnce(stage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(dailyOsOnboardingSessionControllerProvider);
    if (session == null) return const SizedBox.shrink();
    return DailyOsOnboardingCoachStrip(message: widget.message);
  }
}
