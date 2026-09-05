import 'package:flutter/services.dart' show HapticFeedback;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The design-system's compact value stepper — a bounded −/value/+ control.
///
/// Renders the current [label] (e.g. "3× / 7 days") between decrement and
/// increment glyphs inside one contained band, so the value reads as an
/// adjustable control rather than loose text floating in a row. The value
/// uses tabular figures so stepping does not make the band jitter.
///
/// A null [onDecrement]/[onIncrement] disables that side. Each glyph keeps
/// the [TapTargets.minimum] pointer target of an icon-only control, and
/// [decrementTooltip]/[incrementTooltip] double as the semantic labels.
class DesignSystemStepper extends StatelessWidget {
  const DesignSystemStepper({
    required this.label,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.onDecrement,
    required this.onIncrement,
    this.decrementKey,
    this.incrementKey,
    super.key,
  });

  /// The rendered value, already formatted and localized by the caller.
  final String label;
  final String decrementTooltip;
  final String incrementTooltip;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// Optional keys for the glyph buttons so feature tests can target them.
  final Key? decrementKey;
  final Key? incrementKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The band swallows stray taps: a near-miss beside a glyph must not
    // fall through to whatever row hosts the stepper.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () {},
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          borderRadius: BorderRadius.circular(tokens.radii.smallChips),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperGlyph(
              key: decrementKey,
              icon: LottiIcons.remove,
              tooltip: decrementTooltip,
              onPressed: onDecrement,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
              child: Text(
                label,
                // One level below a selection-row title, so the row's name
                // outranks its cadence.
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _StepperGlyph(
              key: incrementKey,
              icon: LottiIcons.add,
              tooltip: incrementTooltip,
              onPressed: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of the stepper: an accent-colored icon-only button with the
/// standard minimum pointer target. Disabled sides drop to low emphasis.
class _StepperGlyph extends StatelessWidget {
  const _StepperGlyph({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = onPressed != null;

    void handleTap() {
      HapticFeedback.selectionClick();
      onPressed!();
    }

    return Semantics(
      container: true,
      button: true,
      label: tooltip,
      enabled: enabled,
      onTap: enabled ? handleTap : null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.smallChips),
              onTap: enabled ? handleTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: TapTargets.minimum,
                  minHeight: TapTargets.minimum,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  // A circular container carries "tappable" by shape, so the
                  // accent glyph does not have to do it alone.
                  child: Container(
                    width: tokens.spacing.step7,
                    height: tokens.spacing.step7,
                    decoration: BoxDecoration(
                      color: tokens.colors.background.level02,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: IconSizes.s,
                      color: enabled
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
