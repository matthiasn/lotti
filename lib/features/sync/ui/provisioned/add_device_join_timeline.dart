import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the inviting sheet is waiting on, shared between the scroll body and
/// the pinned bar. The bar is built outside the view's `State`, and the live
/// signal has to live there: on a phone the body's own status strip can sit
/// below the fold, so a caption pointing "above" pointed at nothing.
enum AddDeviceJoinState { waiting, joined, ready, rosterFailed }

/// The three stops of the inviting side's wait, with the live one pulsing.
class AddDeviceJoinTimeline extends StatelessWidget {
  const AddDeviceJoinTimeline({required this.state, super.key});

  final AddDeviceJoinState state;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    // rosterFailed pauses the *poll*, not the journey: the stops keep their
    // last honest reading while the bar explains the retry.
    final reached = switch (state) {
      AddDeviceJoinState.waiting || AddDeviceJoinState.rosterFailed => 0,
      AddDeviceJoinState.joined => 1,
      AddDeviceJoinState.ready => 2,
    };
    final labels = [
      messages.syncAddDeviceTimelineWaiting,
      messages.syncAddDeviceTimelineJoined,
      messages.syncAddDeviceTimelineVerified,
    ];

    return Column(
      key: const Key('add_device_timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          _TimelineStop(
            label: labels[i],
            isDone:
                i < reached ||
                (i == reached && state == AddDeviceJoinState.ready),
            isActive: i == reached && state != AddDeviceJoinState.ready,
            isLast: i == labels.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotSide = tokens.spacing.step1 * 5;

    final Widget dot;
    if (isActive) {
      dot = _PulsingDot(side: dotSide);
    } else if (isDone) {
      dot = DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.interactive.enabled,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: dotSide, height: dotSide),
      );
    } else {
      dot = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: tokens.colors.decorative.level02,
            width: BorderWidths.emphasis,
          ),
        ),
        child: SizedBox(width: dotSide, height: dotSide),
      );
    }

    final labelStyle = isActive
        ? tokens.typography.styles.subtitle.subtitle2
        : tokens.typography.styles.body.bodySmall.copyWith(
            color: isDone
                ? tokens.colors.text.mediumEmphasis
                : tokens.colors.text.lowEmphasis,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: dot,
            ),
            if (!isLast)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.decorative.level01,
                ),
                child: SizedBox(
                  width: BorderWidths.emphasis,
                  height: tokens.spacing.step5,
                ),
              ),
          ],
        ),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step2),
            child: Text(label, style: labelStyle),
          ),
        ),
      ],
    );
  }
}

/// The live stop's marker: a softly pulsing accent dot; steady under reduced
/// motion.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.side});

  final double side;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.interactive.enabled,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: widget.side, height: widget.side),
      ),
    );
  }
}
