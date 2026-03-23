import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemProgressBarStyle {
  defaultStyle,
  chunky,
}

class DesignSystemProgressBar extends StatelessWidget {
  const DesignSystemProgressBar({
    required this.value,
    this.style = DesignSystemProgressBarStyle.defaultStyle,
    this.label,
    this.progressText,
    this.trailingIcon,
    this.labelColor,
    this.progressColor,
    this.fillColor,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  }) : assert(
         (label != null && label != '') || semanticsLabel != null,
         'Provide either a visible label or a semanticsLabel.',
       );

  final double value;
  final DesignSystemProgressBarStyle style;
  final String? label;
  final String? progressText;
  final IconData? trailingIcon;
  final Color? labelColor;
  final Color? progressColor;
  final Color? fillColor;
  final Color? trackColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ProgressBarSpec.fromTokens(
      tokens,
      style,
      labelColor: labelColor,
      progressColor: progressColor,
      fillColor: fillColor,
      trackColor: trackColor,
    );
    final clampedValue = value.clamp(0.0, 1.0);
    final showHeader =
        label?.isNotEmpty == true ||
        progressText?.isNotEmpty == true ||
        trailingIcon != null;

    return Semantics(
      container: true,
      label: semanticsLabel ?? label,
      value:
          semanticsValue ?? progressText ?? '${(clampedValue * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _ProgressBarHeader(
              label: label,
              progressText: progressText,
              trailingIcon: trailingIcon,
              spec: spec,
            ),
            SizedBox(height: spec.headerSpacing),
          ],
          _ProgressBarTrack(
            value: clampedValue,
            spec: spec,
          ),
        ],
      ),
    );
  }
}

class _ProgressBarHeader extends StatelessWidget {
  const _ProgressBarHeader({
    required this.spec,
    this.label,
    this.progressText,
    this.trailingIcon,
  });

  final _ProgressBarSpec spec;
  final String? label;
  final String? progressText;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final trailingChildren = <Widget>[
      if (trailingIcon != null)
        Icon(
          trailingIcon,
          size: spec.iconSize,
          color: spec.progressColor,
        ),
      if (progressText?.isNotEmpty == true)
        Text(
          progressText!,
          style: spec.headerTextStyle.copyWith(color: spec.progressColor),
        ),
    ];

    final trailing = trailingChildren.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: trailingChildren
                .intersperse(SizedBox(width: spec.trailingContentGap))
                .toList(),
          );

    return SizedBox(
      height: spec.headerHeight,
      child: Row(
        children: [
          if (label?.isNotEmpty == true)
            Expanded(
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: spec.headerTextStyle.copyWith(color: spec.labelColor),
              ),
            ),
          if (label?.isNotEmpty != true && trailing != null) const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _ProgressBarTrack extends StatelessWidget {
  const _ProgressBarTrack({
    required this.value,
    required this.spec,
  });

  final double value;
  final _ProgressBarSpec spec;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: spec.trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: spec.trackColor),
          borderRadius: BorderRadius.circular(spec.trackRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(spec.trackInset),
          child: switch (spec.style) {
            DesignSystemProgressBarStyle.defaultStyle => _DefaultTrackFill(
              value: value,
              spec: spec,
            ),
            DesignSystemProgressBarStyle.chunky => _ChunkyTrackFill(
              value: value,
              spec: spec,
            ),
          },
        ),
      ),
    );
  }
}

class _DefaultTrackFill extends StatelessWidget {
  const _DefaultTrackFill({
    required this.value,
    required this.spec,
  });

  final double value;
  final _ProgressBarSpec spec;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * value;

        return Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(spec.fillRadius),
            child: SizedBox(
              width: fillWidth,
              height: spec.fillHeight,
              child: ColoredBox(color: spec.fillColor),
            ),
          ),
        );
      },
    );
  }
}

class _ChunkyTrackFill extends StatelessWidget {
  const _ChunkyTrackFill({
    required this.value,
    required this.spec,
  });

  final double value;
  final _ProgressBarSpec spec;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalGap = spec.segmentGap * (spec.segmentCount - 1);
        final segmentWidth =
            (constraints.maxWidth - totalGap) / spec.segmentCount;

        final segments = List.generate(
          spec.segmentCount,
          (index) => SizedBox(
            width: segmentWidth,
            height: spec.fillHeight,
            child: _ChunkySegment(
              fillFraction: _segmentFillFraction(index),
              isFirst: index == 0,
              isLast: index == spec.segmentCount - 1,
              spec: spec,
            ),
          ),
        );

        return Row(
          children: segments
              .intersperse(SizedBox(width: spec.segmentGap))
              .toList(),
        );
      },
    );
  }

  double _segmentFillFraction(int index) {
    final start = index / spec.segmentCount;
    final end = (index + 1) / spec.segmentCount;

    if (value <= start) {
      return 0;
    }
    if (value >= end) {
      return 1;
    }

    return (value - start) * spec.segmentCount;
  }
}

class _ChunkySegment extends StatelessWidget {
  const _ChunkySegment({
    required this.fillFraction,
    required this.isFirst,
    required this.isLast,
    required this.spec,
  });

  final double fillFraction;
  final bool isFirst;
  final bool isLast;
  final _ProgressBarSpec spec;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: isFirst ? Radius.circular(spec.fillRadius) : Radius.zero,
      right: isLast ? Radius.circular(spec.fillRadius) : Radius.zero,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: spec.trackColor),
          if (fillFraction > 0)
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fillFraction,
              heightFactor: 1,
              child: ColoredBox(color: spec.fillColor),
            ),
        ],
      ),
    );
  }
}

class _ProgressBarSpec {
  const _ProgressBarSpec({
    required this.style,
    required this.headerTextStyle,
    required this.labelColor,
    required this.progressColor,
    required this.fillColor,
    required this.trackColor,
    required this.headerHeight,
    required this.headerSpacing,
    required this.trackHeight,
    required this.trackRadius,
    required this.trackInset,
    required this.fillHeight,
    required this.fillRadius,
    required this.iconSize,
    required this.trailingContentGap,
    required this.segmentCount,
    required this.segmentGap,
  });

  factory _ProgressBarSpec.fromTokens(
    DsTokens tokens,
    DesignSystemProgressBarStyle style, {
    Color? labelColor,
    Color? progressColor,
    Color? fillColor,
    Color? trackColor,
  }) {
    return _ProgressBarSpec(
      style: style,
      headerTextStyle: tokens.typography.styles.body.bodyMedium,
      labelColor: labelColor ?? tokens.colors.text.mediumEmphasis,
      progressColor: progressColor ?? tokens.colors.text.highEmphasis,
      fillColor: fillColor ?? tokens.colors.interactive.enabled,
      trackColor: trackColor ?? tokens.colors.decorative.level01,
      headerHeight: tokens.typography.lineHeight.bodyMedium,
      headerSpacing: tokens.spacing.step3,
      trackHeight: tokens.spacing.step5,
      trackRadius: tokens.spacing.step3,
      trackInset: 3,
      fillHeight: 8,
      fillRadius: tokens.spacing.step3,
      iconSize: tokens.typography.lineHeight.subtitle2,
      trailingContentGap: tokens.spacing.step1,
      segmentCount: 5,
      segmentGap: tokens.spacing.step1,
    );
  }

  final DesignSystemProgressBarStyle style;
  final TextStyle headerTextStyle;
  final Color labelColor;
  final Color progressColor;
  final Color fillColor;
  final Color trackColor;
  final double headerHeight;
  final double headerSpacing;
  final double trackHeight;
  final double trackRadius;
  final double trackInset;
  final double fillHeight;
  final double fillRadius;
  final double iconSize;
  final double trailingContentGap;
  final int segmentCount;
  final double segmentGap;
}
