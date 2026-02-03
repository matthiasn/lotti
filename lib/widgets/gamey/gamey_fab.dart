import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';

/// A floating action button that shows a custom character image
/// when the gamey theme is active, otherwise shows a standard FAB.
class GameyFab extends ConsumerWidget {
  const GameyFab({
    required this.onPressed,
    this.semanticLabel,
    this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final String? semanticLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final isGamey = themingState.isGameyThemeForBrightness(brightness);

    if (isGamey) {
      return _GameyFabImage(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      child: child ?? const Icon(Icons.add),
    );
  }
}

/// Custom gamey-styled FAB with character image
class _GameyFabImage extends StatefulWidget {
  const _GameyFabImage({
    required this.onPressed,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  State<_GameyFabImage> createState() => _GameyFabImageState();
}

class _GameyFabImageState extends State<_GameyFabImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.9,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isPressed
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Image.asset(
              'assets/images/gamey/add_button.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
