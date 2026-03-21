import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemChipVisualState {
  idle,
  hover,
  pressed,
  activated,
}

class DesignSystemChip extends StatefulWidget {
  const DesignSystemChip({
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.avatar,
    this.showRemove = false,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         leadingIcon == null || avatar == null,
         'Use either leadingIcon or avatar, not both.',
       );

  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final Widget? avatar;
  final bool showRemove;
  final String? semanticsLabel;
  final DesignSystemChipVisualState? forcedState;

  @override
  State<DesignSystemChip> createState() => _DesignSystemChipState();
}

class _DesignSystemChipState extends State<DesignSystemChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemChip oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
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
    final visualState = _resolveVisualState();
    final sizeSpec = _ChipSizeSpec.fromTokens(tokens);
    final variantSpec = _ChipVariantSpec.fromTokens(
      tokens: tokens,
      visualState: visualState,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
    );

    final chip = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: variantSpec.backgroundColor,
          shape: shape,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
          onTap: widget.onPressed,
          onHover: widget.forcedState == null && enabled
              ? (value) => setState(() => _hovered = value)
              : null,
          onHighlightChanged: widget.forcedState == null && enabled
              ? (value) => setState(() => _pressed = value)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizeSpec.horizontalPadding,
              vertical: sizeSpec.verticalPadding,
            ),
            child: DefaultTextStyle.merge(
              style: sizeSpec.labelStyle.copyWith(
                color: variantSpec.labelColor,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: variantSpec.accessoryColor,
                  size: sizeSpec.accessoryIconSize,
                ),
                child: Semantics(
                  button: true,
                  enabled: enabled,
                  selected:
                      visualState == DesignSystemChipVisualState.activated,
                  label: widget.semanticsLabel,
                  child: _ChipContent(
                    label: widget.label,
                    leadingIcon: widget.leadingIcon,
                    avatar: widget.avatar,
                    showRemove: widget.showRemove,
                    gap: sizeSpec.itemGap,
                    accessoryBoxSize: sizeSpec.accessoryBoxSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return chip.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  DesignSystemChipVisualState _resolveVisualState() {
    if (widget.forcedState != null) {
      return widget.forcedState!;
    }
    if (_pressed) {
      return DesignSystemChipVisualState.pressed;
    }
    if (_hovered) {
      return DesignSystemChipVisualState.hover;
    }
    return DesignSystemChipVisualState.idle;
  }
}

class _ChipContent extends StatelessWidget {
  const _ChipContent({
    required this.label,
    required this.gap,
    required this.accessoryBoxSize,
    this.leadingIcon,
    this.avatar,
    this.showRemove = false,
  });

  final String label;
  final double gap;
  final double accessoryBoxSize;
  final IconData? leadingIcon;
  final Widget? avatar;
  final bool showRemove;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (avatar != null) {
      items.add(
        SizedBox.square(
          dimension: accessoryBoxSize,
          child: ClipOval(child: avatar),
        ),
      );
    } else if (leadingIcon != null) {
      items.add(
        SizedBox.square(
          dimension: accessoryBoxSize,
          child: Center(child: Icon(leadingIcon)),
        ),
      );
    }

    if (label.isNotEmpty) {
      items.add(
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (showRemove) {
      items.add(
        SizedBox.square(
          dimension: accessoryBoxSize,
          child: const Center(
            child: Icon(Icons.cancel_rounded),
          ),
        ),
      );
    }

    final children = items.isEmpty
        ? const <Widget>[]
        : items.intersperse(SizedBox(width: gap)).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ChipSizeSpec {
  const _ChipSizeSpec({
    required this.labelStyle,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.cornerRadius,
    required this.accessoryBoxSize,
    required this.accessoryIconSize,
  });

  factory _ChipSizeSpec.fromTokens(DsTokens tokens) {
    return _ChipSizeSpec(
      labelStyle: tokens.typography.styles.body.bodySmall,
      horizontalPadding: tokens.spacing.step3,
      verticalPadding: tokens.spacing.step1,
      itemGap: tokens.spacing.step2,
      cornerRadius: tokens.radii.s,
      accessoryBoxSize: tokens.typography.lineHeight.bodySmall,
      accessoryIconSize: tokens.typography.lineHeight.caption,
    );
  }

  final TextStyle labelStyle;
  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double cornerRadius;
  final double accessoryBoxSize;
  final double accessoryIconSize;
}

class _ChipVariantSpec {
  const _ChipVariantSpec({
    required this.backgroundColor,
    required this.labelColor,
    required this.accessoryColor,
  });

  factory _ChipVariantSpec.fromTokens({
    required DsTokens tokens,
    required DesignSystemChipVisualState visualState,
  }) {
    final backgroundColor = switch (visualState) {
      DesignSystemChipVisualState.idle => tokens.colors.surface.enabled,
      DesignSystemChipVisualState.hover => tokens.colors.surface.hover,
      DesignSystemChipVisualState.pressed => tokens.colors.surface.focusPressed,
      DesignSystemChipVisualState.activated => tokens.colors.surface.active,
    };

    return _ChipVariantSpec(
      backgroundColor: backgroundColor,
      labelColor: tokens.colors.text.highEmphasis,
      accessoryColor: tokens.colors.text.mediumEmphasis,
    );
  }

  final Color backgroundColor;
  final Color labelColor;
  final Color accessoryColor;
}
