import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemCaptionIconPosition {
  none,
  left,
  top,
}

class DesignSystemCaption extends StatelessWidget {
  const DesignSystemCaption({
    required this.title,
    required this.description,
    this.iconPosition = DesignSystemCaptionIconPosition.none,
    this.icon,
    this.iconColor,
    this.primaryAction,
    this.secondaryAction,
    this.semanticsLabel,
    super.key,
  }) : assert(
         iconPosition == DesignSystemCaptionIconPosition.none || icon != null,
         'An icon must be provided when iconPosition is not none.',
       );

  final String title;
  final String description;
  final DesignSystemCaptionIconPosition iconPosition;
  final IconData? icon;
  final Color? iconColor;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _CaptionSpec.fromTokens(tokens);

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: spec.backgroundColor,
          border: Border.all(
            color: spec.borderColor,
          ),
          borderRadius: BorderRadius.circular(spec.borderRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(spec.padding),
          child: switch (iconPosition) {
            DesignSystemCaptionIconPosition.none => _buildContent(spec),
            DesignSystemCaptionIconPosition.left => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(spec),
                SizedBox(width: spec.gap),
                Expanded(child: _buildContent(spec)),
              ],
            ),
            DesignSystemCaptionIconPosition.top => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(spec),
                SizedBox(height: spec.gap),
                _buildContent(spec),
              ],
            ),
          },
        ),
      ),
    );
  }

  Widget _buildIcon(_CaptionSpec spec) {
    return Icon(
      icon,
      size: spec.iconSize,
      color: iconColor ?? spec.iconDefaultColor,
    );
  }

  Widget _buildContent(_CaptionSpec spec) {
    final hasActions = primaryAction != null || secondaryAction != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: spec.titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: spec.textGap),
        Text(
          description,
          style: spec.descriptionStyle,
        ),
        if (hasActions) ...[
          SizedBox(height: spec.gap),
          Wrap(
            alignment: WrapAlignment.end,
            runAlignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spec.actionGap,
            runSpacing: spec.textGap,
            children: [
              ?secondaryAction,
              ?primaryAction,
            ],
          ),
        ],
      ],
    );
  }
}

class _CaptionSpec {
  const _CaptionSpec({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderRadius,
    required this.padding,
    required this.gap,
    required this.textGap,
    required this.actionGap,
    required this.iconSize,
    required this.iconDefaultColor,
    required this.titleStyle,
    required this.descriptionStyle,
  });

  factory _CaptionSpec.fromTokens(DsTokens tokens) {
    return _CaptionSpec(
      backgroundColor: tokens.colors.surface.enabled,
      borderColor: tokens.colors.text.highEmphasis.withValues(alpha: 0.12),
      borderRadius: tokens.radii.s,
      padding: tokens.spacing.step5,
      gap: tokens.spacing.step5,
      textGap: tokens.spacing.step2,
      actionGap: tokens.spacing.step3,
      iconSize: tokens.spacing.step6,
      iconDefaultColor: tokens.colors.interactive.enabled,
      titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      descriptionStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }

  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double padding;
  final double gap;
  final double textGap;
  final double actionGap;
  final double iconSize;
  final Color iconDefaultColor;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
}
