// The action bar's pill and round-button widgets — part of the
// task_action_bar library so they share the file-level glass-chip
// styling constants.
part of 'task_action_bar.dart';

/// Primary "Track time" pill.
///
/// Idle: stopwatch icon + localized label; the entire pill is one tap
/// target that starts a new timer.
///
/// Tracking-this-task: live-elapsed duration with the inset stop circle
/// on the leading edge. The pill body and the stop circle are
/// independent tap zones — tapping the body navigates to the running
/// timer entry (matching the sidebar timer card), tapping the stop
/// circle stops the timer.
class _TrackTimePill extends StatelessWidget {
  const _TrackTimePill({
    required this.isTracking,
    required this.label,
    required this.idleSemanticLabel,
    required this.navigateSemanticLabel,
    required this.stopSemanticLabel,
    required this.onStartTimer,
    required this.onNavigateToRunningEntry,
    required this.onStop,
    super.key,
  });

  final bool isTracking;
  final String label;
  final String idleSemanticLabel;
  final String navigateSemanticLabel;
  final String stopSemanticLabel;
  final VoidCallback onStartTimer;
  final VoidCallback onNavigateToRunningEntry;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    // Idle pill is translucent and floats over a backdrop-blurred glass
    // strip. Boosted alpha + hairline outline keep contrast over bright
    // underlying content without losing the glass aesthetic.
    final fillColor = isTracking
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.surface.focusPressed.withValues(
            alpha: _glassFillAlpha,
          );
    // The error palette has no dedicated on-color token — its
    // defaultColor is a vivid red across both themes, so a fixed white
    // foreground stays legible on top.
    final foreground = isTracking
        ? Colors.white
        : tokens.colors.text.highEmphasis;
    final pillRadius = BorderRadius.circular(tokens.radii.badgesPills);
    final textStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: foreground,
      // Tabular figures + slashed zero + cv02/03/04 (open 4/6/9),
      // matching the sidebar timer pill so elapsed digits don't shift
      // width as they tick.
      fontFeatures: numericBadgeFontFeatures,
    );
    final idleContentWidth =
        TaskActionBar.iconSize +
        spacing.step2 +
        _measureSingleLineTextWidth(
          context,
          idleSemanticLabel,
          textStyle,
        ) +
        spacing.step3;

    return Semantics(
      button: true,
      label: isTracking ? navigateSemanticLabel : idleSemanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: pillRadius,
          onTap: isTracking ? onNavigateToRunningEntry : onStartTimer,
          child: Container(
            height: TaskActionBar.buttonSize,
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: pillRadius,
            ),
            // foregroundDecoration paints on top of the child without
            // contributing to the Container's padding, so the hairline
            // outline stays a hairline and doesn't widen the pill (which
            // would otherwise push the action row past the layout
            // thresholds).
            foregroundDecoration: isTracking
                ? null
                : BoxDecoration(
                    borderRadius: pillRadius,
                    border: Border.all(
                      color: tokens.colors.decorative.level01.withValues(
                        alpha: _glassBorderAlpha,
                      ),
                    ),
                  ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: idleContentWidth),
              child: Center(
                widthFactor: 1,
                child: _TrackTimePillContent(
                  icon: isTracking
                      ? _PillStopButton(
                          onStop: onStop,
                          semanticLabel: stopSemanticLabel,
                        )
                      : Icon(
                          Icons.timer_outlined,
                          size: TaskActionBar.iconSize,
                          color: foreground,
                        ),
                  label: label,
                  textStyle: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _measureSingleLineTextWidth(
  BuildContext context,
  String text,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

class _TrackTimePillContent extends StatelessWidget {
  const _TrackTimePillContent({
    required this.icon,
    required this.label,
    required this.textStyle,
  });

  final Widget icon;
  final String label;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: spacing.step2),
        Padding(
          padding: EdgeInsets.only(right: spacing.step3),
          child: Text(
            label,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

/// Inset stop circle that lives on the leading edge of the running
/// pill. Its own [InkWell] absorbs the tap so it does not bubble up to
/// the pill body's navigate handler.
class _PillStopButton extends StatelessWidget {
  const _PillStopButton({
    required this.onStop,
    required this.semanticLabel,
  });

  final VoidCallback onStop;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        key: TaskActionBar.trackTimeStopKey,
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onStop,
          child: const SizedBox.square(
            dimension: TaskActionBar.pillStopButtonSize,
            child: Icon(
              Icons.stop_rounded,
              size: TaskActionBar.pillStopIconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon-only action button — the round affordances after the
/// Track time pill. [backgroundColor] / [iconColor] are optional
/// overrides; when null, the default surface-hover + high-emphasis
/// colors are used. The audio button passes the alert-error fill while
/// a recording session for the open task is active.
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Round buttons sit on a translucent glass strip; when no caller
    // override is supplied the chip uses the shared "glass chip"
    // styling (`_glassFillAlpha`, `_glassBorderAlpha`) so the
    // silhouette and glyph stay visible regardless of what's behind the
    // bar. Caller overrides (e.g. recording = solid red) already carry
    // their own contrast.
    final isTranslucent = backgroundColor == null;
    final defaultFill = tokens.colors.surface.focusPressed.withValues(
      alpha: _glassFillAlpha,
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: TaskActionBar.buttonSize,
            height: TaskActionBar.buttonSize,
            decoration: BoxDecoration(
              color: backgroundColor ?? defaultFill,
              shape: BoxShape.circle,
            ),
            // foregroundDecoration so the hairline outline doesn't eat
            // into the icon's content rect — keeps the icon centered
            // exactly the same as before the outline was added.
            foregroundDecoration: isTranslucent
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.colors.decorative.level01.withValues(
                        alpha: _glassBorderAlpha,
                      ),
                    ),
                  )
                : null,
            child: Icon(
              icon,
              size: TaskActionBar.iconSize,
              color: iconColor ?? tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}
