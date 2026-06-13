// The action bar's Track time pill widgets. Glass-chip fill/outline
// styling comes from the shared `glass_action_bar.dart` helpers
// (`dsGlassChipFill` / `dsGlassChipBorder`); the round affordances use
// `DsGlassRoundButton`.
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

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
class TrackTimePill extends StatelessWidget {
  const TrackTimePill({
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
        : dsGlassChipFill(tokens);
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
                    border: dsGlassChipBorder(tokens),
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
