import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const _kMenuWidth = 320.0;
const _kMaxVisibleItems = 6;
const _kShadowColor = Color.fromRGBO(70, 70, 70, 0.25);
const _kShadowBlurRadius = 4.0;
const _kShadowOffsetY = 2.0;

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
  });

  final String label;
  final Key? key;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isSelected;
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
    this.edgeToEdge = false,
    super.key,
  });

  final List<DesignSystemContextMenuItem> items;
  final DesignSystemContextMenuSize size;
  final double width;
  final String? semanticsLabel;

  /// Optional quiet heading rendered above the action rows.
  final String? header;

  /// Optional identity for the header row, used by anchored menus whose
  /// heading names the concrete object or date being acted on.
  final Key? headerKey;

  /// Removes the normal outer row padding so the first and last interaction
  /// fills meet — and are clipped by — the menu's rounded outline.
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ContextMenuSpec.fromTokens(tokens, size);
    final needsScroll = items.length > _kMaxVisibleItems;
    final verticalPadding = edgeToEdge ? 0.0 : spec.verticalPadding;
    final headerHeight = header == null ? 0.0 : spec.headerHeight;
    final maxHeight = needsScroll
        ? spec.itemHeight * _kMaxVisibleItems +
              verticalPadding * 2 +
              headerHeight
        : null;

    final itemList = needsScroll
        ? SizedBox(
            height: spec.itemHeight * _kMaxVisibleItems,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildItem(tokens, spec, items[index]),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map((item) => _buildItem(tokens, spec, item))
                .toList(),
          );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight)
              : const BoxConstraints(),
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: BorderRadius.circular(spec.borderRadius),
            boxShadow: const [
              BoxShadow(
                color: _kShadowColor,
                offset: Offset(0, _kShadowOffsetY),
                blurRadius: _kShadowBlurRadius,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(spec.borderRadius),
            // The inner Material puts hover/splash ink above the opaque card
            // decoration. The clip then makes an edge-to-edge last row follow
            // the bottom corners instead of stopping short of the border.
            child: Material(
              color: Colors.transparent,
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
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: verticalPadding),
                    child: itemList,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
      label: item.label,
      onTap: item.onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: item.onTap,
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
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
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
    required this.verticalPadding,
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
      verticalPadding: tokens.spacing.step2,
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
  final double verticalPadding;
  final double horizontalPadding;
  final double headerHeight;
  final double dividerWidth;
  final double itemHeight;
  final double iconSize;
  final double iconGap;
  final TextStyle textStyle;
}
