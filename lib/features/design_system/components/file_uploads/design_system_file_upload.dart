import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// ──────────────────────────────────────────────────────────────
// Drop zone
// ──────────────────────────────────────────────────────────────

/// Visual state of the drop zone for forced preview (e.g. widgetbook).
enum DesignSystemFileUploadDropZoneVisualState {
  idle,
  hover,
  disabled,
}

/// A dashed-border drop zone that invites the user to upload a file.
class DesignSystemFileUploadDropZone extends StatefulWidget {
  const DesignSystemFileUploadDropZone({
    required this.clickToUploadLabel,
    required this.dragAndDropLabel,
    required this.hintText,
    this.onTap,
    this.forcedState,
    this.semanticsLabel,
    super.key,
  });

  final String clickToUploadLabel;
  final String dragAndDropLabel;
  final String hintText;
  final VoidCallback? onTap;
  final DesignSystemFileUploadDropZoneVisualState? forcedState;
  final String? semanticsLabel;

  @override
  State<DesignSystemFileUploadDropZone> createState() =>
      _DesignSystemFileUploadDropZoneState();
}

class _DesignSystemFileUploadDropZoneState
    extends State<DesignSystemFileUploadDropZone> {
  bool _hovered = false;

  DesignSystemFileUploadDropZoneVisualState _resolveVisualState() {
    if (widget.forcedState != null) return widget.forcedState!;
    if (widget.onTap == null) {
      return DesignSystemFileUploadDropZoneVisualState.disabled;
    }
    if (_hovered) return DesignSystemFileUploadDropZoneVisualState.hover;
    return DesignSystemFileUploadDropZoneVisualState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _DropZoneSpec.fromTokens(tokens);
    final visualState = _resolveVisualState();
    final enabled = widget.onTap != null;

    final backgroundColor = switch (visualState) {
      DesignSystemFileUploadDropZoneVisualState.idle => Colors.transparent,
      DesignSystemFileUploadDropZoneVisualState.hover =>
        tokens.colors.surface.enabled,
      DesignSystemFileUploadDropZoneVisualState.disabled => Colors.transparent,
    };

    final borderColor = switch (visualState) {
      DesignSystemFileUploadDropZoneVisualState.disabled =>
        tokens.colors.decorative.level01,
      _ => tokens.colors.decorative.level02,
    };

    final iconColor = switch (visualState) {
      DesignSystemFileUploadDropZoneVisualState.disabled =>
        tokens.colors.text.lowEmphasis,
      _ => tokens.colors.interactive.enabled,
    };

    final linkColor = switch (visualState) {
      DesignSystemFileUploadDropZoneVisualState.disabled =>
        tokens.colors.text.lowEmphasis,
      _ => tokens.colors.interactive.enabled,
    };

    final textColor = switch (visualState) {
      DesignSystemFileUploadDropZoneVisualState.disabled =>
        tokens.colors.text.lowEmphasis,
      _ => tokens.colors.text.mediumEmphasis,
    };

    return Semantics(
      button: enabled,
      label: widget.semanticsLabel,
      child: MouseRegion(
        onEnter: widget.forcedState == null && enabled
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.forcedState == null && enabled
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: borderColor,
              borderRadius: spec.borderRadius,
              strokeWidth: spec.borderWidth,
              dashLength: spec.dashLength,
              dashGap: spec.dashGap,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(spec.borderRadius),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: spec.horizontalPadding,
                vertical: spec.verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: spec.iconSize,
                    color: iconColor,
                  ),
                  SizedBox(height: spec.iconSpacing),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.clickToUploadLabel,
                          style: spec.linkStyle.copyWith(color: linkColor),
                        ),
                        TextSpan(
                          text: ' ${widget.dragAndDropLabel}',
                          style: spec.bodyStyle.copyWith(color: textColor),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spec.hintSpacing),
                  Text(
                    widget.hintText,
                    style: spec.hintStyle.copyWith(color: textColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// File item
// ──────────────────────────────────────────────────────────────

/// Status of an individual file in the upload list.
enum DesignSystemFileUploadItemStatus {
  uploading,
  complete,
  error,
}

/// An individual file row showing upload progress, completion, or error.
class DesignSystemFileUploadItem extends StatelessWidget {
  const DesignSystemFileUploadItem({
    required this.fileName,
    required this.fileSize,
    required this.status,
    this.progress = 0,
    this.errorLabel,
    this.retryLabel,
    this.onCancel,
    this.onRetry,
    this.semanticsLabel,
    super.key,
  });

  final String fileName;
  final String fileSize;
  final DesignSystemFileUploadItemStatus status;
  final double progress;
  final String? errorLabel;
  final String? retryLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _FileItemSpec.fromTokens(tokens);

    final isError = status == DesignSystemFileUploadItemStatus.error;

    final borderColor = isError
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.decorative.level01;

    final backgroundColor = isError
        ? tokens.colors.alert.error.defaultColor.withValues(alpha: 0.08)
        : tokens.colors.surface.enabled;

    final iconColor = isError
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.interactive.enabled;

    return Semantics(
      container: true,
      label: semanticsLabel ?? fileName,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(spec.borderRadius),
        ),
        padding: EdgeInsets.all(spec.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upload_file,
                  size: spec.fileIconSize,
                  color: iconColor,
                ),
                SizedBox(width: spec.iconGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: spec.fileNameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fileSize,
                        style: spec.fileSizeStyle,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spec.iconGap),
                _buildTrailingAction(tokens, spec),
              ],
            ),
            if (!isError) ...[
              SizedBox(height: spec.progressSpacing),
              Row(
                children: [
                  Expanded(
                    child: DesignSystemProgressBar(
                      value: progress,
                      semanticsLabel: fileName,
                    ),
                  ),
                  SizedBox(width: spec.iconGap),
                  Text(
                    '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                    style: spec.percentageStyle,
                  ),
                ],
              ),
            ],
            if (isError) ...[
              SizedBox(height: spec.progressSpacing),
              Row(
                children: [
                  if (errorLabel != null)
                    Text(
                      errorLabel!,
                      style: spec.errorLabelStyle,
                    ),
                  if (retryLabel != null) ...[
                    SizedBox(width: spec.iconGap),
                    GestureDetector(
                      onTap: onRetry,
                      child: Text(
                        retryLabel!,
                        style: spec.retryLabelStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingAction(DsTokens tokens, _FileItemSpec spec) {
    return switch (status) {
      DesignSystemFileUploadItemStatus.uploading => GestureDetector(
        onTap: onCancel,
        child: Icon(
          Icons.cancel_outlined,
          size: spec.actionIconSize,
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
      DesignSystemFileUploadItemStatus.complete => Icon(
        Icons.check_circle,
        size: spec.actionIconSize,
        color: tokens.colors.alert.success.defaultColor,
      ),
      DesignSystemFileUploadItemStatus.error => GestureDetector(
        onTap: onRetry,
        child: Icon(
          Icons.refresh,
          size: spec.actionIconSize,
          color: tokens.colors.alert.error.defaultColor,
        ),
      ),
    };
  }
}

// ──────────────────────────────────────────────────────────────
// Dashed border painter
// ──────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      dashGap != oldDelegate.dashGap;
}

// ──────────────────────────────────────────────────────────────
// Specs
// ──────────────────────────────────────────────────────────────

class _DropZoneSpec {
  const _DropZoneSpec({
    required this.borderRadius,
    required this.borderWidth,
    required this.dashLength,
    required this.dashGap,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.iconSpacing,
    required this.hintSpacing,
    required this.linkStyle,
    required this.bodyStyle,
    required this.hintStyle,
  });

  factory _DropZoneSpec.fromTokens(DsTokens tokens) {
    return _DropZoneSpec(
      borderRadius: tokens.radii.s,
      borderWidth: 1.5,
      dashLength: 6,
      dashGap: 4,
      horizontalPadding: tokens.spacing.step7,
      verticalPadding: tokens.spacing.step6,
      iconSize: tokens.spacing.step7,
      iconSpacing: tokens.spacing.step3,
      hintSpacing: tokens.spacing.step1,
      linkStyle: tokens.typography.styles.body.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyStyle: tokens.typography.styles.body.bodySmall,
      hintStyle: tokens.typography.styles.others.caption,
    );
  }

  final double borderRadius;
  final double borderWidth;
  final double dashLength;
  final double dashGap;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double iconSpacing;
  final double hintSpacing;
  final TextStyle linkStyle;
  final TextStyle bodyStyle;
  final TextStyle hintStyle;
}

class _FileItemSpec {
  const _FileItemSpec({
    required this.borderRadius,
    required this.padding,
    required this.fileIconSize,
    required this.actionIconSize,
    required this.iconGap,
    required this.progressSpacing,
    required this.fileNameStyle,
    required this.fileSizeStyle,
    required this.percentageStyle,
    required this.errorLabelStyle,
    required this.retryLabelStyle,
  });

  factory _FileItemSpec.fromTokens(DsTokens tokens) {
    return _FileItemSpec(
      borderRadius: tokens.radii.s,
      padding: tokens.spacing.step4,
      fileIconSize: tokens.spacing.step6,
      actionIconSize: tokens.spacing.step6,
      iconGap: tokens.spacing.step3,
      progressSpacing: tokens.spacing.step3,
      fileNameStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.highEmphasis,
        fontWeight: FontWeight.w600,
      ),
      fileSizeStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      percentageStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      errorLabelStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.alert.error.defaultColor,
      ),
      retryLabelStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.alert.error.defaultColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  final double borderRadius;
  final double padding;
  final double fileIconSize;
  final double actionIconSize;
  final double iconGap;
  final double progressSpacing;
  final TextStyle fileNameStyle;
  final TextStyle fileSizeStyle;
  final TextStyle percentageStyle;
  final TextStyle errorLabelStyle;
  final TextStyle retryLabelStyle;
}
