# Lotti Reusable Widgets

This directory contains all reusable widgets used throughout the Lotti application. These widgets are organized by functionality and designed to maintain consistency across the app.

## Table of Contents

- [App Bar Widgets](#app-bar-widgets)
- [Button Widgets](#button-widgets)
- [Card Widgets](#card-widgets)
- [Chart Widgets](#chart-widgets)
- [Create Widgets](#create-widgets)
- [Date/Time Widgets](#datetime-widgets)
- [Event Widgets](#event-widgets)
- [Layout Widgets](#layout-widgets)
- [Miscellaneous Widgets](#miscellaneous-widgets)
- [Modal Widgets](#modal-widgets)
- [Navigation Bar Widgets](#navigation-bar-widgets)
- [Search Widgets](#search-widgets)
- [Selection Widgets](#selection-widgets)
- [Sync/Matrix Widgets](#syncmatrix-widgets)

## App Bar Widgets

Located in `/lib/widgets/app_bar/`

### BackWidget
A customizable back navigation widget for app bars.

### JournalFilter
Filter widget for journal entries with various filtering options.

### JournalFilterIcon
Icon component for the journal filter, providing visual feedback for active filters.

### JournalSliverAppBar
A sliver app bar specifically designed for journal pages with scrolling behavior.

### SliverTitleBar
A generic sliver title bar that can be customized for different screens.

### TitleAppBar
Standard app bar with title text.

### TitleWidgetAppBar
App bar that accepts a custom widget as its title, providing more flexibility than TitleAppBar.

## Button Widgets

Located in `/lib/widgets/buttons/`

### LottiPrimaryButton
Primary action button with Lotti's design system styling. Used for main actions.

### LottiSecondaryButton
Secondary (outlined) button with Lotti's design system styling. Used for secondary actions.

### RoundedButton
Basic rounded button with customizable appearance.

### RoundedFilledButton
Filled rounded button with solid background color.

## Card Widgets

Located in `/lib/widgets/cards/`

### EnhancedModernCard
An enhanced version of ModernBaseCard with additional features like animations and gestures.

### ModalCard
Card specifically designed for use in modal dialogs with appropriate styling.

### ModernBaseCard
Base card component following modern design principles. Extended by other card widgets.

### ModernCardContent
Content wrapper for modern cards, providing consistent padding and layout.

### ModernIconContainer
Container for icons with modern styling, including background and border options.

### ModernStatusChip
Status indicator chip with modern design, used for showing states like active/inactive.

## Chart Widgets

Located in `/lib/widgets/charts/`

### DashboardHabitsChart
Chart component for visualizing habit tracking data on the dashboard.

### DashboardItemModal
Modal dialog for displaying detailed dashboard item information.

### HabitCompletionRateChart
Specialized chart showing habit completion rates over time.

### InfoLabel
Information label component for charts, providing context and explanations.

## Create Widgets

Located in `/lib/widgets/create/`

### MeasurementSuggestions
Widget that provides intelligent suggestions for measurement entries.

### RadialAddTagButtons
Radial menu interface for adding tags, providing an intuitive circular selection UI.

## Date/Time Widgets

Located in `/lib/widgets/date_time/`

### DateTimeBottomSheet
Bottom sheet for selecting date and time values with a user-friendly interface.

### DateTimeField
Form field specifically designed for date and time input with validation.

### DateTimeStickyActionBar
Sticky action bar for date/time related actions, stays visible during scrolling.

### DurationBottomSheet
Bottom sheet for selecting duration values (hours, minutes, seconds).

## Event Widgets

Located in `/lib/widgets/events/`

### EventForm
Comprehensive form for creating and editing events with all necessary fields.

### EventStatusWidget
Widget displaying the current status of an event (upcoming, ongoing, completed).

## Layout Widgets

Located in `/lib/widgets/layouts/`

### SpaceBetweenWrap
A custom layout widget that behaves like a Row with `MainAxisAlignment.spaceBetween` when children fit on one line, but automatically wraps to multiple lines when they don't.

**Usage:**
```dart
SpaceBetweenWrap(
  spacing: 16.0,
  runSpacing: 8.0,
  children: [
    Widget1(),
    Widget2(),
    Widget3(),
  ],
)
```

**Features:**
- Distributes children evenly across available width when they fit
- Automatically wraps to next line when space is insufficient
- Customizable spacing between items and lines
- No pixel overflow errors

### RenderSpaceBetweenWrap
The render object implementation for SpaceBetweenWrap. Not typically used directly.

## Miscellaneous Widgets

Located in `/lib/widgets/misc/`

### DesktopMenuWrapper
Wrapper that adds desktop-specific menu functionality to widgets.

### FlaggedCount
Widget showing the count of flagged items with appropriate styling.

### MapWidget
Interactive map display widget for location-based features.

### TaskCounts
Widget displaying multiple task count statistics.

### TasksCountWidget
Individual task count display component.

### TimeRecordingIndicator
Visual indicator showing whether time recording is currently active.

### TimeSpanSegmentedControl
Segmented control for selecting time spans (day, week, month, year).

## Modal Widgets

Located in `/lib/widgets/modal/`

### AnimatedModalCardItem
Card item with animation support for use in modals.

### AnimatedModalItem
Base class for animated modal items with common animation logic.

### AnimatedModalItemController
Controller for managing animated modal item states and animations.

### AnimatedModalItemWithIcon
Animated modal item that includes an icon with the content.

### ModernModalActionItem
Action item for modals following modern design principles.

### ModernModalEntryTypeItem
Modal item for selecting entry types with modern styling.

### ModernModalPromptItem
Prompt item for modals with modern design aesthetics.

## Navigation Bar Widgets

Located in `/lib/widgets/nav_bar/`

### SpotifyStyleBottomNavigationBar
Bottom navigation bar with Spotify-inspired design and animations.

**Internal Components:**
- **_Bar**: Internal bar component
- **_BottomNavigationTile**: Navigation tile component
- **_Label**: Label component for navigation items
- **_Tile**: Base tile component
- **_TileIcon**: Icon component for tiles

## Search Widgets

Located in `/lib/widgets/search/`

### EntryTypeAllChip
Chip for selecting/deselecting all entry types at once.

### EntryTypeChip
Individual chip for each entry type in the filter.

### EntryTypeFilter
Complete filter component for entry types.

### FilterChoiceChip
Generic choice chip for filter options.

### SearchWidget
Main search widget with text input and search functionality.

## Selection Widgets

Located in `/lib/widgets/selection/`

### RadioSelectionIndicator
Radio button style selection indicator for single-choice options.

### SelectionModalContent
Content wrapper for selection modals with consistent styling.

### SelectionOption
Individual selectable option in a list.

### SelectionOptionsList
List container for multiple selection options.

### SelectionSaveButton
Save button for confirming selections in modals.

### _DefaultSelectionIndicator
Default selection indicator implementation (internal use).

## Sync/Matrix Widgets

Located in `/lib/widgets/sync/matrix/`

### DeviceCard
Card displaying device information for sync settings.

### IncomingVerificationModal
Modal for handling incoming verification requests.

### IncomingVerificationWrapper
Wrapper component for incoming verification flow.

### StatusIndicator
Visual indicator for sync/connection status.

### VerificationEmojisRow
Row displaying verification emojis for secure verification.

### VerificationModal
Complete modal for the verification process.

## Usage Guidelines

1. **Import widgets** using their relative path:
   ```dart
   import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
   ```

2. **Maintain consistency** by using these widgets instead of creating similar ones.

3. **Extend existing widgets** when you need similar functionality with minor changes.

4. **Document new widgets** by adding them to this README when created.

5. **Follow naming conventions**:
   - Use descriptive names that indicate the widget's purpose
   - Prefix with 'Lotti' for app-specific styled widgets
   - Use 'Modern' prefix for widgets following the modern design system

## Contributing

When adding new reusable widgets:

1. Place them in the appropriate subdirectory based on functionality
2. Include comprehensive documentation in the widget file
3. Add unit tests in the corresponding test directory
4. Update this README with the new widget information
5. Consider creating example usage in the widget documentation