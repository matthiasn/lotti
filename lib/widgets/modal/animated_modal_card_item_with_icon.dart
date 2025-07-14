import 'package:flutter/material.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/modal/animated_modal_card_item.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

/// A specialized version for ModalCard widgets that also animates an icon
///
/// This widget combines AnimatedModalCardItem functionality with icon animations,
/// specifically designed for modal card use cases.
class AnimatedModalCardItemWithIcon extends StatefulWidget {
  const AnimatedModalCardItemWithIcon({
    required this.modalCard,
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

  final ModalCard modalCard;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, Animation<double> iconAnimation,
      {required bool isPressed}) iconBuilder;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;
  final double iconScaleOnTap;
  final EdgeInsets? margin;
  final bool disableShadow;

  @override
  State<AnimatedModalCardItemWithIcon> createState() =>
      _AnimatedModalCardItemWithIconState();
}

class _AnimatedModalCardItemWithIconState
    extends State<AnimatedModalCardItemWithIcon> with TickerProviderStateMixin {
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
  void didUpdateWidget(AnimatedModalCardItemWithIcon oldWidget) {
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
    return Stack(
      children: [
        AnimatedModalCardItem(
          onTap: widget.onTap,
          isDisabled: widget.isDisabled,
          hoverScale: widget.hoverScale,
          tapScale: widget.tapScale,
          tapOpacity: widget.tapOpacity,
          hoverElevation: widget.hoverElevation,
          margin: widget.margin,
          disableShadow: widget.disableShadow,
          cardBuilder: (context, controller) => widget.modalCard,
        ),
        AnimatedBuilder(
          animation: _iconScaleAnimation,
          builder: (context, _) => widget.iconBuilder(
            context,
            _iconScaleAnimation,
            isPressed: _isPressed,
          ),
        ),
      ],
    );
  }
}
