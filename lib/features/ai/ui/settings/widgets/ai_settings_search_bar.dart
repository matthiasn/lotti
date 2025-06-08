import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A specialized search bar widget for AI Settings page
///
/// This widget provides a consistent search interface with proper styling
/// and behavior for filtering AI configurations.
///
/// **Features:**
/// - Material 3 design with rounded corners
/// - Clear button when text is present
/// - Proper color theming
/// - Accessibility support
///
/// **Usage:**
/// ```dart
/// AiSettingsSearchBar(
///   controller: _searchController,
///   onChanged: (query) => _handleSearchChange(query),
///   onClear: () => _clearSearch(),
/// )
/// ```
class AiSettingsSearchBar extends StatefulWidget {
  const AiSettingsSearchBar({
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search AI configurations...',
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

  @override
  State<AiSettingsSearchBar> createState() => _AiSettingsSearchBarState();
}

class _AiSettingsSearchBarState extends State<AiSettingsSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {
        // Rebuild when text changes to show/hide clear button
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: context.colorScheme.onSurfaceVariant,
            semanticLabel: 'Search icon',
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: context.colorScheme.onSurfaceVariant,
                    semanticLabel: 'Clear search',
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                  },
                  tooltip: 'Clear search',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: context.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: context.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: context.colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
      ),
    );
  }
}
