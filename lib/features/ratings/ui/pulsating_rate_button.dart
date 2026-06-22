import 'dart:async';

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
  bool _pulseStartChecked = false;

  /// Number of full pulse cycles (forward + reverse = 1 cycle). With a
  /// 1-second animation duration per leg, 5 cycles is about 10 seconds.
  static const _maxPulseCycles = 5;
  static const _repeatIterationsPerCycle = 2;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start the pulse here (not initState) so the reduced-motion setting is
    // readable: under reduced motion the button stays visible but never pulses.
    if (_pulseStartChecked) return;
    _pulseStartChecked = true;
    if (widget.shouldPulse && !MediaQuery.disableAnimationsOf(context)) {
      _startPulsing();
    }
  }

  void _startPulsing() {
    if (_isPulsing) return;
    _isPulsing = true;
    unawaited(
      _controller
          .repeat(
            reverse: true,
            count: _maxPulseCycles * _repeatIterationsPerCycle,
          )
          .whenComplete(() {
            if (!mounted) return;
            _controller.value = 1;
            setState(() => _isPulsing = false);
          }),
    );
  }

  @override
  void didUpdateWidget(_AnimatedRateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPulse &&
        !oldWidget.shouldPulse &&
        !_isPulsing &&
        !MediaQuery.disableAnimationsOf(context)) {
      _startPulsing();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
