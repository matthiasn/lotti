import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';
import 'package:material_ui/material_ui.dart';

/// AI-specific toggle field that matches the AI Settings design language.
///
/// It shares the settings selector rows' surface, border, insets, icon size
/// and type scale, so a column of selectors and toggles lines up. The switch
/// carries the on/off state; the frame stays the same either way.
class UnifiedAiToggleField extends StatelessWidget {
  const UnifiedAiToggleField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
    this.icon,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    final mutedAlpha = enabled ? 1.0 : 0.5;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: radius,
            border: Border.all(
              color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: tokens.colors.text.mediumEmphasis.withValues(
                        alpha: mutedAlpha,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis.withValues(
                          alpha: mutedAlpha,
                        ),
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  UnifiedToggle(
                    value: value,
                    onChanged: enabled ? onChanged : null,
                    enabled: enabled,
                    semanticLabel: label,
                  ),
                ],
              ),
              // Full width under the headline row, starting at the icon's
              // edge rather than indented past it, so it wraps in fewer lines.
              if (description != null) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  description!,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
