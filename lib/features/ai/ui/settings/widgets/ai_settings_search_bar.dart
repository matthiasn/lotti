import 'package:flutter/material.dart';
import 'package:lotti/widgets/search/index.dart';

/// A specialized search bar widget for AI Settings page
///
/// This widget wraps the LottiSearchBar with AI-specific defaults.
class AiSettingsSearchBar extends StatelessWidget {
  const AiSettingsSearchBar({
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search AI configurations...',
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

  /// Whether to use a more compact style (for app bar)
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LottiSearchBar(
      controller: controller,
      onChanged: onChanged,
      onClear: onClear,
      hintText: hintText,
      isCompact: isCompact,
    );
  }
}
