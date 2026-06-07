import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

part 'design_system_file_upload_item.dart';

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
            painter: DashedBorderPainter(
              color: borderColor,
              radius: spec.borderRadius,
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
