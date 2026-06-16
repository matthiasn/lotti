import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemButtonVariant {
  primary,
  secondary,
  tertiary,
  danger,
  dangerSecondary,
  dangerTertiary,
}

enum DesignSystemButtonSize {
  small,
  medium,
  large,
  jumbo,
}

enum DesignSystemButtonVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemButton extends StatefulWidget {
  const DesignSystemButton({
    required this.label,
    required this.onPressed,
    this.variant = DesignSystemButtonVariant.primary,
    this.size = DesignSystemButtonSize.small,
    this.leadingIcon,
    this.trailingIcon,
    this.semanticsLabel,
    this.forcedState,
    this.fullWidth = false,
    super.key,
  }) : assert(
         label != '' || semanticsLabel != null,
         'Provide either a visible label or a semanticsLabel.',
       );

  final String label;
  final VoidCallback? onPressed;
  final DesignSystemButtonVariant variant;
  final DesignSystemButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final String? semanticsLabel;
  final DesignSystemButtonVisualState? forcedState;

  /// When true, the button expands to fill its parent's width (use inside an
  /// [Expanded]/[SizedBox]) and its content is centered rather than left
  /// aligned. Without it a stretched button left-aligns its label.
  final bool fullWidth;

  @override
  State<DesignSystemButton> createState() => _DesignSystemButtonState();
}

class _DesignSystemButtonState extends State<DesignSystemButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemButton oldWidget) {
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
    final visualState = _resolveVisualState(enabled);
    final sizeSpec = _ButtonSizeSpec.fromTokens(tokens, widget.size);
    final variantSpec = _ButtonVariantSpec.fromTokens(
      tokens: tokens,
      variant: widget.variant,
      visualState: visualState,
      enabled: enabled,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
    );

    final button = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: variantSpec.backgroundColor ?? Colors.transparent,
          shape: buttonShape,
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
                color: variantSpec.foregroundColor,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: variantSpec.foregroundColor,
                  size: sizeSpec.iconSize,
                ),
                child: Semantics(
                  button: true,
                  label: widget.semanticsLabel,
                  enabled: enabled,
                  child: widget.fullWidth
                      ? Center(
                          child: _ButtonContent(
                            label: widget.label,
                            leadingIcon: widget.leadingIcon,
                            trailingIcon: widget.trailingIcon,
                            gap: sizeSpec.itemGap,
                          ),
                        )
                      : _ButtonContent(
                          label: widget.label,
                          leadingIcon: widget.leadingIcon,
                          trailingIcon: widget.trailingIcon,
                          gap: sizeSpec.itemGap,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return button;
  }

  DesignSystemButtonVisualState _resolveVisualState(bool enabled) {
    if (!enabled) {
      return DesignSystemButtonVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }
    if (_pressed) {
      return DesignSystemButtonVisualState.pressed;
    }
    if (_hovered) {
      return DesignSystemButtonVisualState.hover;
    }
    return DesignSystemButtonVisualState.idle;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.gap,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (leadingIcon != null) {
      children.add(Icon(leadingIcon));
    }

    if (label.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: gap));
      }

      children.add(
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );
    }

    if (trailingIcon != null) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: gap));
      }
      children.add(Icon(trailingIcon));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ButtonSizeSpec {
  const _ButtonSizeSpec({
    required this.labelStyle,
    required this.iconSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.cornerRadius,
  });

  factory _ButtonSizeSpec.fromTokens(
    DsTokens tokens,
    DesignSystemButtonSize size,
  ) {
    return switch (size) {
      DesignSystemButtonSize.small => _ButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        iconSize: tokens.typography.lineHeight.subtitle2,
        horizontalPadding: tokens.spacing.step3,
        verticalPadding: tokens.spacing.step3,
        itemGap: tokens.spacing.step2,
        cornerRadius: tokens.radii.l,
      ),
      DesignSystemButtonSize.medium => _ButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        iconSize: tokens.typography.lineHeight.subtitle2,
        horizontalPadding: tokens.spacing.step4,
        verticalPadding: tokens.spacing.step4,
        itemGap: tokens.spacing.step3,
        cornerRadius: tokens.radii.xl,
      ),
      DesignSystemButtonSize.large => _ButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle1,
        iconSize: tokens.typography.lineHeight.subtitle1,
        horizontalPadding: tokens.spacing.step4,
        verticalPadding: tokens.spacing.step4,
        itemGap: tokens.spacing.step3,
        cornerRadius: tokens.radii.xl,
      ),
      DesignSystemButtonSize.jumbo => _ButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle1,
        iconSize: tokens.typography.lineHeight.subtitle1,
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step5,
        itemGap: tokens.spacing.step3,
        cornerRadius: tokens.radii.xl,
      ),
    };
  }

  final TextStyle labelStyle;
  final double iconSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double cornerRadius;
}

class _ButtonVariantSpec {
  const _ButtonVariantSpec({
    required this.foregroundColor,
    required this.backgroundColor,
  });

  factory _ButtonVariantSpec.fromTokens({
    required DsTokens tokens,
    required DesignSystemButtonVariant variant,
    required DesignSystemButtonVisualState visualState,
    required bool enabled,
  }) {
    // A disabled button must read as inert, not as a dimmer brand button: drop
    // the brand hue entirely and render a flat, low-emphasis neutral. Filled
    // variants keep a faint neutral pill so they still read as a (disabled)
    // button; text-only (tertiary) variants stay fill-less. The label uses the
    // low-emphasis text token so it is clearly muted rather than actionable.
    if (!enabled) {
      final isFilled = switch (variant) {
        DesignSystemButtonVariant.primary ||
        DesignSystemButtonVariant.secondary ||
        DesignSystemButtonVariant.danger ||
        DesignSystemButtonVariant.dangerSecondary => true,
        DesignSystemButtonVariant.tertiary ||
        DesignSystemButtonVariant.dangerTertiary => false,
      };
      return _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.lowEmphasis,
        backgroundColor: isFilled ? tokens.colors.surface.enabled : null,
      );
    }

    final surfaceColor = switch (visualState) {
      DesignSystemButtonVisualState.idle => tokens.colors.surface.enabled,
      DesignSystemButtonVisualState.hover => tokens.colors.surface.hover,
      DesignSystemButtonVisualState.pressed =>
        tokens.colors.surface.focusPressed,
    };

    final interactiveColor = switch (visualState) {
      DesignSystemButtonVisualState.idle => tokens.colors.interactive.enabled,
      DesignSystemButtonVisualState.hover => tokens.colors.interactive.hover,
      DesignSystemButtonVisualState.pressed =>
        tokens.colors.interactive.pressed,
    };

    final dangerColor = switch (visualState) {
      DesignSystemButtonVisualState.idle =>
        tokens.colors.alert.error.defaultColor,
      DesignSystemButtonVisualState.hover => tokens.colors.alert.error.hover,
      DesignSystemButtonVisualState.pressed =>
        tokens.colors.alert.error.pressed,
    };

    return switch (variant) {
      DesignSystemButtonVariant.primary => _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        backgroundColor: interactiveColor,
      ),
      DesignSystemButtonVariant.secondary => _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.highEmphasis,
        backgroundColor: surfaceColor,
      ),
      DesignSystemButtonVariant.tertiary => _ButtonVariantSpec(
        foregroundColor: interactiveColor,
        backgroundColor: visualState == DesignSystemButtonVisualState.idle
            ? null
            : surfaceColor,
      ),
      DesignSystemButtonVariant.danger => _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        backgroundColor: dangerColor,
      ),
      DesignSystemButtonVariant.dangerSecondary => _ButtonVariantSpec(
        foregroundColor: tokens.colors.alert.error.defaultColor,
        backgroundColor: surfaceColor,
      ),
      DesignSystemButtonVariant.dangerTertiary => _ButtonVariantSpec(
        foregroundColor: tokens.colors.alert.error.defaultColor,
        backgroundColor: visualState == DesignSystemButtonVisualState.idle
            ? null
            : surfaceColor,
      ),
    };
  }

  final Color foregroundColor;
  final Color? backgroundColor;
}
