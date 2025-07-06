import 'package:flutter/material.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

/// A specialized version of AnimatedModalItem that also animates an icon
///
/// This widget composes AnimatedModalItem to reuse its animation logic,
/// while adding icon-specific animations on top.
class AnimatedModalItemWithIcon extends StatefulWidget {
  const AnimatedModalItemWithIcon({
    required this.child,
    required this.onTap,
    required this.iconBuilder,
    this.isDisabled = false,
    this.hoverScale = 0.99,
    this.tapScale = 0.97,
    this.tapOpacity = 1.0,
    this.hoverElevation = 4,
    this.iconScaleOnTap = 0.9,
    this.margin,
    this.disableShadow = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, Animation<double> iconAnimation,
      {required bool isPressed}) iconBuilder;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;
  final double iconScaleOnTap;
  final EdgeInsetsGeometry? margin;
  final bool disableShadow;

  @override
  State<AnimatedModalItemWithIcon> createState() =>
      _AnimatedModalItemWithIconState();
}

class _AnimatedModalItemWithIconState extends State<AnimatedModalItemWithIcon>
    with TickerProviderStateMixin {
  late AnimatedModalItemController _controller;
  late Animation<double> _iconScaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimatedModalItemController(vsync: this);
    _initializeAnimations();

    // Listen to tap animation state changes
    _controller.tapAnimationController.addStatusListener(_handleTapStatus);
  }

  void _handleTapStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      setState(() => _isPressed = true);
    } else if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  void didUpdateWidget(AnimatedModalItemWithIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.iconScaleOnTap != oldWidget.iconScaleOnTap) {
      _initializeAnimations();
    }
  }

  void _initializeAnimations() {
    _iconScaleAnimation = Tween<double>(
      begin: 1,
      end: widget.iconScaleOnTap,
    ).animate(CurvedAnimation(
      parent: _controller.tapAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.tapAnimationController.removeStatusListener(_handleTapStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedModalItem(
      controller: _controller,
      onTap: widget.onTap,
      isDisabled: widget.isDisabled,
      hoverScale: widget.hoverScale,
      tapScale: widget.tapScale,
      tapOpacity: widget.tapOpacity,
      hoverElevation: widget.hoverElevation,
      margin: widget.margin,
      disableShadow: widget.disableShadow,
      child: Stack(
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _iconScaleAnimation,
            builder: (context, _) => widget.iconBuilder(
              context,
              _iconScaleAnimation,
              isPressed: _isPressed,
            ),
          ),
        ],
      ),
    );
  }
}
