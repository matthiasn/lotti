import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the saved-filters sheet's bar and pin toggles.
@visibleForTesting
abstract final class SavedTaskFiltersSheetBarKeys {
  static const Key bar = Key('saved-filters-sheet-bar');
  static const Key pinnedOnly = Key('saved-filters-sheet-pinned-only');
  static Key pin(String id) => Key('saved-filters-sheet-pin-$id');
}

/// The saved-filters sheet's sticky bar: the pinned-only switch on the
/// leading edge and Edit / Done on the trailing one.
///
/// Docked to the top of the list on the app's standard glass
/// ([DesignSystemGlassStrip]), so the rows scroll under it blurred while
/// both controls stay in reach — the switch changes what the list holds and
/// Edit changes what its rows do, so neither belongs at the end of a list
/// the user may have scrolled away from.
class SavedTaskFiltersSheetBar extends StatelessWidget {
  const SavedTaskFiltersSheetBar({
    required this.pinnedOnly,
    required this.onPinnedOnlyChanged,
    required this.editing,
    required this.onEditToggled,
    required this.editToggleKey,
    super.key,
  });

  final bool pinnedOnly;
  final ValueChanged<bool> onPinnedOnlyChanged;
  final bool editing;
  final VoidCallback onEditToggled;

  /// Key for the Edit / Done button, owned by the sheet's key set.
  final Key editToggleKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;

    return DesignSystemGlassStrip(
      key: SavedTaskFiltersSheetBarKeys.bar,
      dock: DesignSystemGlassStripDock.top,
      child: Padding(
        // The sheet's page gutter plus its rows' own inset, so the switch
        // starts on the rows' radio column. The trailing side keeps the
        // gutter alone: the button's own padding is its inset.
        padding: EdgeInsetsDirectional.only(
          start: tokens.spacing.step5 + tokens.spacing.step3,
          end: tokens.spacing.step5,
        ),
        child: Row(
          children: [
            Flexible(
              // The switch itself is a compact pill; the whole leading cell
              // flips it, so the touch target is the bar's full height and
              // the label's width rather than the pill alone.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () => onPinnedOnlyChanged(!pinnedOnly),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minTarget),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DesignSystemToggle(
                      key: SavedTaskFiltersSheetBarKeys.pinnedOnly,
                      value: pinnedOnly,
                      onChanged: onPinnedOnlyChanged,
                      label: messages.tasksSavedFiltersPinnedOnly,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            DesignSystemButton(
              key: editToggleKey,
              label: editing
                  ? messages.tasksSavedFiltersDone
                  : messages.tasksSavedFiltersEdit,
              variant: DesignSystemButtonVariant.tertiary,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: onEditToggled,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pin / unpin toggle for one saved filter, sized to a full touch target.
///
/// Pinned reads as the filled glyph in the interactive accent, unpinned as
/// the outline in medium emphasis — shape and colour both carry the state,
/// so it holds in greyscale and for colour-blind users. The glyphs swap
/// through a quick scale-and-fade, so the tap is answered where the finger
/// is even when the row is about to leave a pinned-only list.
class SavedTaskFilterPinToggle extends StatelessWidget {
  const SavedTaskFilterPinToggle({
    required this.filterId,
    required this.filterName,
    required this.pinned,
    required this.onToggle,
    super.key,
  });

  final String filterId;
  final String filterName;
  final bool pinned;
  final VoidCallback onToggle;

  /// Duration of the glyph swap.
  static const swapDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final label = pinned
        ? messages.tasksSavedFiltersUnpinNamed(filterName)
        : messages.tasksSavedFiltersPinNamed(filterName);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: pinned,
        label: label,
        onTap: onToggle,
        child: ExcludeSemantics(
          // Its own transparent material, so the hover and splash ink draw
          // on the pin itself rather than on whatever surface hosts the row.
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              key: SavedTaskFiltersSheetBarKeys.pin(filterId),
              onTap: onToggle,
              radius: minTarget / 2,
              hoverColor: tokens.colors.surface.hover,
              focusColor: tokens.colors.surface.focusPressed,
              highlightColor: tokens.colors.surface.focusPressed,
              child: SizedBox.square(
                dimension: minTarget,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: swapDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      pinned ? LottiIconsFilled.pin : LottiIcons.pin,
                      key: ValueKey(pinned),
                      size: tokens.spacing.step5,
                      color: pinned
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
