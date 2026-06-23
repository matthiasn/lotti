import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';

/// AI Settings search field.
///
/// Thin adapter over the design system's [DesignSystemSearch] so the AI
/// settings search shares one token-styled component with the rest of the
/// app. [isCompact] maps to [DesignSystemSearchSize.small].
class AiSettingsSearchBar extends StatelessWidget {
  const AiSettingsSearchBar({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.isCompact = false,
    super.key,
  });

  /// Controller for the search text field
  final TextEditingController controller;

  /// Callback invoked when search text changes
  final ValueChanged<String>? onChanged;

  /// Callback invoked when clear button is pressed
  final VoidCallback? onClear;

  /// Hint text displayed when field is empty
  final String hintText;

  /// Whether to use the compact (small) size variant
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return DesignSystemSearch(
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      onClear: onClear,
      size: isCompact
          ? DesignSystemSearchSize.small
          : DesignSystemSearchSize.medium,
    );
  }
}
