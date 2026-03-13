import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/features/ratings/state/session_ended_controller.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/consts.dart';

/// A pulsating outline button that appears after a timer session ends,
/// prompting the user to rate the session. Pulses for ~10 seconds
/// then remains visible (without pulsing) until a rating is saved.
class PulsatingRateButton extends ConsumerWidget {
  const PulsatingRateButton({
    required this.entryId,
    required this.sessionJustEnded,
    super.key,
  });

  final String entryId;
  final bool sessionJustEnded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableRatingsAsync = ref.watch(
      configFlagProvider(enableSessionRatingsFlag),
    );
    final enableRatings =
        enableRatingsAsync.unwrapPrevious().whenData((v) => v).value ?? false;

    if (!enableRatings) return const SizedBox.shrink();

    final ratingAsync = ref.watch(
      ratingControllerProvider(targetId: entryId),
    );
    final hasRating = ratingAsync.value != null;

    // Clean up provider state when a rating is saved — deferred to avoid
    // mutating Riverpod state synchronously during the build phase.
    ref.listen(
      ratingControllerProvider(targetId: entryId),
      (previous, next) {
        if (previous?.value == null && next.value != null) {
          Future.microtask(() {
            ref
                .read(sessionEndedControllerProvider.notifier)
                .clearSessionEnded(entryId);
          });
        }
      },
    );

    if (hasRating) return const SizedBox.shrink();
    if (!sessionJustEnded) return const SizedBox.shrink();

    return _AnimatedRateButton(
      entryId: entryId,
      shouldPulse: sessionJustEnded,
    );
  }
}

class _AnimatedRateButton extends StatefulWidget {
  const _AnimatedRateButton({
    required this.entryId,
    required this.shouldPulse,
  });

  final String entryId;
  final bool shouldPulse;

  @override
  State<_AnimatedRateButton> createState() => _AnimatedRateButtonState();
}

class _AnimatedRateButtonState extends State<_AnimatedRateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isPulsing = false;

  /// Number of full pulse cycles (forward + reverse = 1 cycle).
  /// With a 1-second animation duration, each cycle is 2 seconds,
  /// so 5 cycles ≈ 10 seconds of pulsing.
  static const _maxPulseCycles = 5;
  int _completedCycles = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addStatusListener(_onAnimationStatus);

    if (widget.shouldPulse) {
      _startPulsing();
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    // Count a full cycle when the animation completes a reverse pass
    if (status == AnimationStatus.dismissed && _isPulsing) {
      _completedCycles++;
      if (_completedCycles >= _maxPulseCycles) {
        _controller.stop();
        setState(() => _isPulsing = false);
      }
    }
  }

  void _startPulsing() {
    _isPulsing = true;
    _completedCycles = 0;
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedRateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPulse && !oldWidget.shouldPulse && !_isPulsing) {
      _startPulsing();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = starredGold;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _isPulsing ? _animation.value : 1.0;
        final borderColor = baseColor.withValues(alpha: opacity);

        return IconButton(
          onPressed: () => RatingModal.show(context, widget.entryId),
          icon: Icon(Icons.star_rate_rounded, color: borderColor),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          tooltip: context.messages.sessionRatingRateAction,
        );
      },
    );
  }
}
