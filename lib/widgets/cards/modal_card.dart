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
    this.borderColor,
    this.onTap,
    this.isDisabled = false,
    this.animationController,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool isDisabled;
  final AnimatedModalItemController? animationController;

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
    return Card(
      elevation: 0,
      surfaceTintColor: context.colorScheme.surfaceTint,
      color: backgroundColor,
      clipBehavior: Clip.hardEdge,
      shape: borderColor != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              side: BorderSide(color: borderColor!),
            )
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
  }
}
