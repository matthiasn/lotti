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
    return Container(
      height: widget.isCompact ? 36 : 48,
      decoration: BoxDecoration(
        gradient: widget.isCompact
            ? null
            : LinearGradient(
                colors: [
                  context.colorScheme.surfaceContainer,
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        color: widget.isCompact
            ? context.colorScheme.surfaceContainer.withValues(alpha: 0.8)
            : null,
        borderRadius: BorderRadius.circular(widget.isCompact ? 12 : 16),
        border: Border.all(
          color: context.colorScheme.primaryContainer
              .withValues(alpha: widget.isCompact ? 0.1 : 0.2),
        ),
        boxShadow: widget.isCompact
            ? []
            : [
                BoxShadow(
                  color: context.colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: context.colorScheme.onSurface,
          fontSize: widget.isCompact ? 14 : 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: widget.isCompact ? 14 : 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colorScheme.primary.withValues(alpha: 0.8),
            size: widget.isCompact ? 20 : 22,
            semanticLabel: 'Search icon',
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      widget.controller.clear();
                      widget.onClear?.call();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.clear_rounded,
                        color: context.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        size: 20,
                        semanticLabel: 'Clear search',
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
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
