import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemCheckboxVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemCheckbox extends StatefulWidget {
  const DesignSystemCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         (label != null && label != '') || semanticsLabel != null,
         'Provide either a visible label or a semanticsLabel.',
       );

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final String? semanticsLabel;
  final DesignSystemCheckboxVisualState? forcedState;

  @override
  State<DesignSystemCheckbox> createState() => _DesignSystemCheckboxState();
}

class _DesignSystemCheckboxState extends State<DesignSystemCheckbox> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        (oldWidget.onChanged == null) != (widget.onChanged == null);

    if (interactionModeChanged) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onChanged != null;
    final visualState = _resolveVisualState(enabled);
    final sizeSpec = _CheckboxSizeSpec.fromTokens(tokens);
    final styleSpec = _CheckboxStyleSpec.fromTokens(
      tokens: tokens,
      enabled: enabled,
      value: widget.value,
      visualState: visualState,
    );
    final showTransientGlyph =
        enabled &&
        widget.value == false &&
        visualState != DesignSystemCheckboxVisualState.idle;
    final glyphColor = widget.value == false
        ? styleSpec.borderColor
        : styleSpec.glyphColor;

    final checkbox = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: enabled ? _handleTap : null,
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
          child: MergeSemantics(
            child: Semantics(
              checked: widget.value == true,
              mixed: widget.value == null,
              enabled: enabled,
              label: widget.semanticsLabel ?? widget.label,
              onTap: enabled ? _handleTap : null,
              child: DefaultTextStyle.merge(
                style: sizeSpec.labelStyle.copyWith(
                  color: styleSpec.labelColor,
                ),
                child: _CheckboxContent(
                  label: widget.label,
                  gap: sizeSpec.itemGap,
                  boxSize: sizeSpec.checkboxSize,
                  borderRadius: sizeSpec.cornerRadius,
                  fillColor: styleSpec.backgroundColor,
                  borderColor: styleSpec.borderColor,
                  glyphColor: glyphColor,
                  glyphSize: sizeSpec.glyphSize,
                  glyphStrokeWidth: sizeSpec.glyphStrokeWidth,
                  showGlyph: widget.value != false || showTransientGlyph,
                  value: widget.value,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return checkbox.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  void _handleTap() {
    widget.onChanged?.call(widget.value != true);
  }

  DesignSystemCheckboxVisualState _resolveVisualState(bool enabled) {
    if (!enabled) {
      return DesignSystemCheckboxVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }
    if (_pressed) {
      return DesignSystemCheckboxVisualState.pressed;
    }
    if (_hovered) {
      return DesignSystemCheckboxVisualState.hover;
    }
    return DesignSystemCheckboxVisualState.idle;
  }
}

class _CheckboxContent extends StatelessWidget {
  const _CheckboxContent({
    required this.gap,
    required this.boxSize,
    required this.borderRadius,
    required this.fillColor,
    required this.borderColor,
    required this.glyphColor,
    required this.glyphSize,
    required this.glyphStrokeWidth,
    required this.showGlyph,
    required this.value,
    this.label,
  });

  final String? label;
  final double gap;
  final double boxSize;
  final double borderRadius;
  final Color fillColor;
  final Color borderColor;
  final Color glyphColor;
  final double glyphSize;
  final double glyphStrokeWidth;
  final bool showGlyph;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SizedBox(
        width: boxSize,
        height: boxSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: glyphStrokeWidth,
            ),
          ),
          child: showGlyph
              ? Center(
                  child: SizedBox.square(
                    dimension: glyphSize,
                    child: CustomPaint(
                      painter: _CheckboxGlyphPainter(
                        color: glyphColor,
                        strokeWidth: glyphStrokeWidth,
                        isMixed: value == null,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    ];

    if (label != null) {
      children
        ..add(SizedBox(width: gap))
        ..add(
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _CheckboxSizeSpec {
  const _CheckboxSizeSpec({
    required this.checkboxSize,
    required this.glyphSize,
    required this.glyphStrokeWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.cornerRadius,
    required this.labelStyle,
  });

  factory _CheckboxSizeSpec.fromTokens(DsTokens tokens) {
    final checkboxSize =
        tokens.typography.lineHeight.caption + tokens.spacing.step2;
    final glyphStrokeWidth = tokens.spacing.step1;
    final glyphSize = checkboxSize - (tokens.spacing.step1 * 2);

    return _CheckboxSizeSpec(
      checkboxSize: checkboxSize,
      glyphSize: glyphSize,
      glyphStrokeWidth: glyphStrokeWidth,
      horizontalPadding: tokens.spacing.step1,
      verticalPadding: tokens.spacing.step1,
      itemGap: tokens.spacing.step2,
      cornerRadius: tokens.radii.xs,
      labelStyle: tokens.typography.styles.body.bodySmall,
    );
  }

  final double checkboxSize;
  final double glyphSize;
  final double glyphStrokeWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double cornerRadius;
  final TextStyle labelStyle;
}

class _CheckboxStyleSpec {
  const _CheckboxStyleSpec({
    required this.backgroundColor,
    required this.borderColor,
    required this.glyphColor,
    required this.labelColor,
  });

  factory _CheckboxStyleSpec.fromTokens({
    required DsTokens tokens,
    required bool enabled,
    required bool? value,
    required DesignSystemCheckboxVisualState visualState,
  }) {
    final selectedTone = switch (visualState) {
      DesignSystemCheckboxVisualState.idle => tokens.colors.interactive.enabled,
      DesignSystemCheckboxVisualState.hover => tokens.colors.interactive.hover,
      DesignSystemCheckboxVisualState.pressed =>
        tokens.colors.interactive.pressed,
    };
    final surfaceTone = switch (visualState) {
      DesignSystemCheckboxVisualState.idle => tokens.colors.background.level01,
      DesignSystemCheckboxVisualState.hover => tokens.colors.surface.hover,
      DesignSystemCheckboxVisualState.pressed =>
        tokens.colors.surface.focusPressed,
    };
    final selected = value != false;
    final fillColor = selected ? selectedTone : surfaceTone;
    final borderColor = selected
        ? selectedTone
        : switch (visualState) {
            DesignSystemCheckboxVisualState.idle =>
              tokens.colors.text.mediumEmphasis,
            DesignSystemCheckboxVisualState.hover =>
              tokens.colors.interactive.enabled,
            DesignSystemCheckboxVisualState.pressed =>
              tokens.colors.interactive.pressed,
          };

    return _CheckboxStyleSpec(
      backgroundColor: enabled ? fillColor : tokens.colors.background.level02,
      borderColor: enabled ? borderColor : tokens.colors.text.lowEmphasis,
      glyphColor: tokens.colors.text.onInteractiveAlert,
      labelColor: tokens.colors.text.highEmphasis,
    );
  }

  final Color backgroundColor;
  final Color borderColor;
  final Color glyphColor;
  final Color labelColor;
}

class _CheckboxGlyphPainter extends CustomPainter {
  const _CheckboxGlyphPainter({
    required this.color,
    required this.strokeWidth,
    required this.isMixed,
  });

  final Color color;
  final double strokeWidth;
  final bool isMixed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (isMixed) {
      canvas.drawLine(
        Offset(size.width * 0.2, size.height / 2),
        Offset(size.width * 0.8, size.height / 2),
        paint,
      );
      return;
    }

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.75)
      ..lineTo(size.width * 0.8, size.height * 0.28);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckboxGlyphPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isMixed != isMixed;
  }
}
