import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemButtonVariant {
  primary,
  secondary,
  tertiary,

  /// Transparent body with a neutral hairline border — a labeled action that
  /// must read as a button without spending a fill or the interactive accent.
  outlined,

  /// The outlined grammar carrying the interactive accent on its border and
  /// label — a demoted-but-*positive* action. Exists for slots beside a
  /// danger primary, where the neutral [outlined] treatment reads as Cancel:
  /// "Verify" next to "Remove" must still look like a good idea.
  constructiveOutlined,
  danger,
  dangerSecondary,
  dangerTertiary,
}

enum DesignSystemButtonSize {
  /// Caption-tier action for metadata rows and settings zones: the label sits
  /// at `typography.styles.others.caption`, so the control reads as a button
  /// through its glyph, ink and hover fill rather than by out-weighing the
  /// text around it.
  dense,
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

/// The design-system's primary button — the app-wide replacement for ad-hoc
/// buttons.
///
/// Renders one of [DesignSystemButtonVariant] (primary/secondary/…) at a
/// [DesignSystemButtonSize], optionally with leading/trailing icons, and
/// resolves all colors/spacing/typography from design tokens. A `null`
/// [onPressed] is the disabled state; [forcedState] pins a visual state for
/// widgetbook/tests; [fullWidth] stretches it to the parent width. When
/// [isLoading] is true the button keeps its branded colour but stops
/// responding to taps and swaps its leading glyph for a spinner. Asserts that
/// an icon-only button still supplies a [semanticsLabel]. [tapTargetSize]
/// decouples the visible pill from its pointer target: `padded` keeps the
/// visual size but centers it in a 48dp interaction slot, while `shrinkWrap`
/// preserves the compact layout for callers that do not own that space.
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
    this.isLoading = false,
    this.alignsLabelToLeadingEdge = false,
    this.tapTargetSize = MaterialTapTargetSize.shrinkWrap,
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
  final MaterialTapTargetSize tapTargetSize;

  /// When true, the button shows a spinner in place of its leading glyph and
  /// ignores taps, while keeping the enabled (branded) styling — the standard
  /// "work in progress" affordance. Pass the real [onPressed] alongside it; the
  /// button suppresses the tap itself, so the caller need not null it out.
  final bool isLoading;

  /// Pulls the button outward by its own horizontal content inset, so its
  /// glyph and label land on the parent's leading edge while the ink still
  /// bleeds into the surrounding padding.
  ///
  /// A button placed flush on a shared leading column otherwise puts its
  /// *content* one inset inside that column, because the padding is internal.
  /// The effect is invisible beside other buttons and obvious the moment the
  /// button sits in a stack of text rows — which is exactly where the caption
  /// tier gets used. Direction-aware, so it pulls right in RTL.
  final bool alignsLabelToLeadingEdge;

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
  bool _focused = false;

  @override
  void didUpdateWidget(covariant DesignSystemButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        oldWidget.isLoading != widget.isLoading ||
        (oldWidget.onPressed == null) != (widget.onPressed == null);

    if (interactionModeChanged) {
      _hovered = false;
      _pressed = false;
      _focused = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A button with a callback styles as enabled (branded) even while loading;
    // `interactable` gates taps/hover so a loading button looks active but
    // doesn't fire.
    final hasCallback = widget.onPressed != null;
    final interactable = hasCallback && !widget.isLoading;
    final visualState = _resolveVisualState(interactable);
    final sizeSpec = _ButtonSizeSpec.fromTokens(tokens, widget.size);
    final variantSpec = _ButtonVariantSpec.fromTokens(
      tokens: tokens,
      variant: widget.variant,
      visualState: visualState,
      enabled: hasCallback,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
      side: variantSpec.borderColor != null
          ? BorderSide(color: variantSpec.borderColor!)
          : BorderSide.none,
    );

    final visualButton = Ink(
      decoration: ShapeDecoration(
        color: variantSpec.backgroundColor ?? Colors.transparent,
        shape: buttonShape,
      ),
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
            child: widget.fullWidth
                ? Center(
                    child: _ButtonContent(
                      label: widget.label,
                      leadingIcon: widget.leadingIcon,
                      trailingIcon: widget.trailingIcon,
                      gap: sizeSpec.itemGap,
                      isLoading: widget.isLoading,
                    ),
                  )
                : _ButtonContent(
                    label: widget.label,
                    leadingIcon: widget.leadingIcon,
                    trailingIcon: widget.trailingIcon,
                    gap: sizeSpec.itemGap,
                    isLoading: widget.isLoading,
                  ),
          ),
        ),
      ),
    );
    final targetConstraints =
        widget.tapTargetSize == MaterialTapTargetSize.padded
        ? const BoxConstraints(
            minWidth: TapTargets.minimum,
            minHeight: TapTargets.minimum,
          )
        : const BoxConstraints();
    final button = Material(
      color: Colors.transparent,
      child: Semantics(
        container: true,
        button: true,
        label: widget.semanticsLabel ?? widget.label,
        enabled: interactable,
        onTap: interactable ? widget.onPressed : null,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: interactable ? widget.onPressed : null,
          onHover: widget.forcedState == null && interactable
              ? (value) => setState(() => _hovered = value)
              : null,
          onFocusChange: widget.forcedState == null && interactable
              ? (value) => setState(() => _focused = value)
              : null,
          onHighlightChanged: widget.forcedState == null && interactable
              ? (value) => setState(() => _pressed = value)
              : null,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: targetConstraints,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visualShell =
                      widget.fullWidth && constraints.hasBoundedWidth
                      ? SizedBox(
                          width: constraints.maxWidth,
                          child: visualButton,
                        )
                      : visualButton;
                  return Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: visualShell,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.alignsLabelToLeadingEdge) return button;
    final towardsLeading = Directionality.of(context) == TextDirection.rtl
        ? 1.0
        : -1.0;
    return Transform.translate(
      offset: Offset(towardsLeading * sizeSpec.horizontalPadding, 0),
      child: button,
    );
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
    if (_hovered || _focused) {
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
    this.isLoading = false,
  });

  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double gap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // The spinner takes the leading slot at the icon's footprint (from the
    // ambient IconTheme), so toggling loading on an icon button never resizes
    // it, and it inherits the foreground colour.
    final iconTheme = IconTheme.of(context);

    if (isLoading) {
      children.add(
        SizedBox.square(
          dimension: iconTheme.size ?? 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconTheme.color,
          ),
        ),
      );
    } else if (leadingIcon != null) {
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
      DesignSystemButtonSize.dense => _ButtonSizeSpec(
        labelStyle: tokens.typography.styles.others.caption,
        iconSize: tokens.typography.lineHeight.caption,
        horizontalPadding: tokens.spacing.step2,
        verticalPadding: tokens.spacing.step2,
        itemGap: tokens.spacing.step2,
        cornerRadius: tokens.radii.s,
      ),
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
    this.borderColor,
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
        DesignSystemButtonVariant.outlined ||
        DesignSystemButtonVariant.constructiveOutlined ||
        DesignSystemButtonVariant.dangerTertiary => false,
      };
      final isOutlined =
          variant == DesignSystemButtonVariant.outlined ||
          variant == DesignSystemButtonVariant.constructiveOutlined;
      return _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.lowEmphasis,
        backgroundColor: isFilled ? tokens.colors.surface.enabled : null,
        borderColor: isOutlined ? tokens.colors.text.lowEmphasis : null,
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
    final dangerContentColor = switch (visualState) {
      DesignSystemButtonVisualState.idle => tokens.colors.alert.error.hover,
      DesignSystemButtonVisualState.hover => tokens.colors.alert.error.pressed,
      DesignSystemButtonVisualState.pressed => tokens.colors.text.highEmphasis,
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
      DesignSystemButtonVariant.outlined => _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.highEmphasis,
        backgroundColor: visualState == DesignSystemButtonVisualState.idle
            ? null
            : surfaceColor,
        borderColor: tokens.colors.text.lowEmphasis,
      ),
      DesignSystemButtonVariant.constructiveOutlined => _ButtonVariantSpec(
        // The accent rides border and label together, tracking the
        // interaction state like the tertiary text button does — the
        // outlined shape demotes it, the hue keeps it a good idea.
        foregroundColor: interactiveColor,
        backgroundColor: visualState == DesignSystemButtonVisualState.idle
            ? null
            : surfaceColor,
        borderColor: interactiveColor,
      ),
      DesignSystemButtonVariant.danger => _ButtonVariantSpec(
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        backgroundColor: dangerColor,
      ),
      DesignSystemButtonVariant.dangerSecondary => _ButtonVariantSpec(
        foregroundColor: dangerContentColor,
        backgroundColor: surfaceColor,
      ),
      DesignSystemButtonVariant.dangerTertiary => _ButtonVariantSpec(
        foregroundColor: dangerContentColor,
        backgroundColor: visualState == DesignSystemButtonVisualState.idle
            ? null
            : surfaceColor,
      ),
    };
  }

  final Color foregroundColor;
  final Color? backgroundColor;

  /// Hairline stroke for the outlined variant; null renders no border.
  final Color? borderColor;
}
