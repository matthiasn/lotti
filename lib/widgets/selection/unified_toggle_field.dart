part of 'unified_toggle.dart';

/// Unified toggle with integrated label for form-like contexts
/// Matches the exact styling of existing FormSwitch implementations
class UnifiedToggleField extends StatelessWidget {
  const UnifiedToggleField({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.variant = UnifiedToggleVariant.normal,
    this.activeColor,
    this.enabled = true,
    this.dense = false,
    this.contentPadding,
    this.leading,
    this.semanticLabel,
    this.semanticsLabel,
    super.key,
  });

  /// Current toggle state
  final bool value;

  /// Callback when toggle state changes
  final ValueChanged<bool>? onChanged;

  /// Main label text
  final String title;

  /// Optional subtitle/description text
  final String? subtitle;

  /// Visual variant of the toggle
  final UnifiedToggleVariant variant;

  /// Custom active color (overrides variant color)
  final Color? activeColor;

  /// Whether the toggle is enabled
  final bool enabled;

  /// Whether to use dense layout
  final bool dense;

  /// Custom content padding
  final EdgeInsetsGeometry? contentPadding;

  /// Optional leading widget (e.g., icon)
  final Widget? leading;

  /// Semantic label for accessibility
  final String? semanticLabel;

  /// Semantic label for accessibility (FormSwitch naming convention)
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final toggle = UnifiedToggle(
      value: value,
      onChanged: onChanged,
      variant: variant,
      activeColor: activeColor,
      semanticLabel: semanticLabel ?? semanticsLabel ?? title,
      enabled: enabled,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding:
              contentPadding ??
              EdgeInsets.symmetric(
                horizontal: 16,
                vertical: dense ? 8 : 12,
              ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? context.colorScheme.onSurface
                            : context.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: enabled
                              ? context.colorScheme.onSurfaceVariant
                              : context.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.38,
                                ),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              toggle,
            ],
          ),
        ),
      ),
    );
  }
}

/// AI-specific toggle field that matches the AI Settings design language
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
            context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: value
                          ? context.colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            )
                          : context.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: value
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? context.colorScheme.onSurface
                              : context.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                UnifiedToggle(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  enabled: enabled,
                  semanticLabel: label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
