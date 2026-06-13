import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Default border alpha for idle picker fields — mirrors
/// `DesignSystemTextInput`'s resting border so pickers and text inputs
/// read as one field family inside a form section.
const double _kBorderAlpha = 0.12;

/// Tap-to-pick form field for settings editors (category, dashboard,
/// date/time pickers). Renders in the design-system input silhouette —
/// label above, bordered rounded field — with an optional [leading]
/// widget, the current value (or [hintText] when empty), an optional
/// clear affordance, and a dropdown chevron. The actual picking happens
/// in whatever modal [onTap] opens.
class SettingsPickerField extends StatelessWidget {
  const SettingsPickerField({
    required this.onTap,
    this.label,
    this.valueText,
    this.hintText,
    this.leading,
    this.onClear,
    this.helperText,
    this.semanticsLabel,
    this.enabled = true,
    super.key,
  });

  /// Field label rendered above the tappable row. Omit when the field is
  /// the sole content of a section whose header already names it.
  final String? label;

  /// Opens the picker (modal sheet / dialog).
  final VoidCallback onTap;

  /// When false the field is inert: it does not announce as a tappable
  /// button and ignores taps (e.g. a template picker with no templates).
  final bool enabled;

  /// Currently selected value; when null the field shows [hintText].
  final String? valueText;

  /// Placeholder when nothing is selected.
  final String? hintText;

  /// Optional leading visual (category icon, color dot, glyph).
  final Widget? leading;

  /// When provided (and a value is set), shows a clear button that
  /// resets the selection without opening the picker.
  final VoidCallback? onClear;

  /// Optional explanatory caption under the field — for the one field on
  /// a form whose label alone can't carry the meaning.
  final String? helperText;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final hasValue = valueText != null && valueText!.isNotEmpty;
    // Radius matches DesignSystemTextInput's field radius so the two
    // field families align inside a section card.
    final radius = BorderRadius.circular(spacing.step5);

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semanticsLabel ?? label ?? hintText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: spacing.step2),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: radius,
              child: Container(
                height: spacing.step9,
                padding: EdgeInsetsDirectional.only(
                  start: spacing.step4,
                  end: spacing.step3,
                ),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: tokens.colors.text.highEmphasis.withValues(
                      alpha: _kBorderAlpha,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      SizedBox(width: spacing.step3),
                    ],
                    Expanded(
                      child: Text(
                        hasValue ? valueText! : (hintText ?? ''),
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: hasValue
                                  ? tokens.colors.text.highEmphasis
                                  : tokens.colors.text.lowEmphasis,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasValue && onClear != null)
                      IconButton(
                        onPressed: onClear,
                        icon: Icon(
                          Icons.close_rounded,
                          size: spacing.step5,
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                      ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: spacing.step6,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            SizedBox(height: spacing.step2),
            Text(
              helperText!,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
