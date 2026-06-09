# Selection Widgets

This directory contains reusable components for building consistent selection modals throughout the application, plus a family of unified toggle/switch widgets (see [Unified Toggles](#unified-toggles)). These components follow Material Design principles and provide a unified user experience for all selection interfaces.

## Overview

The selection widgets were created to eliminate code duplication across various selection modals (e.g. modality selection in `lib/features/ai/ui/settings/widgets/modality_selection_modal.dart` and the Gemini thinking-mode picker in `lib/features/ai/ui/widgets/gemini_thinking_mode_picker_modal.dart`) and provide a consistent, maintainable architecture for selection interfaces.

## Components

### SelectionOption

A reusable option widget that provides consistent styling for individual selection items.

**Features:**
- Consistent 16px border radius with 2px borders (prevents breathing effects)
- Proper shadows and visual feedback
- Support for icons, titles, and descriptions
- Customizable selection indicators
- Accessibility support

**Usage:**
```dart
SelectionOption(
  title: 'Option Title',
  description: 'Optional description text',
  icon: Icons.example_icon,
  isSelected: true,
  onTap: () => handleSelection(),
  // selectionIndicator: Icon(Icons.star), // Optional custom indicator widget;
  // when omitted, the default checkmark/empty-circle indicator is used.
)
```

### SelectionSaveButton

A standardized save button for selection modals with consistent styling.

**Features:**
- Elevated button with icon
- Proper disabled state styling
- Consistent padding and border radius
- Customizable label and icon

**Usage:**
```dart
SelectionSaveButton(
  onPressed: _handleSave, // null to disable
  label: 'Custom Label', // Optional, defaults to localized "Save"
  icon: Icons.done, // Optional, defaults to check mark
)
```

### SelectionModalBase

Provides standard modal structure using Wolt Modal Sheet.

**Features:**
- Consistent modal configuration
- Standard header with title and close button
- Proper background colors and styling
- Safe area handling

**Usage:**
```dart
SelectionModalBase.show(
  context: context,
  title: 'Select Options',
  child: YourModalContent(),
);
```

### SelectionModalContent

A wrapper widget that provides consistent padding and structure for modal content.

**Usage:**
```dart
SelectionModalContent(
  children: [
    // Your selection options
    SelectionOptionsList(...),
    SizedBox(height: 24),
    SelectionSaveButton(...),
  ],
)
```

### SelectionOptionsList

A flexible list widget for displaying selection options with consistent spacing.

**Usage:**
```dart
SelectionOptionsList(
  itemCount: options.length,
  itemBuilder: (context, index) {
    return SelectionOption(...);
  },
  separatorHeight: 8, // Optional, defaults to 8
)
```

## Unified Toggles

This directory also contains a family of toggle/switch components (in
`unified_toggle.dart` and its part file `unified_toggle_field.dart`). They are
**not** re-exported by the `selection.dart` barrel; import them directly from
`package:lotti/widgets/selection/unified_toggle.dart`.

### UnifiedToggle

A bare toggle that wraps Flutter's `Switch` (or `CupertinoSwitch` for the
`cupertino` variant) and selects active/inactive colors based on a
`UnifiedToggleVariant`. The `UnifiedToggleVariant` enum has five values:

- `normal` — primary theme color (default `FormSwitch` behavior)
- `warning` — error color, for sensitive options
- `priority` — `starredGold`, for starred/important items
- `archived` — outline color, for inactive items
- `cupertino` — renders a `CupertinoSwitch` with the iOS system green active track

An `activeColor` argument overrides the variant color. `enabled: false` disables
`onChanged`.

### UnifiedToggleField

A labeled toggle for form-like contexts: an `InkWell` row with a `title`,
optional `subtitle`, optional `leading` widget, and a trailing `UnifiedToggle`.
Tapping the row invokes `onChanged`. Accepts the same `variant`/`activeColor`
options as `UnifiedToggle`, plus `dense` and `contentPadding` layout controls.

### UnifiedAiToggleField

An AI-settings-styled toggle field with a gradient/bordered container, an
optional `icon` chip, a `label`, and an optional `description`. The container
border and icon coloring change based on the current `value`.

## Selection Indicators

`SelectionOption` renders a single built-in indicator, the private
`_DefaultSelectionIndicator` (see `selection_option.dart`): a checkmark
(`Icons.check_rounded`) inside a filled circle when selected, and an empty
outlined circle when not. This is used whenever the optional `selectionIndicator`
parameter is `null`.

To use a different indicator, pass any widget via the `selectionIndicator`
parameter; it is rendered in place of the default.

**Usage:**
```dart
// Default indicator (checkmark / empty circle)
SelectionOption(
  // ... other properties
  // No need to specify selectionIndicator
)

// Custom indicator
SelectionOption(
  // ... other properties
  selectionIndicator: Icon(isSelected ? Icons.star : Icons.star_border),
)
```

## Complete Example

Here's a complete example of creating a selection modal:

```dart
class ColorSelectionModal extends StatefulWidget {
  const ColorSelectionModal({
    required this.selectedColors,
    required this.onSave,
    super.key,
  });

  final List<Color> selectedColors;
  final ValueChanged<List<Color>> onSave;

  static void show({
    required BuildContext context,
    required List<Color> selectedColors,
    required ValueChanged<List<Color>> onSave,
  }) {
    SelectionModalBase.show(
      context: context,
      title: 'Select Colors',
      child: ColorSelectionModal(
        selectedColors: selectedColors,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ColorSelectionModal> createState() => _ColorSelectionModalState();
}

class _ColorSelectionModalState extends State<ColorSelectionModal> {
  late Set<Color> _selectedColors;

  @override
  void initState() {
    super.initState();
    _selectedColors = widget.selectedColors.toSet();
  }

  void _toggleColor(Color color) {
    setState(() {
      if (_selectedColors.contains(color)) {
        _selectedColors.remove(color);
      } else {
        _selectedColors.add(color);
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedColors.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionModalContent(
      children: [
        SelectionOptionsList(
          itemCount: Colors.primaries.length,
          itemBuilder: (context, index) {
            final color = Colors.primaries[index];
            final isSelected = _selectedColors.contains(color);

            return SelectionOption(
              title: _getColorName(color),
              icon: Icons.palette,
              isSelected: isSelected,
              onTap: () => _toggleColor(color),
            );
          },
        ),
        const SizedBox(height: 24),
        SelectionSaveButton(onPressed: _handleSave),
      ],
    );
  }
}
```

## Design Principles

1. **Consistency**: All selection modals use the same visual language and interaction patterns
2. **No Breathing Effects**: Fixed 2px borders prevent size changes on selection
3. **Accessibility**: Proper contrast ratios and touch targets
4. **Performance**: Minimal rebuilds through proper state management
5. **Flexibility**: Components can be composed for different selection types

## Migration Guide

If you're migrating an existing selection modal to use these components:

1. Replace custom modal showing logic with `SelectionModalBase.show()`
2. Replace custom option widgets with `SelectionOption`
3. Replace custom save buttons with `SelectionSaveButton`
4. Wrap your content in `SelectionModalContent`
5. Use `SelectionOptionsList` for consistent spacing
6. Update tests to look for the actual widget structure instead of internal widget names

## Testing

When testing modals using these components:

```dart
// Find options by looking for InkWell containing the text
final optionFinder = find.ancestor(
  of: find.text('Option Text'),
  matching: find.byType(InkWell),
).last;

// Check for selection by looking for checkmark
expect(
  find.descendant(
    of: optionFinder,
    matching: find.byIcon(Icons.check_rounded),
  ),
  findsOneWidget,
);
```

## Contributing

When adding new selection modals:
1. Use these components instead of creating custom implementations
2. If you need additional features, consider extending the base components
3. Maintain the consistent styling and behavior patterns
4. Add appropriate tests