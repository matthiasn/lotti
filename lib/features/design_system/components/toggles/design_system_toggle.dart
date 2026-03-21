import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemToggleSize {
  small,
  defaultSize,
}

enum DesignSystemToggleVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemToggle extends StatefulWidget {
  const DesignSystemToggle({
    required this.value,
    required this.onChanged,
    this.size = DesignSystemToggleSize.small,
    this.label,
    this.semanticsLabel,
    this.tooltipIcon,
    this.tooltipMessage,
    this.enabled = true,
    this.forcedState,
    super.key,
  }) : assert(
         (label != null && label != '') || semanticsLabel != null,
         'Provide either a visible label or a semanticsLabel.',
       );

  final bool value;
  final ValueChanged<bool> onChanged;
  final DesignSystemToggleSize size;
  final String? label;
  final String? semanticsLabel;
  final IconData? tooltipIcon;
  final String? tooltipMessage;
  final bool enabled;
  final DesignSystemToggleVisualState? forcedState;

  @override
  State<DesignSystemToggle> createState() => _DesignSystemToggleState();
}

class _DesignSystemToggleState extends State<DesignSystemToggle> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemToggle oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        oldWidget.enabled != widget.enabled;

    if (interactionModeChanged) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.enabled;
    final visualState = _resolveVisualState(enabled);
    final sizeSpec = _ToggleSizeSpec.fromTokens(tokens, widget.size);
    final variantSpec = _ToggleVariantSpec.fromTokens(
      tokens: tokens,
      value: widget.value,
      visualState: visualState,
    );
    final hasLabel = widget.label?.isNotEmpty == true;
    final hasTooltipIcon = widget.tooltipIcon != null;
    final tooltipMessage =
        widget.tooltipMessage ?? widget.label ?? widget.semanticsLabel!;
    final control = _ToggleControl(
      sizeSpec: sizeSpec,
      variantSpec: variantSpec,
      value: widget.value,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        if (hasLabel || hasTooltipIcon) SizedBox(width: sizeSpec.itemGap),
        if (hasLabel)
          Flexible(
            child: DefaultTextStyle.merge(
              style: sizeSpec.labelStyle.copyWith(
                color: variantSpec.labelColor,
              ),
              child: Text(
                widget.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (hasLabel && hasTooltipIcon) SizedBox(width: sizeSpec.inlineGap),
        if (hasTooltipIcon)
          Tooltip(
            message: tooltipMessage,
            child: Icon(
              widget.tooltipIcon,
              size: sizeSpec.tooltipIconSize,
              color: variantSpec.iconColor,
            ),
          ),
      ],
    );

    final toggle = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => widget.onChanged(!widget.value) : null,
        onHover: widget.forcedState == null && enabled
            ? (value) => setState(() => _hovered = value)
            : null,
        onHighlightChanged: widget.forcedState == null && enabled
            ? (value) => setState(() => _pressed = value)
            : null,
        child: Semantics(
          button: true,
          enabled: enabled,
          toggled: widget.value,
          label: widget.semanticsLabel ?? widget.label,
          child: content,
        ),
      ),
    );

    return toggle.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  DesignSystemToggleVisualState _resolveVisualState(bool enabled) {
    if (!enabled) {
      return DesignSystemToggleVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }
    if (_pressed) {
      return DesignSystemToggleVisualState.pressed;
    }
    if (_hovered) {
      return DesignSystemToggleVisualState.hover;
    }
    return DesignSystemToggleVisualState.idle;
  }
}

const _kToggleAnimationDuration = Duration(milliseconds: 160);

class _ToggleControl extends StatelessWidget {
  const _ToggleControl({
    required this.sizeSpec,
    required this.variantSpec,
    required this.value,
  });

  final _ToggleSizeSpec sizeSpec;
  final _ToggleVariantSpec variantSpec;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kToggleAnimationDuration,
      curve: Curves.easeOut,
      width: sizeSpec.trackWidth,
      height: sizeSpec.trackHeight,
      padding: EdgeInsets.all(sizeSpec.trackInset),
      decoration: BoxDecoration(
        color: variantSpec.trackColor,
        borderRadius: BorderRadius.circular(sizeSpec.trackRadius),
        border: variantSpec.trackBorderColor == null
            ? null
            : Border.all(
                color: variantSpec.trackBorderColor!,
                width: sizeSpec.borderWidth,
              ),
      ),
      child: AnimatedAlign(
        duration: _kToggleAnimationDuration,
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: _kToggleAnimationDuration,
          curve: Curves.easeOut,
          width: sizeSpec.thumbDiameter,
          height: sizeSpec.thumbDiameter,
          decoration: BoxDecoration(
            color: variantSpec.thumbColor,
            borderRadius: BorderRadius.circular(sizeSpec.thumbRadius),
            border: Border.all(
              color: variantSpec.thumbBorderColor,
              width: sizeSpec.thumbBorderWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleSizeSpec {
  const _ToggleSizeSpec({
    required this.trackWidth,
    required this.trackHeight,
    required this.trackInset,
    required this.thumbDiameter,
    required this.trackRadius,
    required this.thumbRadius,
    required this.borderWidth,
    required this.thumbBorderWidth,
    required this.itemGap,
    required this.inlineGap,
    required this.labelStyle,
    required this.tooltipIconSize,
  });

  factory _ToggleSizeSpec.fromTokens(
    DsTokens tokens,
    DesignSystemToggleSize size,
  ) {
    return switch (size) {
      DesignSystemToggleSize.small => _ToggleSizeSpec(
        trackWidth: tokens.spacing.step8,
        trackHeight: tokens.spacing.step6,
        trackInset: tokens.spacing.step1,
        thumbDiameter: tokens.spacing.step6 - tokens.spacing.step2,
        trackRadius: tokens.spacing.step6 / 2,
        thumbRadius: (tokens.spacing.step6 - tokens.spacing.step2) / 2,
        borderWidth: tokens.spacing.step1 / 2,
        thumbBorderWidth: tokens.spacing.step1 / 2,
        itemGap: tokens.spacing.step2,
        inlineGap: tokens.spacing.step1,
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        tooltipIconSize: tokens.typography.styles.subtitle.subtitle2.fontSize!,
      ),
      DesignSystemToggleSize.defaultSize => _ToggleSizeSpec(
        trackWidth: tokens.spacing.step9,
        trackHeight: tokens.spacing.step7,
        trackInset: tokens.spacing.step1,
        thumbDiameter: tokens.spacing.step7 - tokens.spacing.step2,
        trackRadius: tokens.spacing.step7 / 2,
        thumbRadius: (tokens.spacing.step7 - tokens.spacing.step2) / 2,
        borderWidth: tokens.spacing.step1 / 2,
        thumbBorderWidth: tokens.spacing.step1 / 2,
        itemGap: tokens.spacing.step3,
        inlineGap: tokens.spacing.step1,
        labelStyle: tokens.typography.styles.subtitle.subtitle1,
        tooltipIconSize: tokens.typography.styles.subtitle.subtitle1.fontSize!,
      ),
    };
  }

  final double trackWidth;
  final double trackHeight;
  final double trackInset;
  final double thumbDiameter;
  final double trackRadius;
  final double thumbRadius;
  final double borderWidth;
  final double thumbBorderWidth;
  final double itemGap;
  final double inlineGap;
  final TextStyle labelStyle;
  final double tooltipIconSize;
}

class _ToggleVariantSpec {
  const _ToggleVariantSpec({
    required this.trackColor,
    required this.trackBorderColor,
    required this.thumbColor,
    required this.thumbBorderColor,
    required this.labelColor,
    required this.iconColor,
  });

  factory _ToggleVariantSpec.fromTokens({
    required DsTokens tokens,
    required bool value,
    required DesignSystemToggleVisualState visualState,
  }) {
    final trackColor = switch (value) {
      true => switch (visualState) {
        DesignSystemToggleVisualState.idle => tokens.colors.interactive.enabled,
        DesignSystemToggleVisualState.hover => tokens.colors.interactive.hover,
        DesignSystemToggleVisualState.pressed =>
          tokens.colors.interactive.pressed,
      },
      false => switch (visualState) {
        DesignSystemToggleVisualState.idle => tokens.colors.background.level02,
        DesignSystemToggleVisualState.hover => tokens.colors.surface.hover,
        DesignSystemToggleVisualState.pressed =>
          tokens.colors.surface.focusPressed,
      },
    };

    return _ToggleVariantSpec(
      trackColor: trackColor,
      trackBorderColor: value ? null : tokens.colors.decorative.level02,
      thumbColor: tokens.colors.background.level01,
      thumbBorderColor: tokens.colors.decorative.level02,
      labelColor: tokens.colors.text.highEmphasis,
      iconColor: tokens.colors.text.mediumEmphasis,
    );
  }

  final Color trackColor;
  final Color? trackBorderColor;
  final Color thumbColor;
  final Color thumbBorderColor;
  final Color labelColor;
  final Color iconColor;
}
