import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemCircularProgressSize {
  small,
  medium,
  large,
}

/// The design-system's determinate ring progress indicator.
///
/// Fills an arc proportional to [value] (clamped to 0–1) at one of
/// [DesignSystemCircularProgressSize], with optional [center] content inside the
/// ring. [progressColor]/[trackColor] override the token defaults; an
/// accessible [semanticsLabel] and [semanticsValue] (defaulting to a percentage)
/// are exposed via [Semantics].
class DesignSystemCircularProgress extends StatelessWidget {
  const DesignSystemCircularProgress({
    required this.value,
    this.size = DesignSystemCircularProgressSize.medium,
    this.center,
    this.progressColor,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  });

  final double value;
  final DesignSystemCircularProgressSize size;
  final Widget? center;
  final Color? progressColor;
  final Color? trackColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _CircularProgressSpec.fromTokens(tokens, size);
    final clampedValue = value.clamp(0.0, 1.0);
    final resolvedProgressColor =
        progressColor ?? tokens.colors.interactive.enabled;
    final resolvedTrackColor = trackColor ?? tokens.colors.decorative.level01;

    return Semantics(
      container: true,
      label: semanticsLabel,
      value: semanticsValue ?? '${(clampedValue * 100).round()}%',
      child: SizedBox.square(
        dimension: spec.dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: spec.dimension,
              child: CircularProgressIndicator(
                value: clampedValue,
                strokeWidth: spec.strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: resolvedTrackColor,
                valueColor: AlwaysStoppedAnimation(resolvedProgressColor),
              ),
            ),
            if (center != null)
              DefaultTextStyle.merge(
                style: spec.centerTextStyle.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                child: center!,
              ),
          ],
        ),
      ),
    );
  }
}

class _CircularProgressSpec {
  const _CircularProgressSpec({
    required this.dimension,
    required this.strokeWidth,
    required this.centerTextStyle,
  });

  factory _CircularProgressSpec.fromTokens(
    DsTokens tokens,
    DesignSystemCircularProgressSize size,
  ) {
    return switch (size) {
      DesignSystemCircularProgressSize.small => _CircularProgressSpec(
        dimension: tokens.spacing.step9,
        strokeWidth: 4,
        centerTextStyle: tokens.typography.styles.subtitle.subtitle2,
      ),
      DesignSystemCircularProgressSize.medium => _CircularProgressSpec(
        dimension: tokens.spacing.step10,
        strokeWidth: 5,
        centerTextStyle: tokens.typography.styles.subtitle.subtitle1,
      ),
      DesignSystemCircularProgressSize.large => _CircularProgressSpec(
        dimension: tokens.spacing.step11,
        strokeWidth: 6,
        centerTextStyle: tokens.typography.styles.heading.heading3,
      ),
    };
  }

  final double dimension;
  final double strokeWidth;
  final TextStyle centerTextStyle;
}
