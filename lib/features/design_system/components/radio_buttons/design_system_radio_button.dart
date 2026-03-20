import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemRadioButtonSize {
  defaultSize,
  large,
}

enum DesignSystemRadioButtonVisualState {
  idle,
  hover,
}

class DesignSystemRadioButton extends StatefulWidget {
  const DesignSystemRadioButton({
    required this.selected,
    required this.onPressed,
    this.size = DesignSystemRadioButtonSize.defaultSize,
    this.label,
    this.showTooltipIcon = false,
    this.tooltipMessage,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         label != null || !showTooltipIcon,
         'A tooltip icon requires a label.',
       );

  final bool selected;
  final VoidCallback? onPressed;
  final DesignSystemRadioButtonSize size;
  final String? label;
  final bool showTooltipIcon;
  final String? tooltipMessage;
  final String? semanticsLabel;
  final DesignSystemRadioButtonVisualState? forcedState;

  @override
  State<DesignSystemRadioButton> createState() =>
      _DesignSystemRadioButtonState();
}

class _DesignSystemRadioButtonState extends State<DesignSystemRadioButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onPressed != null;
    final visualState = _resolveVisualState(enabled);
    final sizeSpec = _RadioButtonSizeSpec.fromTokens(tokens, widget.size);
    final colorSpec = _RadioButtonColorSpec.fromTokens(
      tokens: tokens,
      visualState: visualState,
    );

    final radio = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: widget.forcedState == null && enabled
            ? (value) => setState(() => _hovered = value)
            : null,
        child: DefaultTextStyle.merge(
          style: sizeSpec.labelStyle.copyWith(color: colorSpec.labelColor),
          child: IconTheme.merge(
            data: IconThemeData(
              color: colorSpec.tooltipColor,
              size: sizeSpec.tooltipIconSize,
            ),
            child: Semantics(
              button: true,
              enabled: enabled,
              selected: widget.selected,
              label: widget.semanticsLabel ?? widget.label,
              child: _RadioButtonContent(
                selected: widget.selected,
                sizeSpec: sizeSpec,
                colorSpec: colorSpec,
                label: widget.label,
                showTooltipIcon: widget.showTooltipIcon,
                tooltipMessage: widget.tooltipMessage,
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return radio;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: radio,
    );
  }

  DesignSystemRadioButtonVisualState _resolveVisualState(bool enabled) {
    if (!enabled) {
      return DesignSystemRadioButtonVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }

    if (_hovered) {
      return DesignSystemRadioButtonVisualState.hover;
    }

    return DesignSystemRadioButtonVisualState.idle;
  }
}

class _RadioButtonContent extends StatelessWidget {
  const _RadioButtonContent({
    required this.selected,
    required this.sizeSpec,
    required this.colorSpec,
    this.label,
    this.showTooltipIcon = false,
    this.tooltipMessage,
  });

  final bool selected;
  final _RadioButtonSizeSpec sizeSpec;
  final _RadioButtonColorSpec colorSpec;
  final String? label;
  final bool showTooltipIcon;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _RadioControl(
        sizeSpec: sizeSpec,
        colorSpec: colorSpec,
        selected: selected,
      ),
    ];

    if (label != null) {
      children
        ..add(SizedBox(width: sizeSpec.labelGap))
        ..add(
          Flexible(
            child: Text(
              label!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );

      if (showTooltipIcon) {
        children
          ..add(SizedBox(width: sizeSpec.tooltipGap))
          ..add(
            Tooltip(
              message: tooltipMessage ?? label!,
              child: const Icon(Icons.info_outline_rounded),
            ),
          );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _RadioControl extends StatelessWidget {
  const _RadioControl({
    required this.selected,
    required this.sizeSpec,
    required this.colorSpec,
  });

  final bool selected;
  final _RadioButtonSizeSpec sizeSpec;
  final _RadioButtonColorSpec colorSpec;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: sizeSpec.controlSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorSpec.controlBackgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorSpec.controlBorderColor,
            width: sizeSpec.controlBorderWidth,
          ),
        ),
        child: selected
            ? Center(
                child: SizedBox.square(
                  dimension: sizeSpec.selectedDotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorSpec.controlBorderColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _RadioButtonSizeSpec {
  const _RadioButtonSizeSpec({
    required this.controlSize,
    required this.labelGap,
    required this.tooltipGap,
    required this.controlBorderWidth,
    required this.selectedDotSize,
    required this.labelStyle,
    required this.tooltipIconSize,
  });

  factory _RadioButtonSizeSpec.fromTokens(
    DsTokens tokens,
    DesignSystemRadioButtonSize size,
  ) {
    return switch (size) {
      DesignSystemRadioButtonSize.defaultSize => _RadioButtonSizeSpec(
        controlSize:
            tokens.typography.lineHeight.caption + (tokens.spacing.step1 * 2),
        labelGap: tokens.spacing.step3,
        tooltipGap: tokens.spacing.step2,
        controlBorderWidth: tokens.spacing.step1 / 2,
        selectedDotSize: tokens.spacing.step3,
        labelStyle: tokens.typography.styles.body.bodySmall,
        tooltipIconSize: tokens.typography.lineHeight.caption,
      ),
      DesignSystemRadioButtonSize.large => _RadioButtonSizeSpec(
        controlSize:
            tokens.typography.lineHeight.subtitle2 + (tokens.spacing.step1 * 2),
        labelGap: tokens.spacing.step4,
        tooltipGap: tokens.spacing.step2,
        controlBorderWidth: tokens.spacing.step1 / 2,
        selectedDotSize: tokens.spacing.step4 - tokens.spacing.step1,
        labelStyle: tokens.typography.styles.body.bodyMedium,
        tooltipIconSize: tokens.typography.lineHeight.caption,
      ),
    };
  }

  final double controlSize;
  final double labelGap;
  final double tooltipGap;
  final double controlBorderWidth;
  final double selectedDotSize;
  final TextStyle labelStyle;
  final double tooltipIconSize;
}

class _RadioButtonColorSpec {
  const _RadioButtonColorSpec({
    required this.controlBackgroundColor,
    required this.controlBorderColor,
    required this.labelColor,
    required this.tooltipColor,
  });

  factory _RadioButtonColorSpec.fromTokens({
    required DsTokens tokens,
    required DesignSystemRadioButtonVisualState visualState,
  }) {
    final accentColor = switch (visualState) {
      DesignSystemRadioButtonVisualState.idle =>
        tokens.colors.alert.info.defaultColor,
      DesignSystemRadioButtonVisualState.hover =>
        tokens.colors.alert.info.hover,
    };

    return _RadioButtonColorSpec(
      controlBackgroundColor: tokens.colors.background.level01,
      controlBorderColor: accentColor,
      labelColor: tokens.colors.text.highEmphasis,
      tooltipColor: tokens.colors.text.mediumEmphasis,
    );
  }

  final Color controlBackgroundColor;
  final Color controlBorderColor;
  final Color labelColor;
  final Color tooltipColor;
}
