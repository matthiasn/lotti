# Modal Components

This directory contains the app's modal-presentation utilities (built on
`wolt_modal_sheet`) plus a small set of animation widgets used for interactive
list/card items. The only public export of the package is `ModalUtils` (via
`index.dart`).

## Contents

```
lib/widgets/modal/
├── index.dart                       # exports modal_utils.dart only
├── modal_utils.dart                 # ModalUtils: Wolt sheet helpers
├── confirmation_modal.dart          # showConfirmationModal(...)
├── modal_action_sheet.dart          # showModalActionSheet(...)
├── modal_sheet_action.dart          # ModalSheetAction<T> (action model)
├── sized_wolt_dialog_type.dart      # SizedWoltDialogType (width-configurable dialog)
├── animated_modal_item.dart         # AnimatedModalItem (hover/tap animation wrapper)
└── animated_modal_item_controller.dart # AnimatedModalItemController (ChangeNotifier)
```

## Modal Presentation API

### ModalUtils

`ModalUtils` (the only export of `index.dart`) wraps `WoltModalSheet` with the
app's styling and responsive behavior. Key static members:

- `modalTypeBuilder(context)` — returns a `bottomSheet` below
  `WoltModalConfig.pageBreakpoint` and a `dialog` at or above it.
- `shouldUseRootNavigatorForBottomSheet(context)` — true below the breakpoint.
- `getModalBarrierColor({isDark, context})` / `getModalBackgroundColor(context)`
  — theme-derived barrier and background colors.
- `modalSheetPage({...})` / `sliverModalSheetPage({...})` — build styled
  `WoltModalSheetPage` / `SliverWoltModalSheetPage` instances with optional
  title, back button (`onTapBack`), and close button (`showCloseButton`).
- `showSinglePageModal<T>({...})` — show a single styled page.
- `showSingleSliverPageModal<T>({...})` — show a single sliver-based page.
- `showMultiPageModal<T>({...})` — show a multi-page modal with an optional
  `pageIndexNotifier`.
- `showBottomSheet<T>({...})` — thin wrapper over `showModalBottomSheet` that
  applies the root-navigator heuristic.

```dart
ModalUtils.showSinglePageModal<void>(
  context: context,
  title: 'Title',
  builder: (context) => const MyModalBody(),
);
```

### showConfirmationModal

`Future<bool> showConfirmationModal({required context, required message, ...})`
in `confirmation_modal.dart` shows a single-page confirmation built on
`ModalUtils.showSinglePageModal`. It renders an optional warning icon (when
`isDestructive`), the message, and a `cancel`/`confirm` pair of
`DesignSystemButton`s — a `secondary` cancel and a `danger` (or `primary`, when
not destructive) confirm — returning `true` only when the confirm button is
tapped.

```dart
final ok = await showConfirmationModal(
  context: context,
  message: 'Delete this entry?',
  confirmLabel: 'DELETE',
  cancelLabel: 'CANCEL',
);
```

### showModalActionSheet / ModalSheetAction

`Future<T?> showModalActionSheet<T>({required context, ...})` in
`modal_action_sheet.dart` shows a bottom sheet of `LottiTertiaryButton` actions
plus an optional title, message, and cancel button. Each action is a
`ModalSheetAction<T>` (`label`, optional `key`, optional `icon`,
`isDestructiveAction`); the sheet pops with the tapped action's `key`.

```dart
final choice = await showModalActionSheet<String>(
  context: context,
  actions: const [
    ModalSheetAction(label: 'Edit', key: 'edit'),
    ModalSheetAction(label: 'Delete', key: 'delete', isDestructiveAction: true),
  ],
  cancelLabel: 'Cancel',
);
```

### SizedWoltDialogType

`SizedWoltDialogType` (`sized_wolt_dialog_type.dart`) subclasses Wolt's
`WoltDialogType` to render the dialog at a configurable `preferredWidth`,
shrinking to fit (less the standard dialog padding) on narrower screens and
capping height at 80% of available height (minimum 360px).

## Animation Widgets

### AnimatedModalItem

`AnimatedModalItem` (`animated_modal_item.dart`) is a `StatefulWidget` wrapper
that adds hover and tap animations to an arbitrary `child`.

```dart
AnimatedModalItem(
  onTap: () => print('Tapped'),
  child: const Text('Click me'),
  // Optional parameters (defaults shown)
  hoverScale: 0.99,        // Scale on hover
  tapScale: 0.98,          // Scale on tap
  tapOpacity: 0.8,         // Opacity on tap
  hoverElevation: 4,       // Shadow elevation added on hover
  isDisabled: false,       // Disable interactions (renders at 0.5 opacity)
  controller: null,        // Optional shared AnimatedModalItemController
  margin: null,            // Defaults to symmetric(horizontal: cardPadding, vertical: cardSpacing / 2)
  disableShadow: false,    // Skip the box shadow entirely
)
```

If no `controller` is supplied, the widget creates and disposes an internal
`AnimatedModalItemController`. Both internal and external controller swaps are
handled in `didUpdateWidget`, and animations are re-initialized when scale,
opacity, elevation, or the controller change.

The only consumer of `AnimatedModalItem` outside this directory is
`AnimatedModernTaskCard`
(`lib/features/journal/ui/widgets/list_cards/animated_task_card.dart`), which
wraps `ModernTaskCard` with `margin: EdgeInsets.zero` and `disableShadow: true`.

### AnimatedModalItemController

`AnimatedModalItemController` (`animated_modal_item_controller.dart`) is a
`ChangeNotifier` that owns the two `AnimationController`s used by
`AnimatedModalItem`. It exists primarily so the animation state is observable in
tests, and can be shared so multiple widgets animate in sync.

```dart
final controller = AnimatedModalItemController(vsync: this);

AnimatedModalItem(
  controller: controller,
  onTap: () => print('Tapped'),
  child: const Text('Controlled item'),
);

// Drive / read animation state
controller.startHover();                          // forward hover
controller.startTap();                            // forward tap
controller.hoverAnimationController.value;         // 0.0 to 1.0
controller.tapAnimationController.value;           // 0.0 to 1.0
```

Constructor durations default to `hoverDuration: 200ms` and `tapDuration: 150ms`.
`AnimatedModalItem` is a plain field holder of `controller`; the controller is a
standalone `ChangeNotifier`, not a subclass of `AnimatedModalItem`.

## Animation Details

These describe `AnimatedModalItem` (`animated_modal_item.dart`).

### Hover Animations
- Scale: `1.0 → hoverScale` (default 0.99)
- Elevation: shadow blur grows by `hoverElevation` (default 4)
- Duration: 200ms (controller `hoverDuration`)
- Curve: `Curves.easeOutCubic`

### Tap Animations
- Scale: `1.0 → tapScale` (default 0.98)
- Opacity: `1.0 → tapOpacity` (default 0.8)
- Duration: 150ms (controller `tapDuration`; the build's `AnimatedOpacity` also
  uses 150ms)
- Curve: `Curves.easeOutCubic`

### Disabled State
- Opacity: 0.5
- Hover/tap callbacks are gated on `!isDisabled`
- `onTap` is set to `null`

## Styling Constants

`AnimatedModalItem` pulls its layout values from `AppTheme`
(`lib/themes/theme.dart`):

```dart
AppTheme.cardPadding          // 16 (default horizontal margin)
AppTheme.cardSpacing          // 10 (default vertical margin = cardSpacing / 2)
AppTheme.cardBorderRadius     // 16
```

Related constants available in `AppTheme` (not all used by this widget):

```dart
AppTheme.cardPaddingCompact   // 14
AppTheme.iconContainerSize    // 44
AppTheme.iconContainerSizeCompact // 40
AppTheme.iconSize             // 22
AppTheme.spacingSmall         // 8
AppTheme.spacingMedium        // 12
AppTheme.spacingLarge         // 16
AppTheme.titleFontSize        // 18
AppTheme.subtitleFontSize     // 13
AppTheme.letterSpacingTitle   // 0.15
```

## Examples

### Custom animated item

```dart
AnimatedModalItem(
  onTap: () => navigateToDetails(),
  hoverScale: 0.995,
  tapScale: 0.99,
  child: Container(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: const [
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

## Testing

Tests live in `test/widgets/modal/`:

- `animated_modal_item_test.dart` — `AnimatedModalItem` animation/behavior
- `animated_modal_item_controller_test.dart` — controller state and disposal
- `confirmation_modal_test.dart` — `showConfirmationModal`
- `modal_action_sheet_test.dart` — `showModalActionSheet` / `ModalSheetAction`
- `modal_utils_test.dart` — `ModalUtils` helpers

Run them with:

```bash
fvm flutter test test/widgets/modal/
```
