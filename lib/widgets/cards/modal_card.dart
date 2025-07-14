import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A card widget specifically designed for use in modals
/// Provides better contrast and visual separation against modal backgrounds
class ModalCard extends StatelessWidget {
  const ModalCard({
    required this.child,
    this.onTap,
    this.padding,
    this.elevation,
    this.shadowColor,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Color? shadowColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      surfaceTintColor: context.colorScheme.surfaceTint,
      color: backgroundColor,
      child: Container(
        padding: padding,
        child: child,
      ),
    );
  }
}
