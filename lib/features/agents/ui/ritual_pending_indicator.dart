// Nullable fields are intentional: the AnimationController is only created
// when count > 0. Using `late` would trigger creation during dispose() for
// the count == 0 case, crashing with a deactivated widget ancestor lookup.
// ignore_for_file: use_late_for_private_fields_and_variables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// A pulsing dot indicator that shows when there are pending ritual reviews.
///
/// Uses [GameyColors.primaryPurple] to distinguish from the What's New
/// indicator which uses `colorScheme.primary`.
class RitualPendingIndicator extends ConsumerStatefulWidget {
  const RitualPendingIndicator({super.key});

  @override
  ConsumerState<RitualPendingIndicator> createState() =>
      _RitualPendingIndicatorState();
}

class _RitualPendingIndicatorState extends ConsumerState<RitualPendingIndicator>
    with SingleTickerProviderStateMixin {
  // Nullable: the controller is only created when count > 0. Using `late`
  // would trigger creation during dispose() for the count == 0 case,
  // crashing with a deactivated widget ancestor lookup.
  AnimationController? _controller;
  Animation<double>? _animation;

  void _ensureAnimationInitialized() {
    if (_controller != null) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _controller = controller;
    _animation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(
      templatesPendingReviewProvider
          .select((async) => async.value?.length ?? 0),
    );

    if (count == 0) {
      _controller?.stop();
      return const SizedBox.shrink();
    }

    _ensureAnimationInitialized();
    final controller = _controller!;
    if (!controller.isAnimating) controller.repeat(reverse: true);
    final animation = _animation!;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GameyColors.primaryPurple.withAlpha(
              (animation.value * 255).toInt(),
            ),
            boxShadow: [
              BoxShadow(
                color: GameyColors.primaryPurple.withAlpha(
                  (animation.value * 128).toInt(),
                ),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
