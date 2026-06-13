import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// Uploaded-file row for [DesignSystemFileUploadDropZone] result lists.

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
// Specs
// ──────────────────────────────────────────────────────────────

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
