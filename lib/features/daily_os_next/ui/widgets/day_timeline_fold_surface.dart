import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Formats an absolute hour-of-day marker for the timeline rail and the
/// fold-region range labels, e.g. `08:00`. Hour `24` is the exclusive
/// end-of-day marker and renders as `24:00`; any other value is taken
/// modulo 24 so wrap-around inputs collapse onto a 24-hour clock.
String formatTimelineHourLabel(int hour) {
  final displayHour = hour == 24 ? 24 : hour % 24;
  return '${displayHour.toString().padLeft(2, '0')}:00';
}

class FoldRegionLayer extends StatelessWidget {
  const FoldRegionLayer({
    required this.foldingState,
    required this.pxPerMinute,
    required this.onToggleFoldRegion,
    super.key,
  });

  final TimelineFoldingState foldingState;
  final double pxPerMinute;
  final ValueChanged<int> onToggleFoldRegion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final region in foldingState.compressedRegions)
          Positioned(
            top: foldingState.positionForHour(region.startHour, pxPerMinute),
            left: 0,
            right: 0,
            height: region.height(pxPerMinute),
            child: _FoldRegionToggle(
              key: Key(
                'daily_os_timeline_fold_${region.startHour}_${region.endHour}',
              ),
              region: region,
              pxPerMinute: pxPerMinute,
              onTap: () => onToggleFoldRegion(region.startHour),
            ),
          ),
      ],
    );
  }
}

class _FoldRegionToggle extends StatelessWidget {
  const _FoldRegionToggle({
    required this.region,
    required this.pxPerMinute,
    required this.onTap,
    super.key,
  });

  final TimelineFoldRegion region;
  final double pxPerMinute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (!region.isExpanded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: _CompressedFoldSurface(
            region: region,
            label: _formatFoldRange(region),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02.withValues(
              alpha: region.isExpanded ? 0.10 : 0.32,
            ),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: tokens.colors.decorative.level01.withValues(
                  alpha: 0.28,
                ),
              ),
            ),
          ),
          child: Stack(
            children: [
              for (var i = 0; i <= region.hourCount; i++)
                Positioned(
                  top: i * region.hourHeight(pxPerMinute),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: tokens.spacing.step1 / 2,
                    color: tokens.colors.decorative.level01.withValues(
                      alpha: 0.10,
                    ),
                  ),
                ),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.background.level03.withValues(
                      alpha: 0.88,
                    ),
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                    border: Border.all(
                      color: tokens.colors.decorative.level01.withValues(
                        alpha: 0.32,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.unfold_less,
                        size: tokens.spacing.step3,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                      Text(
                        _formatFoldRange(region),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFoldRange(TimelineFoldRegion region) {
    // A fold region's start is always in [0, 23] and its end in [1, 24], so the
    // shared formatter reproduces the previous per-bound behaviour: the start
    // never hits the 24 special case, and the end renders 24 as `24:00`.
    return '${formatTimelineHourLabel(region.startHour)}-'
        '${formatTimelineHourLabel(region.endHour)}';
  }
}

class _CompressedFoldSurface extends StatelessWidget {
  const _CompressedFoldSurface({
    required this.region,
    required this.label,
  });

  final TimelineFoldRegion region;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return CustomPaint(
      painter: _CompressedFoldPainter(
        hourCount: region.hourCount,
        hourHeight: region.collapsedHourHeight,
        foldDepth: tokens.spacing.step3,
        strokeWidth: tokens.spacing.step1 / 2,
        frontColor: tokens.colors.background.level02.withValues(alpha: 0.22),
        backColor: tokens.colors.background.level02.withValues(alpha: 0.12),
        hourLineColor: tokens.colors.decorative.level01.withValues(alpha: 0.18),
        creaseColor: tokens.colors.decorative.level01.withValues(alpha: 0.26),
        spineColor: tokens.colors.text.lowEmphasis.withValues(alpha: 0.54),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level03.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            border: Border.all(
              color: tokens.colors.decorative.level01.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.unfold_more,
                size: tokens.spacing.step3,
                color: tokens.colors.text.lowEmphasis,
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompressedFoldPainter extends CustomPainter {
  const _CompressedFoldPainter({
    required this.hourCount,
    required this.hourHeight,
    required this.foldDepth,
    required this.strokeWidth,
    required this.frontColor,
    required this.backColor,
    required this.hourLineColor,
    required this.creaseColor,
    required this.spineColor,
  });

  final int hourCount;
  final double hourHeight;
  final double foldDepth;
  final double strokeWidth;
  final Color frontColor;
  final Color backColor;
  final Color hourLineColor;
  final Color creaseColor;
  final Color spineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final depth = math.min(foldDepth, size.width);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = backColor
        ..style = PaintingStyle.fill,
    );
    final hourLinePaint = Paint()
      ..color = hourLineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final creasePaint = Paint()
      ..color = creaseColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final spinePaint = Paint()
      ..color = spineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftSpinePath = Path()..moveTo(0, 0);
    final rightSpinePath = Path()..moveTo(size.width, 0);
    for (var i = 0; i < hourCount; i++) {
      final y0 = i * hourHeight;
      final y1 = math.min((i + 1) * hourHeight, size.height);
      final midY = (y0 + y1) / 2;
      const leftBase = 0.0;
      final leftPeak = depth;
      final rightBase = size.width;
      final rightPeak = size.width - depth;
      final panelPaint = Paint()
        ..color = i.isEven ? frontColor : backColor
        ..style = PaintingStyle.fill;
      final panelPath = Path()
        ..moveTo(leftBase, y0)
        ..lineTo(rightBase, y0)
        ..lineTo(rightPeak, midY)
        ..lineTo(rightBase, y1)
        ..lineTo(leftBase, y1)
        ..lineTo(leftPeak, midY)
        ..close();

      canvas
        ..drawPath(panelPath, panelPaint)
        ..drawLine(Offset(0, y0), Offset(size.width, y0), hourLinePaint)
        ..drawLine(Offset(leftBase, y0), Offset(leftPeak, midY), creasePaint)
        ..drawLine(Offset(leftPeak, midY), Offset(leftBase, y1), creasePaint)
        ..drawLine(Offset(rightBase, y0), Offset(rightPeak, midY), creasePaint)
        ..drawLine(Offset(rightPeak, midY), Offset(rightBase, y1), creasePaint);
      leftSpinePath
        ..lineTo(leftPeak, midY)
        ..lineTo(leftBase, y1);
      rightSpinePath
        ..lineTo(rightPeak, midY)
        ..lineTo(rightBase, y1);
    }

    canvas
      ..drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        hourLinePaint,
      )
      ..drawPath(leftSpinePath, spinePaint)
      ..drawPath(rightSpinePath, spinePaint);
  }

  @override
  bool shouldRepaint(covariant _CompressedFoldPainter oldDelegate) {
    return hourCount != oldDelegate.hourCount ||
        hourHeight != oldDelegate.hourHeight ||
        foldDepth != oldDelegate.foldDepth ||
        strokeWidth != oldDelegate.strokeWidth ||
        frontColor != oldDelegate.frontColor ||
        backColor != oldDelegate.backColor ||
        hourLineColor != oldDelegate.hourLineColor ||
        creaseColor != oldDelegate.creaseColor ||
        spineColor != oldDelegate.spineColor;
  }
}
