import 'package:flutter/material.dart';

/// A custom animated checkbox widget with label and optional subtitle.
///
/// This widget provides a modern checkbox design with smooth animations,
/// proper touch targets, and support for disabled states with informational text.
class LottiAnimatedCheckbox extends StatelessWidget {
  const LottiAnimatedCheckbox({
    required this.label,
    super.key,
    this.value,
    this.onChanged,
    this.subtitle,
    this.disabledIcon,
    this.enabled = true,
  });

  /// The main label text for the checkbox
  final String label;

  /// The current value of the checkbox (null means using default)
  final bool? value;

  /// Callback when the checkbox value changes
  final ValueChanged<bool?>? onChanged;

  /// Optional subtitle text (typically shown when disabled)
  final String? subtitle;

  /// Optional icon to show when disabled instead of checkbox
  final IconData? disabledIcon;

  /// Whether the checkbox is enabled
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChecked = value ?? false;
    final canTap = enabled && onChanged != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap ? () => onChanged?.call(!isChecked) : null,
        borderRadius: BorderRadius.circular(8),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Checkbox or icon
              if (enabled) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isChecked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isChecked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.6),
                      width: isChecked ? 0 : 1.5,
                    ),
                  ),
                  child: isChecked
                      ? Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ] else if (disabledIcon != null) ...[
                Icon(
                  disabledIcon,
                  size: 20,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
              const SizedBox(width: 10),
              // Label and subtitle
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && !enabled) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.45),
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
