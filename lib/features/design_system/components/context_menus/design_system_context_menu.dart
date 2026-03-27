import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const _kMenuWidth = 320.0;
const _kMaxVisibleItems = 6;
const _kShadowColor = Color.fromRGBO(70, 70, 70, 0.25);
const _kShadowBlurRadius = 4.0;
const _kShadowOffsetY = 2.0;

@visibleForTesting
const kSmallItemHeight = 36.0;

class DesignSystemContextMenuItem {
  const DesignSystemContextMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDestructive;
}

enum DesignSystemContextMenuSize {
  small,
  medium,
}

class DesignSystemContextMenu extends StatelessWidget {
  const DesignSystemContextMenu({
    required this.items,
    this.size = DesignSystemContextMenuSize.medium,
    this.width = _kMenuWidth,
    this.semanticsLabel,
    super.key,
  });

  final List<DesignSystemContextMenuItem> items;
  final DesignSystemContextMenuSize size;
  final double width;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ContextMenuSpec.fromTokens(tokens, size);
    final needsScroll = items.length > _kMaxVisibleItems;
    final maxHeight = needsScroll
        ? spec.itemHeight * _kMaxVisibleItems + spec.verticalPadding * 2
        : null;

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
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spec.verticalPadding),
              child: needsScroll
                  ? ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildItem(tokens, spec, items[index]),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items
                          .map((item) => _buildItem(tokens, spec, item))
                          .toList(),
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
    final textColor = item.isDestructive
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.text.highEmphasis;

    return InkWell(
      onTap: item.onTap,
      child: SizedBox(
        height: spec.itemHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spec.horizontalPadding),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: spec.iconSize,
                  color: textColor,
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
    );
  }
}

class _ContextMenuSpec {
  const _ContextMenuSpec({
    required this.borderRadius,
    required this.verticalPadding,
    required this.horizontalPadding,
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
  final double itemHeight;
  final double iconSize;
  final double iconGap;
  final TextStyle textStyle;
}

/// Shows a [DesignSystemContextMenu] as a popup at the given position.
Future<void> showDesignSystemContextMenu({
  required BuildContext context,
  required Offset position,
  required List<DesignSystemContextMenuItem> items,
  DesignSystemContextMenuSize size = DesignSystemContextMenuSize.medium,
}) async {
  final overlay = Overlay.of(context);
  final screenSize = MediaQuery.of(context).size;
  late final OverlayEntry entry;

  final left = (position.dx + _kMenuWidth > screenSize.width)
      ? screenSize.width - _kMenuWidth
      : position.dx;

  entry = OverlayEntry(
    builder: (context) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: entry.remove,
      child: Stack(
        children: [
          Positioned(
            left: left.clamp(0.0, screenSize.width),
            top: position.dy.clamp(0.0, screenSize.height),
            child: DesignSystemContextMenu(
              items: items.map((item) {
                return DesignSystemContextMenuItem(
                  label: item.label,
                  icon: item.icon,
                  isDestructive: item.isDestructive,
                  onTap: () {
                    entry.remove();
                    item.onTap?.call();
                  },
                );
              }).toList(),
              size: size,
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
}
