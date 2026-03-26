import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemToastTone {
  success,
  warning,
  error,
}

class DesignSystemToast extends StatelessWidget {
  const DesignSystemToast({
    required this.tone,
    required this.title,
    required this.description,
    this.onDismiss,
    this.dismissSemanticsLabel,
    super.key,
  });

  final DesignSystemToastTone tone;
  final String title;
  final String description;
  final VoidCallback? onDismiss;
  final String? dismissSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ToastSpec.fromTokens(tokens, tone);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $description',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(spec.radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: spec.backgroundColor,
            border: Border.all(color: spec.borderColor),
            borderRadius: BorderRadius.circular(spec.radius),
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: spec.stripeWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          spec.stripeColor,
                          spec.stripeColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.step3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: tokens.spacing.step1,
                                ),
                                child: Icon(
                                  spec.leadingIcon,
                                  size: 20,
                                  color: spec.borderColor,
                                ),
                              ),
                              SizedBox(width: tokens.spacing.step3),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: spec.titleStyle.copyWith(
                                        color: spec.titleColor,
                                      ),
                                    ),
                                    SizedBox(height: tokens.spacing.step2),
                                    Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: spec.descriptionStyle.copyWith(
                                        color: spec.descriptionColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onDismiss != null) ...[
                          SizedBox(width: tokens.spacing.step5),
                          _ToastDismissAction(
                            iconColor: spec.dismissColor,
                            semanticsLabel:
                                dismissSemanticsLabel ??
                                MaterialLocalizations.of(
                                  context,
                                ).cancelButtonLabel,
                            onPressed: onDismiss!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastDismissAction extends StatelessWidget {
  const _ToastDismissAction({
    required this.iconColor,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final Color iconColor;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: 12,
          child: SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastSpec {
  const _ToastSpec({
    required this.leadingIcon,
    required this.backgroundColor,
    required this.borderColor,
    required this.stripeColor,
    required this.titleColor,
    required this.descriptionColor,
    required this.dismissColor,
    required this.radius,
    required this.stripeWidth,
    required this.titleStyle,
    required this.descriptionStyle,
  });

  factory _ToastSpec.fromTokens(DsTokens tokens, DesignSystemToastTone tone) {
    final borderColor = switch (tone) {
      DesignSystemToastTone.success => tokens.colors.alert.success.defaultColor,
      DesignSystemToastTone.warning => tokens.colors.alert.warning.defaultColor,
      DesignSystemToastTone.error => tokens.colors.alert.error.defaultColor,
    };

    final stripeColor = switch (tone) {
      DesignSystemToastTone.success =>
        Color.lerp(borderColor, Colors.white, 0.2) ?? borderColor,
      DesignSystemToastTone.warning => borderColor,
      DesignSystemToastTone.error => borderColor,
    };

    return _ToastSpec(
      leadingIcon: switch (tone) {
        DesignSystemToastTone.success => Icons.check_circle_rounded,
        DesignSystemToastTone.warning => Icons.warning_rounded,
        DesignSystemToastTone.error => Icons.error_rounded,
      },
      backgroundColor: tokens.colors.background.level02,
      borderColor: borderColor,
      stripeColor: stripeColor,
      titleColor: tokens.colors.text.highEmphasis,
      descriptionColor: tokens.colors.text.mediumEmphasis,
      dismissColor: tokens.colors.text.highEmphasis,
      radius: tokens.radii.s,
      stripeWidth: tokens.spacing.step3,
      titleStyle: tokens.typography.styles.subtitle.subtitle2,
      descriptionStyle: tokens.typography.styles.others.caption,
    );
  }

  final IconData leadingIcon;
  final Color backgroundColor;
  final Color borderColor;
  final Color stripeColor;
  final Color titleColor;
  final Color descriptionColor;
  final Color dismissColor;
  final double radius;
  final double stripeWidth;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
}
