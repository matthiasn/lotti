import 'package:flutter/material.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

/// DEPRECATED: Use UnifiedAiToggleField directly instead
/// 
/// This wrapper is being removed to consolidate toggle implementations.
/// Replace usage with:
/// ```dart
/// UnifiedAiToggleField(
///   label: 'Your Label',
///   value: value,
///   onChanged: onChanged,
///   description: 'Optional description',
///   icon: Icons.your_icon,
/// )
/// ```
@Deprecated('Use UnifiedAiToggleField directly instead')
class AiSwitchField extends StatelessWidget {
  @Deprecated('Use UnifiedAiToggleField directly instead')
  const AiSwitchField({
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
    return UnifiedAiToggleField(
      label: label,
      value: value,
      onChanged: onChanged,
      description: description,
      enabled: enabled,
      icon: icon,
    );
  }
}
