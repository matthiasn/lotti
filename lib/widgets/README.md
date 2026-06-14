# Lotti Reusable Widgets

This directory contains reusable widgets used throughout the Lotti application. These widgets are organized by functionality and designed to maintain consistency across the app.

## Table of Contents

- [App Bar Widgets](#app-bar-widgets)
- [Button Widgets](#button-widgets)
- [Card Widgets](#card-widgets)
- [Chart Widgets](#chart-widgets)
- [Create Widgets](#create-widgets)
- [Date/Time Widgets](#datetime-widgets)
- [Event Widgets](#event-widgets)
- [Flag Widgets](#flag-widgets)
- [Form Widgets](#form-widgets)
- [Miscellaneous Widgets](#miscellaneous-widgets)
- [Modal Widgets](#modal-widgets)
- [Navigation Bar Widgets](#navigation-bar-widgets)
- [Search Widgets](#search-widgets)
- [Selection Widgets](#selection-widgets)
- [Settings Widgets](#settings-widgets)
- [UI Widgets](#ui-widgets)

## App Bar Widgets

Located in `/lib/widgets/app_bar/`

### BackWidget
A customizable back navigation widget for app bars.

### GlassActionButton
Glass-styled action button for use over images. Combines `GlassIconContainer` with `Material`/`InkWell` for tap feedback; takes any child (typically an `Icon`) and an `onTap` callback.

### GlassBackButton
Glass-styled back button for use over images. Wraps `GlassActionButton` with a chevron icon; defaults to `Navigator.maybePop` but accepts a custom `onPressed`.

### GlassIconContainer
Container with a dark, blurred glass background for overlay icons, keeping them visible over images of varying brightness.

### JournalFilter
Filter widget for journal entries with various filtering options.

### JournalFilterIcon
Icon component for the journal filter, providing visual feedback for active filters.

### JournalSliverAppBar
A sliver app bar specifically designed for journal pages with scrolling behavior.

### SettingsPageHeader
Sliver settings header that adapts to phone, tablet, and desktop layouts. Measures the actual pane width via `SliverLayoutBuilder` (correct on desktop split-pane layouts) and supports a title, optional subtitle, back button, bottom widget, and actions. Used across settings, sync, AI, categories, and other feature pages.

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

### LottiTertiaryButton
Tertiary (text) button with Lotti's design system styling. Used for text-only buttons with minimal styling, typically for secondary actions or links.

## Card Widgets

Located in `/lib/widgets/cards/`

### EnhancedModernCard
A thin wrapper around `ModernBaseCard` that applies the enhanced styling: it defaults the gradient to `GradientThemes.primaryGradient` and passes `isEnhanced: true`, forwarding `onTap` to the base card.

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
Dashboard host for a habit's completion strip. Delegates to `HabitCompletionCard`, passing `showLinkedDashboard: false` so that tapping a row inside a dashboard does not re-embed that same dashboard in the completion dialog.

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

## Date/Time Widgets

Located in `/lib/widgets/date_time/`

Note: Timer and date labels across the app use tabular figures to prevent width “breathing” as digits change. For time strings rendered as `HH:MM` or `HH:MM:SS`, prefer `tabularFigureStyle` from `lib/themes/theme.dart` (keeps the regular UI font and stabilises digits via `numericBadgeFontFeatures`), or apply `numericBadgeFontFeatures` directly. `monoTabularStyle` is reserved for code-style surfaces (JSON payloads, log readouts), not UI time labels.

### DateTimeBottomSheet
Bottom sheet for selecting date and time values with a user-friendly interface.

### DateTimeField
Form field specifically designed for date and time input with validation.

### DateTimeStickyActionBar
Sticky action bar for date/time related actions, stays visible during scrolling.

## Event Widgets

Located in `/lib/widgets/events/`

### EventForm
Comprehensive form for creating and editing events with all necessary fields.

### EventStatusWidget
Chip displaying the current status of an event. Renders the `EventStatus` enum value (`tentative`, `planned`, `ongoing`, `completed`, `cancelled`, `postponed`, `rescheduled`, `missed`) as a colored label.

## Flag Widgets

Located in `/lib/widgets/flags/`

### buildLanguageFlag
Utility function that renders a language flag with consistent country-code overrides for languages whose flag differs from a direct ISO mapping.

## Form Widgets

Located in `/lib/widgets/form/`

### LottiFormSection
Section header with optional icon and description for grouping related form fields.

### LottiTextField
Single-line text input following the Lotti design system (labels, hints, prefixes, validation).

### LottiTextArea
Specialized multiline variant of `LottiTextField` for longer text input.

## Miscellaneous Widgets

Located in `/lib/widgets/misc/`

### DesktopMenuWrapper
Wrapper that adds desktop-specific menu functionality to widgets.

### FlaggedCount
Widget showing the count of flagged items with appropriate styling.

### MapWidget
Interactive map display widget for location-based features.

### RoundedButton
Thin wrapper around `LottiSecondaryButton` exposing a label-plus-`onPressed` API.

### ZoomWrapper
Applies a `TextScaler` to its subtree based on a `scale` value (returns the child unchanged when `scale` is 1.0).

### TaskCounts
Widget displaying multiple task count statistics.

### TasksCountWidget
Individual task count display component.

### SidebarTimerSection
Inline panel surfaced in the desktop sidebar's `aboveSettings` slot whenever a time-recording session is active. Replaces the legacy bottom-anchored floating indicator on desktop.

- Layout: a text-only title row (task title) over a body row with a timer icon, the tabular HH:MM:SS duration, and a circular stop button.
- Typography: Inter with `numericBadgeFontFeatures` (tabular figures, slashed zero, `cv02`/`cv03`/`cv04` open digits) so 4/6/9 stay legible at small sizes and digits do not breathe.
- Interactions: tapping the body navigates to the running task (or the timer's journal entry, if not task-linked); tapping the stop button calls `TimeService.stop()`.
- Visibility: shown for the entire lifetime of a running timer, driven solely by `TimeService.getStream()`. It is intentionally not hidden when the running task is open in the details pane (the action bar's running pill and this card may both show at once) and persists across tab navigation. See "Sidebar timer coordination" in `lib/features/tasks/README.md`.
- Idle state: collapses to `SizedBox.shrink` so the slot consumes no vertical space.

### SidebarAudioRecordingSection
Inline panel surfaced in the desktop sidebar's `aboveSettings` slot whenever an audio recording is active and the recording modal is not visible. It sits above `SidebarTimerSection` and uses the same card radius, padding rhythm, elapsed-time typography, and circular stop affordance.

- Layout: linked task/title fallback over a body row with an emphasized,
  dBFS-reactive `AudioRecordingOrb`, tabular HH:MM:SS, and a circular stop
  button.
- Signal: reads `AudioRecorderState.dBFS`, which is fed by the `record` package amplitude stream for standard recording and by realtime PCM amplitude calculation for realtime recording. The same speech-weighted signal value drives the orb and the card frame's red border/shadow intensity.
- Interactions: tapping the body reopens `AudioRecordingModal`; tapping the stop button calls `AudioRecorderController.stop()` or `stopRealtime()` based on the active recording mode.
- Idle state: collapses to `SizedBox.shrink` so the slot consumes no vertical space.

### TimeRecordingIndicator
Visual indicator showing whether time recording is currently active. Used on **mobile** only — it sits in the bottom-nav overlay above the navigation bar. On desktop the running timer is rendered by `SidebarTimerSection` instead.

- Typography: Uses `tabularFigureStyle` with tabular figures to ensure the duration text does not jitter as digits change.
- Dimensions: Matches its height (`AudioRecordingIndicatorConstants.indicatorHeight`) with the audio recording indicator to keep overlays consistent.
- Sizing: Font size aligns with `fontSizeMedium`.

### TimeSpanSegmentedControl
Segmented control for selecting a time span in days. The default segments are `[30, 90, 180, 365]`, rendered with labels like `30 days` (or `30d` on narrow widths).

## Modal Widgets

Located in `/lib/widgets/modal/`

### AnimatedModalItem
Stateful modal item that applies press/hover animation logic to its child.

### AnimatedModalItemController
`ChangeNotifier` controller for managing animated modal item state and animations.

### ModalSheetAction
Generic (`ModalSheetAction<T>`) data class describing an action presented in a modal action sheet.

### ModalUtils
Helper utilities for presenting modal sheets/dialogs.

### showConfirmationModal
Function presenting a single-page confirmation modal with a customizable message, optional title, confirm/cancel labels, and a destructive flag. Returns a `Future<bool>` resolving to the user's choice.

### showModalActionSheet
Generic function (`showModalActionSheet<T>`) presenting a bottom-sheet action list built from `ModalSheetAction<T>` entries. Returns the value of the selected action (`Future<T?>`).

### SizedWoltDialogType
Custom `WoltDialogType` that renders at a configurable target width (`preferredWidth`, shrinking to fit less the standard padding on narrower screens) with a screen-proportional max height (80% of available height, floored at 360).

## Navigation Bar Widgets

Located in `/lib/widgets/nav_bar/`

### DesignSystemBottomNavigationBar
Mobile bottom-navigation shell that hosts the design-system bar
(`DesignSystemFiveSlotNavBar`), docked flush against the screen's bottom
edge with zero gap. The bar fills with as many destinations as fit
comfortably at the current window width and text scale (measured via
`DesignSystemFiveSlotNavBar.comfortableSlotWidth` against
`availableRowWidth`): the base line-up is Tasks, DailyOS (when its flag is
enabled — it never overflows), and Logbook plus a More slot; as space
grows, overflow destinations are promoted out of the More sheet in nav
order, each landing in its canonical position with More pinned last, and
once everything fits the More slot disappears entirely. The bottom
safe-area inset is absorbed into the bar surface itself. The time/audio
recording indicators that ride above the bar are owned by the mobile shell
(`lib/beamer/beamer_app.dart`), not by this container, so they stay
visible when the shell hides the bar.

Visibility is owned by the same shell as a pure function of router state:
on task detail routes (`/tasks/<uuid>`) the bar is unmounted so the
page-owned `TaskActionBar` can dock flush against the home indicator, and
inside settings entity-definition editors (the categories / habits /
labels / dashboards / measurables detail and create pages plus per-project
editors — not the list pages, see `isSettingsEntityDefinitionRoute`) it
slides below the screen edge with an animated, pointer- and semantics-inert
transition instead of popping out, and slides back in on leaving. While
the bar is slid away the recording indicators animate down to the bottom
safe-area edge in the same motion.

### showMobileNavMoreSheet / MobileNavMoreSheetItem
`WoltModalSheet`-based overflow sheet listing the destinations without a
bar slot: Settings, plus the flag-gated Projects, Habits, and Insights —
newly toggled pages surface here, and rows disappear from the sheet as the
window grows wide enough to promote them into the bar. Each row offers an
optional trailing slot (mirroring the desktop sidebar rows) — Settings
renders its outbox count pill there instead of badging the gear icon.
Selecting a row dismisses the sheet and navigates; the bar's More slot
then renders that destination's name with the active tint.

### DesignSystemBottomNavigationFabPadding
Padding helper that lifts floating action buttons clear of the shared bottom
navigation shell (`DesignSystemBottomNavigationBar.occupiedHeight`). The
occupied height covers the bar plus the recording-indicator row riding above
it — the shell publishes the row's rendered height to the page stack via the
`DesignSystemBottomNavigationOverlayHeight` inherited widget, so padded
content reflows when an indicator appears or disappears.

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

### LottiSearchBar
Main search widget with text input and search functionality.

## Selection Widgets

Located in `/lib/widgets/selection/`

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

### UnifiedToggle
Unified toggle/switch component providing a single source of truth for selection behavior across the app. Supports `UnifiedToggleVariant` (`normal`, `warning`, `priority`, `archived`, `cupertino`), an optional custom active color, semantic labels, and an enabled/disabled state.

### UnifiedToggleField
`UnifiedToggle` with an integrated title/subtitle label for form-like contexts, matching the styling of existing form switch implementations.

### UnifiedAiToggleField
AI-specific toggle field matching the AI Settings design language (gradient container, label, optional description and icon).

## Settings Widgets

Located in `/lib/widgets/settings/` — the shared shell for the settings definition pages (categories, labels, habits, measurables, dashboards) so list and detail surfaces share one silhouette. See `lib/features/settings/README.md` for the page-level architecture.

### SettingsPageLayout / SettingsContentSliver / SettingsContentArea
Responsive content grid for settings pages. `SettingsPageLayout.contentInsets(width)` anchors content to the same responsive start inset as `SettingsPageHeader`'s title and caps content width at `maxContentWidth` (840) on wide panes. `SettingsContentSliver` applies the grid to slivers, `SettingsContentArea` to box widgets (used by the action bar so buttons align with the form's edges).

### SettingsDetailScaffold
Unified detail-page shell: `SettingsPageHeader` with back affordance (callers beam to their list route so the desktop split pane stays in sync), aligned scrollable content (`children` or raw `slivers`), Cmd/Ctrl+S save shortcut, and a sticky glass action bar mounted with `extendBody: true` so the form scrolls visibly behind the blur.

### SettingsFormActionBar
Sticky bottom action bar on `DesignSystemGlassStrip` (hairline + backdrop blur + scrim gradient). Destructive action (icon-only round glass button) at the start, secondary + primary `DsGlassPill`s at the end of the content grid. At accessibility text scales ≥ 1.5 the actions stack vertically with the primary pill closest to the thumb.

### SettingsFormSection
Token-driven section header (quiet medium-emphasis title, optional description) above a grouped card matching `DesignSystemGroupedList`'s surface (background level02, decorative hairline, radii.m). Spaces its children with `cardItemSpacing` — no manual separators needed.

### SettingsSwitchRow
Toggle row (title, optional subtitle/icon, `DesignSystemToggle`) used inside form sections; the whole row is tappable. Also wrapped by `FormSwitch` for `flutter_form_builder` forms.

## UI Widgets

Located in `/lib/widgets/ui/`

### EmptyStateWidget
Reusable empty-state display with icon, title, and description.

### ErrorStateWidget
Reusable error-state display supporting a full decorated container or a compact inline error bar.

### FormBottomBar
Standard bottom bar for forms with shadow, spacing, and left (typically destructive) and right (action) buttons.

### LottiAnimatedCheckbox
Animated checkbox with label, optional subtitle, proper touch targets, and disabled-state support.

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
