import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

/// A card widget specifically designed for use in modals
/// Provides better contrast and visual separation against modal backgrounds
class ModalCard extends StatelessWidget {
  const ModalCard({
    required this.child,
    this.padding,
    this.backgroundColor,
    this.onTap,
    this.isDisabled = false,
    this.animationController,
    this.border,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isDisabled;
  final AnimatedModalItemController? animationController;
  final BoxBorder? border;
  final BorderRadius? borderRadius;

  void _handleTapDown(TapDownDetails details) {
    if (!isDisabled && onTap != null) {
      animationController?.startTap();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!isDisabled && onTap != null) {
      animationController?.endTap();
    }
  }

  void _handleTapCancel() {
    if (!isDisabled && onTap != null) {
      animationController?.endTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 2,
      surfaceTintColor: context.colorScheme.surfaceTint,
      color: backgroundColor,
      clipBehavior: Clip.hardEdge,
      shape: borderRadius != null
          ? RoundedRectangleBorder(borderRadius: borderRadius!)
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: Container(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    // Wrap with border decoration if provided
    if (border != null) {
      return Container(
        decoration: BoxDecoration(
          border: border,
          borderRadius: borderRadius,
        ),
        child: card,
      );
    }

    return card;
  }
}
