import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_spotlight.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mounts the [DailyOsOnboardingSpotlight] over the empty-Day check-in CTA
/// while a Daily OS onboarding walkthrough session is active.
///
/// Rendered as a full-bleed layer above the Day surface: it measures the real
/// CTA (identified by [ctaKey]) and draws the dimmed cutout + coaching card
/// over it. For every normal user — no active session, or [enabled] false
/// because the day already has a plan — it collapses to nothing and the Day
/// surface behaves exactly as before.
///
/// When the spotlight first surfaces it records the walkthrough's top-of-funnel
/// `dailyOsWalkthroughShown` event (once per session), so the funnel's shown
/// count reflects a spotlight the user actually saw rather than a merely-armed
/// session.
///
/// - "Try it" (or a tap on the highlighted CTA) calls [onCheckIn] to open the
///   real create modal and hides the spotlight for the rest of this mount; the
///   session stays active so the modal's coach strips still show.
/// - A scrim / "Not now" dismissal records the session skip and ends the
///   session, which removes the spotlight.
class DayCheckInSpotlightHost extends ConsumerStatefulWidget {
  const DayCheckInSpotlightHost({
    required this.ctaKey,
    required this.enabled,
    required this.onCheckIn,
    super.key,
  });

  /// Key on the real check-in CTA button, used to measure its rect.
  final GlobalKey ctaKey;

  /// Whether the empty-Day CTA exists (false once the day has a plan).
  final bool enabled;

  /// Opens the real create modal — the same handler the CTA runs.
  final VoidCallback? onCheckIn;

  @override
  ConsumerState<DayCheckInSpotlightHost> createState() =>
      _DayCheckInSpotlightHostState();
}

class _DayCheckInSpotlightHostState
    extends ConsumerState<DayCheckInSpotlightHost> {
  Rect? _targetRect;
  bool _proceeded = false;

  /// The session id whose `Shown` funnel event has already been scheduled from
  /// this mount. Tracked by id (not a plain bool) so a replay that starts a new
  /// session while this host stays mounted still records its own `Shown` event.
  /// The session's own once-guard keeps it exactly-once per session; this only
  /// avoids re-scheduling a post-frame callback on every rebuild.
  String? _recordedSessionId;

  /// Measures the CTA's rect in this host's local coordinate space — the same
  /// space the spotlight lays out in. The host is a full-bleed layer over the
  /// Day surface, but it is not guaranteed to start at the global origin
  /// (desktop split-pane, embedded layouts), so the CTA's global position is
  /// converted back into the host's local space rather than assumed equal.
  void _measure() {
    final box = widget.ctaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final hostBox = context.findRenderObject() as RenderBox?;
    if (hostBox == null || !hostBox.hasSize) return;
    final localTopLeft = hostBox.globalToLocal(box.localToGlobal(Offset.zero));
    final rect = localTopLeft & box.size;
    if (rect != _targetRect) setState(() => _targetRect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(dailyOsOnboardingSessionControllerProvider);
    if (session == null || !widget.enabled || _proceeded) {
      return const SizedBox.shrink();
    }

    // Re-measure after each frame so the highlight tracks CTA layout changes
    // (rotation, text scale, keyboard) without a bespoke geometry listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final rect = _targetRect;
    if (rect == null) return const SizedBox.shrink();

    // The walkthrough is now actually on-screen (session active, empty-Day CTA
    // measured), so this is the moment to record the funnel's top-of-funnel
    // `Shown` event — recorded here, not by the arming layer, so it reflects a
    // spotlight the user genuinely saw. `recordStageOnce` is idempotent per
    // session; tracking the session id keeps a replay's new session from being
    // suppressed while this host stays mounted.
    if (_recordedSessionId != session.sessionId) {
      _recordedSessionId = session.sessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(dailyOsOnboardingSessionControllerProvider)
            ?.recordStageOnce(OnboardingEventName.dailyOsWalkthroughShown);
      });
    }

    return DailyOsOnboardingSpotlight(
      targetRect: rect,
      title: context.messages.dailyOsOnboardingSpotlightTitle,
      message: context.messages.dailyOsOnboardingSpotlightMessage,
      actionLabel: context.messages.dailyOsOnboardingSpotlightAction,
      dismissLabel: context.messages.dailyOsOnboardingSpotlightDismiss,
      onAction: () {
        // Opening the modal is progress, not a skip: hide the spotlight but
        // leave the session running for the modal's coach strips.
        setState(() => _proceeded = true);
        widget.onCheckIn?.call();
      },
      onDismiss: () {
        session.recordSkippedOnce();
        ref.read(dailyOsOnboardingSessionControllerProvider.notifier).end();
      },
    );
  }
}
