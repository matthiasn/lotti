import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/themes/theme.dart';

/// A pulsing dot indicator that shows when there is unseen What's New content.
///
/// This widget watches the whatsNewControllerProvider and displays a subtle
/// pulsing animation when hasUnseenRelease is true.
class WhatsNewIndicator extends ConsumerStatefulWidget {
  const WhatsNewIndicator({super.key});

  @override
  ConsumerState<WhatsNewIndicator> createState() => _WhatsNewIndicatorState();
}

class _WhatsNewIndicatorState extends ConsumerState<WhatsNewIndicator>
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
    final whatsNewAsync = ref.watch(whatsNewControllerProvider);

    return whatsNewAsync.when(
      data: (state) {
        if (!state.hasUnseenRelease) {
          return const SizedBox.shrink();
        }

        // Only initialize animation when needed
        _ensureAnimationInitialized();

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colorScheme.primary.withAlpha(
                  (_animation.value * 255).toInt(),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colorScheme.primary.withAlpha(
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
