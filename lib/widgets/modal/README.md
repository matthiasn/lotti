# Modal Components

This directory contains reusable modal components that provide consistent animations and visual feedback across the application. These components follow a layered architecture to maximize code reuse and maintainability.

## Architecture

```
AnimatedModalItem (base animation layer)
    └── AnimatedModalItemWithIcon (adds icon animation support)
            └── ModernModalEntryTypeItem (entry creation specific)
    └── AnimatedModalItemController (shared animation controller)

Independent Components:
- ModernModalPromptItem (selection prompts)
- ModernModalActionItem (actions with optional destructive styling)
```

## Core Components

### AnimatedModalItem

The foundation component that provides hover and tap animations for any modal item.

```dart
AnimatedModalItem(
  onTap: () => print('Tapped'),
  child: Text('Click me'),
  // Optional parameters
  hoverScale: 0.99,        // Scale on hover (default: 0.99)
  tapScale: 0.98,          // Scale on tap (default: 0.98)
  tapOpacity: 0.8,         // Opacity on tap (default: 0.8)
  hoverElevation: 4,       // Shadow elevation on hover (default: 4)
  isDisabled: false,       // Disable interactions
  margin: EdgeInsets.all(8), // Custom margin
  disableShadow: false,    // Disable shadow rendering
)
```

**Features:**
- Smooth hover animations on desktop
- Tap animations with scale and opacity
- Automatic shadow elevation changes
- Disabled state support
- Customizable animation parameters

### AnimatedModalItemWithIcon

Extends AnimatedModalItem to add icon-specific animations. Uses composition to reuse all base animations.

```dart
AnimatedModalItemWithIcon(
  onTap: () => print('Tapped'),
  iconBuilder: (context, iconAnimation, {required bool isPressed}) {
    return Icon(
      Icons.add,
      color: isPressed ? Colors.blue : Colors.grey,
    );
  },
  child: Text('Item with animated icon'),
  iconScaleOnTap: 0.9,     // Icon scale animation (default: 0.9)
)
```

**Features:**
- All AnimatedModalItem features
- Additional icon scale animation on tap
- Icon builder provides animation value and pressed state
- Automatic synchronization with base animations

### AnimatedModalItemController

Manages animation controllers for modal items. Can be shared between parent and child components for synchronized animations.

```dart
final controller = AnimatedModalItemController(vsync: this);

AnimatedModalItem(
  controller: controller,
  onTap: () => print('Tapped'),
  child: Text('Controlled item'),
)

// Access animation values
controller.hoverAnimationController.value  // 0.0 to 1.0
controller.tapAnimationController.value    // 0.0 to 1.0
```

## Specialized Components

### ModernModalEntryTypeItem

Used in the entry creation modal for selecting entry types (Event, Task, Audio, etc.).

```dart
ModernModalEntryTypeItem(
  icon: Icons.event_rounded,
  title: 'Event',
  onTap: () => createEvent(),
  iconColor: Colors.blue,    // Optional custom color
  isDisabled: false,
  badge: BadgeWidget(),      // Optional badge
)
```

**Features:**
- Consistent entry type selection UI
- Icon with gradient background
- Add icon indicator
- Badge support
- Uses AnimatedModalItemWithIcon for animations

### ModernModalPromptItem

Used for selection prompts where users choose from options.

```dart
ModernModalPromptItem(
  icon: Icons.public,
  title: 'Public',
  description: 'Anyone can see this',
  onTap: () => selectOption(),
  isSelected: true,          // Shows selected state
  badge: CountBadge(5),      // Optional badge
)
```

**Features:**
- Title and description layout
- Selected state with background color
- Direct AnimatedModalItem usage
- Badge support

### ModernModalActionItem

Used for action items in modal menus, supports destructive actions.

```dart
ModernModalActionItem(
  icon: Icons.delete_outline,
  title: 'Delete',
  subtitle: 'This cannot be undone',  // Optional
  onTap: () => deleteItem(),
  isDestructive: true,      // Red styling
  trailing: Icon(Icons.chevron_right), // Optional
)
```

**Features:**
- Destructive action styling
- Optional subtitle
- Trailing widget support
- Direct AnimatedModalItem usage

## Animation Details

### Hover Animations (Desktop)
- Scale: 1.0 → 0.99 (subtle shrink)
- Elevation: 0 → 4 (shadow appears)
- Duration: 200ms
- Curve: easeOutCubic

### Tap Animations
- Scale: 1.0 → 0.98 (or custom)
- Opacity: 1.0 → 0.8 (or custom)
- Icon Scale: 1.0 → 0.9 (if using AnimatedModalItemWithIcon)
- Duration: 100ms
- Curve: easeOutCubic (easeOutBack for icons)

### Disabled State
- Opacity: 0.5
- No animations trigger
- Tap callbacks disabled

## Styling Constants

All components use consistent styling from `AppTheme`:

```dart
// Spacing
AppTheme.cardPadding          // 14px
AppTheme.cardSpacing          // Vertical spacing between cards
AppTheme.spacingSmall         // 8px
AppTheme.spacingMedium        // 12px
AppTheme.spacingLarge         // 16px

// Sizing
AppTheme.iconContainerSize    // 40px
AppTheme.iconSize             // Icon inside container
AppTheme.cardBorderRadius     // 16px

// Typography
AppTheme.titleFontSize        // Title text size
AppTheme.subtitleFontSize     // Subtitle text size
AppTheme.letterSpacingTitle   // Letter spacing
```

## Best Practices

1. **Use the appropriate component for your use case:**
   - Entry creation → ModernModalEntryTypeItem
   - Option selection → ModernModalPromptItem
   - Actions → ModernModalActionItem
   - Custom → AnimatedModalItem or AnimatedModalItemWithIcon

2. **Maintain consistent animations:**
   - Use default animation values unless specific needs
   - Keep hover and tap scales subtle (0.97-0.99)
   - Don't make animations too fast or slow

3. **Accessibility:**
   - Always provide meaningful tap handlers
   - Use isDisabled for non-interactive states
   - Ensure sufficient contrast for text and icons

4. **Performance:**
   - Animation controllers are properly disposed
   - Use const constructors where possible
   - Avoid rebuilding during animations

## Examples

### Custom Modal Item

```dart
AnimatedModalItem(
  onTap: () => navigateToDetails(),
  hoverScale: 0.995,
  tapScale: 0.99,
  child: Container(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(Icons.folder),
        SizedBox(width: 12),
        Text('My Custom Item'),
        Spacer(),
        Icon(Icons.arrow_forward_ios, size: 16),
      ],
    ),
  ),
)
```

### Entry Type with Custom Badge

```dart
ModernModalEntryTypeItem(
  icon: Icons.task_alt_rounded,
  title: 'Task',
  onTap: () => createTask(),
  badge: Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'NEW',
      style: TextStyle(fontSize: 10, color: Colors.white),
    ),
  ),
)
```

## Testing

All modal components have comprehensive test coverage:

- `animated_modal_item_test.dart` - Base animation tests
- `animated_modal_item_with_icon_test.dart` - Icon animation tests
- `modern_modal_entry_type_item_test.dart` - Entry type item tests
- `modern_modal_prompt_item_test.dart` - Prompt item tests
- `modern_modal_action_item_test.dart` - Action item tests
- `modal_items_animation_integration_test.dart` - Integration tests
- `animated_modal_item_resource_leak_test.dart` - Resource management tests

Run tests with:
```bash
flutter test test/widgets/modal/
```