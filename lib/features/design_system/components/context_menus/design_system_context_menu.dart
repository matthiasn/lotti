import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

const _kMenuWidth = 320.0;
const _kMaxVisibleItems = 6;

@visibleForTesting
const kSmallItemHeight = 36.0;

/// One row in a [DesignSystemContextMenu].
///
/// Carries the [label], an optional leading [icon], a tap [onTap] callback, and
/// an [isDestructive] flag that renders the row in the danger tone.
class DesignSystemContextMenuItem {
  const DesignSystemContextMenuItem({
    required this.label,
    this.key,
    this.icon,
    this.iconColor,
    this.onTap,
    this.isDestructive = false,
    this.isSelected = false,
    this.checked,
    this.startsGroup = false,
  });

  final String label;
  final Key? key;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isSelected;

  /// A setting the row switches in place: non-null makes the row a toggle,
  /// drawn with a checkbox glyph in the icon slot and announced as checked
  /// or not. Null for an ordinary action.
  final bool? checked;

  /// Draws a hairline above the row, opening a new group — a page's own
  /// actions apart from its agent's, delete apart from the rest. Ignored on
  /// the first row.
  final bool startsGroup;
}

enum DesignSystemContextMenuSize {
  small,
  medium,
}

/// The design-system's context/popover menu — a token-styled card listing
/// tappable [DesignSystemContextMenuItem]s.
///
/// Sized by [DesignSystemContextMenuSize] (small/medium row height) and [width]
/// (default 320px); once items exceed the visible cap the body scrolls within a
/// bounded height. [semanticsLabel] labels the menu container.
class DesignSystemContextMenu extends StatelessWidget {
  const DesignSystemContextMenu({
    required this.items,
    this.size = DesignSystemContextMenuSize.medium,
    this.width = _kMenuWidth,
    this.semanticsLabel,
    this.header,
    this.headerKey,
    this.fitContent = false,
    this.surfaceColor,
    super.key,
  });

  /// The width every menu surface takes unless a caller asks otherwise;
  /// shared with `DesignSystemPopoverAnchor` so popovers and menus line up.
  static const double defaultWidth = _kMenuWidth;

  final List<DesignSystemContextMenuItem> items;
  final DesignSystemContextMenuSize size;
  final double width;
  final String? semanticsLabel;

  /// Optional quiet heading rendered above the action rows.
  final String? header;

  /// Optional identity for the header row, used by anchored menus whose
  /// heading names the concrete object or date being acted on.
  final Key? headerKey;

  /// Sizes the menu to its widest row instead of [width], which then only
  /// caps it — for a short menu whose labels leave most of a fixed width
  /// empty. Ignored once the rows scroll, where a lazy list has no
  /// intrinsic width to measure.
  final bool fitContent;

  /// The menu's surface, for a host that opens it over a dimmed page and
  /// needs it raised off that page; the base level otherwise.
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ContextMenuSpec.fromTokens(tokens, size);
    final needsScroll = items.length > _kMaxVisibleItems;
    final headerHeight = header == null ? 0.0 : spec.headerHeight;
    final maxHeight = needsScroll
        ? spec.itemHeight * _kMaxVisibleItems + headerHeight
        : null;

    final itemList = needsScroll
        ? SizedBox(
            height: spec.itemHeight * _kMaxVisibleItems,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (items[index].startsGroup && index > 0)
                    _groupRule(tokens, spec),
                  _buildItem(tokens, spec, items[index]),
                ],
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, item) in items.indexed) ...[
                if (item.startsGroup && index > 0) _groupRule(tokens, spec),
                _buildItem(tokens, spec, item),
              ],
            ],
          );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: fitContent && !needsScroll ? null : width,
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight)
              : fitContent
              ? BoxConstraints(maxWidth: width)
              : const BoxConstraints(),
          decoration: BoxDecoration(
            color: surfaceColor ?? tokens.colors.background.level01,
            borderRadius: BorderRadius.circular(spec.borderRadius),
            boxShadow: DsShadows.floatingSurface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(spec.borderRadius),
            // The inner Material puts hover/splash ink above the opaque card
            // decoration. The clip then makes an edge-to-edge last row follow
            // the bottom corners instead of stopping short of the border.
            child: Material(
              color: Colors.transparent,
              child: _FitWidth(
                enabled: fitContent && !needsScroll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (header case final header?)
                      Container(
                        key: headerKey,
                        height: spec.headerHeight,
                        alignment: AlignmentDirectional.centerStart,
                        padding: EdgeInsets.symmetric(
                          horizontal: spec.horizontalPadding,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tokens.colors.decorative.level01,
                              width: spec.dividerWidth,
                            ),
                          ),
                        ),
                        child: Text(
                          header,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                    // No inset: the first and last rows' fills meet — and are
                    // clipped by — the rounded outline.
                    itemList,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The rows' fills meet the rule, as they meet the outline.
  Widget _groupRule(DsTokens tokens, _ContextMenuSpec spec) => Divider(
    height: spec.dividerWidth,
    thickness: spec.dividerWidth,
    color: tokens.colors.decorative.level01,
  );

  Widget _buildItem(
    DsTokens tokens,
    _ContextMenuSpec spec,
    DesignSystemContextMenuItem item,
  ) {
    // Ink, not the default red: this paints the item's label, and the default
    // step only clears AA against the light surfaces — on a dark menu it
    // measures 4.25:1.
    final textColor = item.isDestructive
        ? tokens.colors.alert.error.ink
        : tokens.colors.text.highEmphasis;

    return Semantics(
      key: item.key,
      button: true,
      enabled: item.onTap != null,
      selected: item.isSelected ? true : null,
      checked: item.checked,
      label: item.label,
      onTap: item.onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: item.onTap,
          // The pickable-row ladder in the primary hue, flat — no splash.
          hoverColor: DesignSystemListPalette.hoverFill(tokens),
          highlightColor: DesignSystemListPalette.pressedFill(tokens),
          // Focus has no outline here, so it takes the stronger focus fill
          // selection rows use rather than the faint hover tint.
          focusColor: tokens.colors.surface.focusPressed,
          splashFactory: NoSplash.splashFactory,
          child: Ink(
            color: item.isSelected
                ? tokens.colors.surface.selected
                : Colors.transparent,
            child: SizedBox(
              height: spec.itemHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spec.horizontalPadding,
                ),
                child: Row(
                  children: [
                    if (item.icon != null || item.checked != null) ...[
                      Icon(
                        switch (item.checked) {
                          true => LottiIcons.checkboxChecked,
                          false => LottiIcons.checkboxUnchecked,
                          null => item.icon,
                        },
                        size: spec.iconSize,
                        color: item.iconColor ?? textColor,
                      ),
                      SizedBox(width: spec.iconGap),
                    ],
                    Expanded(
                      child: Text(
                        item.label,
                        style: spec.textStyle.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuSpec {
  const _ContextMenuSpec({
    required this.borderRadius,
    required this.horizontalPadding,
    required this.headerHeight,
    required this.dividerWidth,
    required this.itemHeight,
    required this.iconSize,
    required this.iconGap,
    required this.textStyle,
  });

  factory _ContextMenuSpec.fromTokens(
    DsTokens tokens,
    DesignSystemContextMenuSize size,
  ) {
    final isSmall = size == DesignSystemContextMenuSize.small;

    return _ContextMenuSpec(
      borderRadius: tokens.radii.s,
      horizontalPadding: tokens.spacing.step5,
      headerHeight: tokens.spacing.step8,
      dividerWidth: BorderWidths.hairline,
      itemHeight: isSmall ? kSmallItemHeight : tokens.spacing.step9,
      iconSize: isSmall
          ? tokens.typography.lineHeight.subtitle2
          : tokens.spacing.step6,
      iconGap: tokens.spacing.step3,
      textStyle: isSmall
          ? tokens.typography.styles.body.bodySmall
          : tokens.typography.styles.body.bodyMedium,
    );
  }

  final double borderRadius;
  final double horizontalPadding;
  final double headerHeight;
  final double dividerWidth;
  final double itemHeight;
  final double iconSize;
  final double iconGap;
  final TextStyle textStyle;
}

/// [IntrinsicWidth] around a fitted menu's rows, a pass-through otherwise.
class _FitWidth extends StatelessWidget {
  const _FitWidth({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      enabled ? IntrinsicWidth(child: child) : child;
}
