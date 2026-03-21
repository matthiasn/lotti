import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemTabSize {
  small,
  defaultSize,
}

enum DesignSystemTabVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemTab extends StatefulWidget {
  const DesignSystemTab({
    required this.selected,
    required this.onPressed,
    this.size = DesignSystemTabSize.defaultSize,
    this.label,
    this.counter,
    this.leadingIcon,
    this.trailingIcon,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         label != null || semanticsLabel != null,
         'Provide label or semanticsLabel for accessibility.',
       );

  final bool selected;
  final VoidCallback? onPressed;
  final DesignSystemTabSize size;
  final String? label;
  final String? counter;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final String? semanticsLabel;
  final DesignSystemTabVisualState? forcedState;

  @override
  State<DesignSystemTab> createState() => _DesignSystemTabState();
}

class _DesignSystemTabState extends State<DesignSystemTab> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        oldWidget.selected != widget.selected ||
        (oldWidget.onPressed == null) != (widget.onPressed == null);

    if (interactionModeChanged) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onPressed != null;
    final visualState = _resolveVisualState(enabled);
    final sizeSpec = _TabSizeSpec.fromTokens(tokens, widget.size);
    final styleSpec = _TabStyleSpec.fromTokens(
      tokens: tokens,
      selected: widget.selected,
      enabled: enabled,
      visualState: visualState,
    );

    final tab = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: widget.forcedState == null && enabled && !widget.selected
            ? (value) => setState(() => _hovered = value)
            : null,
        onHighlightChanged: widget.forcedState == null && enabled
            ? (value) => setState(() => _pressed = value)
            : null,
        child: Semantics(
          button: true,
          enabled: enabled,
          selected: widget.selected,
          label: widget.semanticsLabel ?? widget.label,
          child: IntrinsicWidth(
            child: SizedBox(
              height: sizeSpec.height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Ink(
                      decoration: BoxDecoration(
                        color: styleSpec.backgroundColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(sizeSpec.cornerRadius),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: sizeSpec.horizontalPadding,
                          right: sizeSpec.horizontalPadding,
                          top: sizeSpec.topPadding,
                          bottom: widget.selected
                              ? sizeSpec.selectedBottomPadding
                              : sizeSpec.bottomPadding,
                        ),
                        child: DefaultTextStyle.merge(
                          style: sizeSpec.labelStyle.copyWith(
                            color: styleSpec.labelColor,
                          ),
                          child: _TabContent(
                            sizeSpec: sizeSpec,
                            styleSpec: styleSpec,
                            label: widget.label,
                            counter: widget.counter,
                            leadingIcon: widget.leadingIcon,
                            trailingIcon: widget.trailingIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.selected)
                    SizedBox(
                      height: sizeSpec.selectorHeight,
                      child: ColoredBox(color: styleSpec.selectorColor),
                    ),
                  if (styleSpec.showDivider)
                    SizedBox(
                      height: sizeSpec.dividerHeight,
                      child: ColoredBox(color: styleSpec.dividerColor),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return tab;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: tab,
    );
  }

  DesignSystemTabVisualState _resolveVisualState(bool enabled) {
    if (!enabled || widget.selected) {
      return DesignSystemTabVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }

    if (_pressed) {
      return DesignSystemTabVisualState.pressed;
    }

    if (_hovered) {
      return DesignSystemTabVisualState.hover;
    }

    return DesignSystemTabVisualState.idle;
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.sizeSpec,
    required this.styleSpec,
    this.label,
    this.counter,
    this.leadingIcon,
    this.trailingIcon,
  });

  final _TabSizeSpec sizeSpec;
  final _TabStyleSpec styleSpec;
  final String? label;
  final String? counter;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    final primaryChildren = <Widget>[];
    if (leadingIcon != null) {
      primaryChildren.add(
        _TabIcon(
          icon: leadingIcon!,
          sizeSpec: sizeSpec,
          color: styleSpec.leadingIconColor,
        ),
      );
    }

    if (label?.isNotEmpty == true) {
      primaryChildren.add(
        Text(
          label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (primaryChildren.isNotEmpty) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: primaryChildren
              .intersperse(SizedBox(width: sizeSpec.primaryContentGap))
              .toList(),
        ),
      );
    }

    if (counter?.isNotEmpty == true) {
      children.add(
        DesignSystemBadge.number(
          value: counter!,
          tone: DesignSystemBadgeTone.secondary,
        ),
      );
    }

    if (trailingIcon != null) {
      children.add(
        _TabIcon(
          icon: trailingIcon!,
          sizeSpec: sizeSpec,
          color: styleSpec.trailingIconColor,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children
          .intersperse(SizedBox(width: sizeSpec.secondaryContentGap))
          .toList(),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.sizeSpec,
    required this.color,
  });

  final IconData icon;
  final _TabSizeSpec sizeSpec;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: sizeSpec.iconSlotSize,
      child: Center(
        child: Icon(
          icon,
          size: sizeSpec.iconSize,
          color: color,
        ),
      ),
    );
  }
}

class _TabSizeSpec {
  const _TabSizeSpec({
    required this.height,
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.selectedBottomPadding,
    required this.iconSlotSize,
    required this.iconSize,
    required this.primaryContentGap,
    required this.secondaryContentGap,
    required this.labelStyle,
    required this.selectorHeight,
    required this.dividerHeight,
    required this.cornerRadius,
  });

  factory _TabSizeSpec.fromTokens(
    DsTokens tokens,
    DesignSystemTabSize size,
  ) {
    final selectorHeight = tokens.spacing.step2 - (tokens.spacing.step1 / 2);
    final dividerHeight = tokens.spacing.step1 / 2;
    final iconSize = tokens.typography.size.subtitle2;
    final primaryContentGap = tokens.spacing.step2;
    final secondaryContentGap = tokens.spacing.step6;
    final labelStyle = tokens.typography.styles.subtitle.subtitle2;
    final cornerRadius = tokens.radii.m;

    return switch (size) {
      DesignSystemTabSize.small => _TabSizeSpec(
        height: tokens.spacing.step8 + (tokens.spacing.step1 / 2),
        horizontalPadding: tokens.spacing.step4,
        topPadding: tokens.spacing.step4 - tokens.spacing.step1,
        bottomPadding: tokens.spacing.step4 - tokens.spacing.step1,
        selectedBottomPadding:
            tokens.spacing.step3 - (tokens.spacing.step1 / 2),
        iconSlotSize: tokens.typography.lineHeight.subtitle2,
        iconSize: iconSize,
        primaryContentGap: primaryContentGap,
        secondaryContentGap: secondaryContentGap,
        labelStyle: labelStyle,
        selectorHeight: selectorHeight,
        dividerHeight: dividerHeight,
        cornerRadius: cornerRadius,
      ),
      DesignSystemTabSize.defaultSize => _TabSizeSpec(
        height: tokens.spacing.step9 + (tokens.spacing.step1 / 2),
        horizontalPadding: tokens.spacing.step5,
        topPadding: tokens.spacing.step4,
        bottomPadding: tokens.spacing.step4,
        selectedBottomPadding: tokens.spacing.step4 - selectorHeight,
        iconSlotSize: tokens.typography.lineHeight.subtitle1,
        iconSize: iconSize,
        primaryContentGap: primaryContentGap,
        secondaryContentGap: secondaryContentGap,
        labelStyle: labelStyle,
        selectorHeight: selectorHeight,
        dividerHeight: dividerHeight,
        cornerRadius: cornerRadius,
      ),
    };
  }

  final double height;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double selectedBottomPadding;
  final double iconSlotSize;
  final double iconSize;
  final double primaryContentGap;
  final double secondaryContentGap;
  final TextStyle labelStyle;
  final double selectorHeight;
  final double dividerHeight;
  final double cornerRadius;
}

class _TabStyleSpec {
  const _TabStyleSpec({
    required this.backgroundColor,
    required this.labelColor,
    required this.leadingIconColor,
    required this.trailingIconColor,
    required this.selectorColor,
    required this.dividerColor,
    required this.showDivider,
  });

  factory _TabStyleSpec.fromTokens({
    required DsTokens tokens,
    required bool selected,
    required bool enabled,
    required DesignSystemTabVisualState visualState,
  }) {
    final backgroundColor = selected
        ? tokens.colors.surface.active
        : switch (visualState) {
            DesignSystemTabVisualState.idle => tokens.colors.surface.enabled,
            DesignSystemTabVisualState.hover => tokens.colors.surface.hover,
            DesignSystemTabVisualState.pressed =>
              tokens.colors.surface.focusPressed,
          };

    final emphasisColor = switch ((selected, enabled)) {
      (true, _) => tokens.colors.interactive.enabled,
      (false, false) => tokens.colors.text.lowEmphasis,
      (false, true) => tokens.colors.text.highEmphasis,
    };

    return _TabStyleSpec(
      backgroundColor: backgroundColor,
      labelColor: emphasisColor,
      leadingIconColor: emphasisColor,
      trailingIconColor: enabled
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.lowEmphasis,
      selectorColor: tokens.colors.interactive.enabled,
      dividerColor: tokens.colors.decorative.level02,
      showDivider: selected || enabled,
    );
  }

  final Color backgroundColor;
  final Color labelColor;
  final Color leadingIconColor;
  final Color trailingIconColor;
  final Color selectorColor;
  final Color dividerColor;
  final bool showDivider;
}
