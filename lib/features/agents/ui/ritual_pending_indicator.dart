import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// A pulsing dot indicator that shows when there are pending ritual reviews.
///
/// Follows the `WhatsNewIndicator` pattern with lazy animation initialization.
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
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAnimationInitialized = false;

  void _ensureAnimationInitialized() {
    if (_isAnimationInitialized) return;
    _isAnimationInitialized = true;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    if (_isAnimationInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(pendingRitualCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) {
          if (_isAnimationInitialized) _controller.stop();
          return const SizedBox.shrink();
        }

        _ensureAnimationInitialized();
        if (!_controller.isAnimating) _controller.repeat(reverse: true);

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameyColors.primaryPurple.withAlpha(
                  (_animation.value * 255).toInt(),
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameyColors.primaryPurple.withAlpha(
                      (_animation.value * 128).toInt(),
                    ),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
