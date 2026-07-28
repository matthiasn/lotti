import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A level-01 inset well on the sync sheets' level-02 surface.
///
/// The sheets are painted `background.level02`, so recessing content one
/// level *down* is what makes a block read as a distinct object — the QR
/// pairing card, the check-code hero, the emoji cells. Deliberately not
/// [SyncFlowSection]: that card elevates with border and shadow, and a well
/// is the opposite move.
class SyncWell extends StatelessWidget {
  const SyncWell({
    required this.child,
    super.key,
    this.padding,
    this.radius,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// Corner radius; defaults to the medium radius token.
  final double? radius;

  /// Optional toned outline — the credential frame borrows the warning tone
  /// so the border itself carries the caveat.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final borderColor = this.borderColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(radius ?? tokens.radii.m),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.spacing.cardPadding),
        child: child,
      ),
    );
  }
}
