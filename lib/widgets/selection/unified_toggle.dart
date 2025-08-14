import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

// Constants for better maintainability
class _UnifiedToggleConstants {
  // iOS system green color for CupertinoSwitch consistency
  static const Color iosSystemGreen = Color(0xFF34C759);

  // Opacity constants
  static const double inactiveTrackOpacity =
      51.0 / 255.0; // withAlpha(51) equivalent
}

/// Unified toggle/switch component for consistent selection behavior across the app
///
/// This component provides a single source of truth for all toggle/switch interactions
/// while preserving the exact colors and styles of existing implementations.
///
/// Features:
/// - Preserves exact colors and styles from existing implementations
/// - Configurable variants to match different use cases (normal, warning, priority, archived)
/// - Proper opacity and color handling to maintain current appearances
/// - Accessibility support with semantic labels
/// - Platform-adaptive behavior when needed
enum UnifiedToggleVariant {
  /// Default variant using primary theme colors (matches FormSwitch default)
  normal,

  /// Warning variant for sensitive options (e.g., privacy settings)
  /// Uses error colors to indicate caution
  warning,

  /// Priority variant for starred/important items (e.g., habit priority)
  /// Uses gold color
  priority,

  /// Archived variant for inactive items (e.g., archived habits)
  /// Uses outline color
  archived,

  /// AI variant for AI settings (matches AiSwitchField styling)
  ai,

  /// Cupertino variant for iOS-style switches
  cupertino,
}

class UnifiedToggle extends StatelessWidget {
  const UnifiedToggle({
    required this.value,
    required this.onChanged,
    this.variant = UnifiedToggleVariant.normal,
    this.activeColor,
    this.semanticLabel,
    this.enabled = true,
    super.key,
  });

  /// Current toggle state
  final bool value;

  /// Callback when toggle state changes
  final ValueChanged<bool>? onChanged;

  /// Visual variant of the toggle
  final UnifiedToggleVariant variant;

  /// Custom active color (overrides variant color)
  final Color? activeColor;

  /// Semantic label for accessibility
  final String? semanticLabel;

  /// Whether the toggle is enabled
  final bool enabled;

  Color _getActiveColor(BuildContext context) {
    // Use custom color if provided
    if (activeColor != null) {
      return activeColor!;
    }

    switch (variant) {
      case UnifiedToggleVariant.warning:
        return context.colorScheme.error;
      case UnifiedToggleVariant.priority:
        return starredGold;
      case UnifiedToggleVariant.archived:
        return context.colorScheme.outline;
      case UnifiedToggleVariant.ai:
        return context.colorScheme.primary;
      case UnifiedToggleVariant.cupertino:
        // CupertinoSwitch uses default iOS green
        return _UnifiedToggleConstants.iosSystemGreen;
      case UnifiedToggleVariant.normal:
        // Default FormSwitch behavior - no activeColor specified
        return context.colorScheme.primary;
    }
  }

  Color _getInactiveThumbColor(BuildContext context) {
    switch (variant) {
      case UnifiedToggleVariant.ai:
        return context.colorScheme.onSurfaceVariant;
      case UnifiedToggleVariant.cupertino:
        // CupertinoSwitch default behavior
        return context.colorScheme.outline;
      case UnifiedToggleVariant.normal:
      case UnifiedToggleVariant.warning:
      case UnifiedToggleVariant.priority:
      case UnifiedToggleVariant.archived:
        // FormSwitch default behavior
        return context.colorScheme.outline;
    }
  }

  Color _getInactiveTrackColor(BuildContext context) {
    switch (variant) {
      case UnifiedToggleVariant.ai:
        return context.colorScheme.surfaceContainerHighest;
      case UnifiedToggleVariant.cupertino:
        // CupertinoSwitch default behavior
        return context.colorScheme.outline
            .withValues(alpha: _UnifiedToggleConstants.inactiveTrackOpacity);
      case UnifiedToggleVariant.normal:
      case UnifiedToggleVariant.warning:
      case UnifiedToggleVariant.priority:
      case UnifiedToggleVariant.archived:
        // FormSwitch default behavior - preserve exact opacity
        return context.colorScheme.outline
            .withValues(alpha: _UnifiedToggleConstants.inactiveTrackOpacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle CupertinoSwitch variant
    if (variant == UnifiedToggleVariant.cupertino) {
      return Semantics(
        label: semanticLabel,
        child: CupertinoSwitch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: _getActiveColor(context),
        ),
      );
    }

    // Handle regular Switch variants
    return Semantics(
      label: semanticLabel,
      child: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: _getActiveColor(context),
        inactiveThumbColor: _getInactiveThumbColor(context),
        inactiveTrackColor: _getInactiveTrackColor(context),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final toggle = UnifiedToggle(
      value: value,
      onChanged: onChanged,
      variant: variant,
      activeColor: activeColor,
      semanticLabel: semanticLabel ?? title,
      enabled: enabled,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: contentPadding ??
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
                            : context.colorScheme.onSurface
                                .withValues(alpha: 0.38),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: enabled
                              ? context.colorScheme.onSurfaceVariant
                              : context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.38),
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

/// Helper widget for form contexts that need FormBuilder integration
/// Preserves exact FormSwitch behavior and styling
class UnifiedFormBuilderToggle extends StatelessWidget {
  const UnifiedFormBuilderToggle({
    required this.name,
    required this.title,
    this.initialValue,
    this.subtitle,
    this.variant = UnifiedToggleVariant.normal,
    this.activeColor,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.semanticLabel,
    this.semanticsLabel,
    super.key,
  });

  /// Form field name
  final String name;

  /// Initial value
  final bool? initialValue;

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

  /// Optional change callback
  final ValueChanged<bool?>? onChanged;

  /// Optional validator
  // ignore: avoid_positional_boolean_parameters
  final String? Function(bool?)? validator;

  /// Semantic label for accessibility (old naming)
  final String? semanticLabel;

  /// Semantic label for accessibility (FormSwitch naming)
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: initialValue ?? false,
      validator: validator,
      builder: (FormFieldState<bool> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UnifiedToggleField(
              value: field.value ?? false,
              onChanged: enabled
                  ? (bool value) {
                      field.didChange(value);
                      onChanged?.call(value);
                    }
                  : null,
              title: title,
              subtitle: subtitle,
              variant: variant,
              activeColor: activeColor,
              enabled: enabled,
              semanticLabel: semanticsLabel ?? semanticLabel,
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: context.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// AI-specific toggle field that matches the exact AiSwitchField styling
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
                          ? context.colorScheme.primaryContainer
                              .withValues(alpha: 0.3)
                          : context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: value
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? context.colorScheme.onSurface
                              : context.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: TextStyle(
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
                  variant: UnifiedToggleVariant.ai,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
