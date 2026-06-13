import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

export 'package:lotti/widgets/selection/unified_toggle_field.dart';

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
      case UnifiedToggleVariant.cupertino:
        // CupertinoSwitch default behavior
        return context.colorScheme.outline.withValues(
          alpha: _UnifiedToggleConstants.inactiveTrackOpacity,
        );
      case UnifiedToggleVariant.normal:
      case UnifiedToggleVariant.warning:
      case UnifiedToggleVariant.priority:
      case UnifiedToggleVariant.archived:
        // FormSwitch default behavior - preserve exact opacity
        return context.colorScheme.outline.withValues(
          alpha: _UnifiedToggleConstants.inactiveTrackOpacity,
        );
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
