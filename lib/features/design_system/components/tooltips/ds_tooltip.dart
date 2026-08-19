import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// The context menu's soft shadow, shared verbatim: the design system has no
// elevation-shadow token yet, and the two floating surfaces must match.
const _kShadowColor = Color.fromRGBO(70, 70, 70, 0.25);
const _kShadowBlurRadius = 4.0;
const _kShadowOffsetY = 2.0;

/// How long a resting pointer waits before the tooltip appears. The stock
/// zero-wait tooltip fires the moment a cursor crosses the target, which on a
/// dense strip of targets turns a horizontal mouse move into a strobe.
const _kWaitDuration = Duration(milliseconds: 300);

/// The design-system tooltip: the context menu's floating-surface language —
/// `background.level01` fill, hairline outline, soft shadow, rounded
/// corners — around caption type, replacing the stock Material grey slab.
///
/// Two forms. A plain [message] renders one high-emphasis caption line. With
/// [title] set, the title names the subject (a date, an entity) in semibold
/// high-emphasis ink and the message describes it a step quieter underneath —
/// the shape a data readout wants, where "what am I pointing at" and "what
/// happened there" are different facts.
///
/// Positioning, trigger gestures and semantics all stay [Tooltip]'s; this
/// widget only owns the surface and the type.
class DsTooltip extends StatelessWidget {
  const DsTooltip({
    required this.message,
    required this.child,
    this.title,
    this.preferBelow,
    this.excludeFromSemantics,
    super.key,
  });

  /// The body line. With no [title], also the only line.
  final String message;

  /// Optional lead line naming what the tooltip describes.
  final String? title;

  /// Forwarded to [Tooltip.preferBelow]. Pass false above content that sits
  /// low in its card, so the tip never covers the row the pointer is reading.
  final bool? preferBelow;

  /// Forwarded to [Tooltip.excludeFromSemantics] when an ancestor already
  /// speaks the same fact through its own label.
  final bool? excludeFromSemantics;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final caption = tokens.typography.styles.others.caption;
    final title = this.title;
    return Tooltip(
      richMessage: TextSpan(
        children: [
          if (title != null)
            TextSpan(
              text: '$title\n',
              style: caption.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: tokens.typography.weight.semiBold,
              ),
            ),
          TextSpan(
            text: message,
            style: caption.copyWith(
              // Alone it carries the whole tip and gets the reading ink;
              // under a title it is the quieter second voice.
              color: title == null
                  ? tokens.colors.text.highEmphasis
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: tokens.colors.decorative.level01),
        boxShadow: const [
          BoxShadow(
            color: _kShadowColor,
            offset: Offset(0, _kShadowOffsetY),
            blurRadius: _kShadowBlurRadius,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      waitDuration: _kWaitDuration,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
  }
}
