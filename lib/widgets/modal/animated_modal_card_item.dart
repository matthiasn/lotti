import 'package:flutter/material.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

/// A specialized version of AnimatedModalItem specifically for ModalCard widgets
///
/// This widget ensures that ModalCard gets proper animation controller and tap handling
/// to enable both ink splash effects and scale/opacity animations.
class AnimatedModalCardItem extends StatefulWidget {
  const AnimatedModalCardItem({
    required this.onTap,
    required this.cardBuilder,
    this.isDisabled = false,
    this.hoverScale = 0.99,
    this.tapScale = 0.98,
    this.tapOpacity = 0.8,
    this.hoverElevation = 4,
    this.margin,
    this.disableShadow = false,
    super.key,
  });

  final VoidCallback? onTap;
  final ModalCard Function(
      BuildContext context, AnimatedModalItemController controller) cardBuilder;
  final bool isDisabled;
  final double hoverScale;
  final double tapScale;
  final double tapOpacity;
  final double hoverElevation;
  final EdgeInsets? margin;
  final bool disableShadow;

  @override
  State<AnimatedModalCardItem> createState() => _AnimatedModalCardItemState();
}

class _AnimatedModalCardItemState extends State<AnimatedModalCardItem>
    with TickerProviderStateMixin {
  late AnimatedModalItemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimatedModalItemController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cardBuilder(context, _controller);
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
      child: ModalCard(
        padding: card.padding,
        backgroundColor: card.backgroundColor,
        onTap: widget.onTap,
        isDisabled: widget.isDisabled,
        animationController: _controller,
        child: card.child,
      ),
    );
  }
}
