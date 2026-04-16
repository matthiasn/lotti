import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// Visual constants that aren't backed by an exported design-system token.
// Kept here as named constants — callers should still prefer tokens for
// any value that has one. Revisit these if the design system gains
// equivalent tokens (alert.*.muted, toast min-height, etc.).

/// Minimum body height of the toast (icon + single-line title).
const double _toastMinHeight = 56;

/// Size of the leading tone icon (success / warning / error glyph).
const double _leadingIconSize = 20;

/// Tap target for the trailing dismiss button.
const double _dismissTapSize = 20;

/// Glyph size of the close icon inside the dismiss tap target.
const double _dismissIconSize = 16;

/// Splash radius for the dismiss [InkResponse].
const double _dismissInkRadius = 12;

/// Splash radius for the action [InkResponse].
const double _actionInkRadius = 24;

/// Padding around the action label.
const EdgeInsets _actionPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 4,
);

/// Height of the countdown progress strip.
const double _countdownBarMinHeight = 3;

/// Lerp amount used to lighten the success-tone stripe — derived purely
/// because no `alert.success.muted` token exists yet.
const double _successStripeLerpAmount = 0.2;

/// Alpha applied to the tone border colour for the countdown track.
const double _countdownTrackAlpha = 0.16;

enum DesignSystemToastTone {
  success,
  warning,
  error,
}

/// Trailing call-to-action attached to a [DesignSystemToast]. Renders
/// inline with the dismiss icon when both are supplied; otherwise sits
/// in the trailing slot on its own.
class ToastAction {
  const ToastAction({
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onPressed;

  /// Optional override for the underlying [Semantics] button label.
  /// Defaults to [label].
  final String? semanticsLabel;
}

class DesignSystemToast extends StatefulWidget {
  const DesignSystemToast({
    required this.tone,
    required this.title,
    this.description,
    this.action,
    this.onDismiss,
    this.dismissSemanticsLabel,
    this.countdownDuration,
    this.initialCountdownProgress = 1.0,
    super.key,
  });

  final DesignSystemToastTone tone;
  final String title;
  final String? description;
  final ToastAction? action;
  final VoidCallback? onDismiss;
  final String? dismissSemanticsLabel;

  /// When non-null, paints a thin tone-coloured progress strip along
  /// the top edge that drains from [initialCountdownProgress] to 0
  /// over [countdownDuration]. Used by undoable transient actions
  /// (e.g. checklist delete with a 5-second undo window).
  final Duration? countdownDuration;

  /// Starting value for the countdown bar (1.0 = full, 0.0 = empty).
  /// Useful when resuming a countdown that has already partially
  /// elapsed. Ignored when [countdownDuration] is null.
  final double initialCountdownProgress;

  @override
  State<DesignSystemToast> createState() => _DesignSystemToastState();
}

class _DesignSystemToastState extends State<DesignSystemToast>
    with SingleTickerProviderStateMixin {
  AnimationController? _countdown;

  @override
  void initState() {
    super.initState();
    _maybeStartCountdown();
  }

  @override
  void didUpdateWidget(covariant DesignSystemToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdownDuration != widget.countdownDuration ||
        oldWidget.initialCountdownProgress != widget.initialCountdownProgress) {
      _countdown?.dispose();
      _countdown = null;
      _maybeStartCountdown();
    }
  }

  void _maybeStartCountdown() {
    final duration = widget.countdownDuration;
    if (duration == null || duration <= Duration.zero) return;
    final initial = widget.initialCountdownProgress.clamp(0.0, 1.0);
    final controller = AnimationController(
      vsync: this,
      duration: duration,
      value: initial,
    )..reverse(from: initial);
    _countdown = controller;
  }

  @override
  void dispose() {
    _countdown?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ToastSpec.fromTokens(tokens, widget.tone);
    final descriptionText = widget.description?.trim();
    final hasDescription =
        descriptionText != null && descriptionText.isNotEmpty;
    final action = widget.action;
    final hasTrailing = action != null || widget.onDismiss != null;

    return Semantics(
      container: true,
      liveRegion: true,
      label: hasDescription
          ? '${widget.title}. $descriptionText'
          : widget.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(spec.radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: spec.backgroundColor,
            border: Border.all(color: spec.borderColor),
            borderRadius: BorderRadius.circular(spec.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_countdown != null)
                _ToastCountdownBar(
                  controller: _countdown!,
                  trackColor: spec.countdownTrackColor,
                  valueColor: spec.borderColor,
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _toastMinHeight),
                child: IntrinsicHeight(
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
                            // Two-line toasts top-align per Figma; single-line
                            // toasts read better centered in the 56px min box.
                            crossAxisAlignment: hasDescription
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: hasDescription
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      spec.leadingIcon,
                                      size: _leadingIconSize,
                                      color: spec.borderColor,
                                    ),
                                    SizedBox(width: tokens.spacing.step3),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: spec.titleStyle.copyWith(
                                              color: spec.titleColor,
                                            ),
                                          ),
                                          if (hasDescription) ...[
                                            SizedBox(
                                              height: tokens.spacing.step2,
                                            ),
                                            Text(
                                              descriptionText,
                                              // Allow two lines so verbose
                                              // translations (e.g. de_DE) don't
                                              // ellipsize off the second clause.
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: spec.descriptionStyle
                                                  .copyWith(
                                                    color:
                                                        spec.descriptionColor,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasTrailing) ...[
                                SizedBox(width: tokens.spacing.step5),
                                if (action != null)
                                  _ToastActionButton(
                                    label: action.label,
                                    semanticsLabel:
                                        action.semanticsLabel ?? action.label,
                                    color: spec.borderColor,
                                    style: spec.actionStyle,
                                    onPressed: action.onPressed,
                                  ),
                                if (action != null && widget.onDismiss != null)
                                  SizedBox(width: tokens.spacing.step3),
                                if (widget.onDismiss != null)
                                  _ToastDismissAction(
                                    iconColor: spec.dismissColor,
                                    semanticsLabel:
                                        widget.dismissSemanticsLabel ??
                                        MaterialLocalizations.of(
                                          context,
                                        ).cancelButtonLabel,
                                    onPressed: widget.onDismiss!,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastCountdownBar extends StatelessWidget {
  const _ToastCountdownBar({
    required this.controller,
    required this.trackColor,
    required this.valueColor,
  });

  final AnimationController controller;
  final Color trackColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LinearProgressIndicator(
          value: controller.value,
          minHeight: _countdownBarMinHeight,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(valueColor),
        );
      },
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({
    required this.label,
    required this.semanticsLabel,
    required this.color,
    required this.style,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final Color color;
  final TextStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: _actionInkRadius,
          child: Padding(
            padding: _actionPadding,
            child: Text(
              label,
              style: style.copyWith(color: color),
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
      // The parent Semantics(container: true) already announces the toast
      // body; excluding the icon here avoids a duplicate "Close" reading.
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: _dismissInkRadius,
          child: SizedBox(
            width: _dismissTapSize,
            height: _dismissTapSize,
            child: Icon(
              Icons.close_rounded,
              size: _dismissIconSize,
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
    required this.countdownTrackColor,
    required this.radius,
    required this.stripeWidth,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.actionStyle,
  });

  factory _ToastSpec.fromTokens(DsTokens tokens, DesignSystemToastTone tone) {
    final borderColor = switch (tone) {
      DesignSystemToastTone.success => tokens.colors.alert.success.defaultColor,
      DesignSystemToastTone.warning => tokens.colors.alert.warning.defaultColor,
      DesignSystemToastTone.error => tokens.colors.alert.error.defaultColor,
    };

    final stripeColor = switch (tone) {
      // Color.lerp returns non-null when both inputs are non-null, so the
      // bang is safe — the fallback would be unreachable.
      DesignSystemToastTone.success => Color.lerp(
        borderColor,
        Colors.white,
        _successStripeLerpAmount,
      )!,
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
      countdownTrackColor: borderColor.withValues(alpha: _countdownTrackAlpha),
      radius: tokens.radii.s,
      stripeWidth: tokens.spacing.step3,
      titleStyle: tokens.typography.styles.subtitle.subtitle2,
      descriptionStyle: tokens.typography.styles.others.caption,
      actionStyle: tokens.typography.styles.subtitle.subtitle2,
    );
  }

  final IconData leadingIcon;
  final Color backgroundColor;
  final Color borderColor;
  final Color stripeColor;
  final Color titleColor;
  final Color descriptionColor;
  final Color dismissColor;
  final Color countdownTrackColor;
  final double radius;
  final double stripeWidth;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final TextStyle actionStyle;
}
