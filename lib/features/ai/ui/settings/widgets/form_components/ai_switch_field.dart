import 'package:flutter/material.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

/// A styled switch field component that matches the AI Settings design language
class AiSwitchField extends StatelessWidget {
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
