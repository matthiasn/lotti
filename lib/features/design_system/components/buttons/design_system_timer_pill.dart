import 'dart:math' as math;

import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart' show formatDuration;
import 'package:material_ui/material_ui.dart';

/// The app's one running-clock control: a pill that is the accent "start"
/// idle and turns the alert red while its clock runs, with the elapsed time
/// in tabular figures and an inset stop circle on its leading edge.
///
/// A task's *Track time* and the voice recorder's Stop are this one
/// element, so a running clock looks and stops the same wherever it runs.
///
/// Idle ([running] false): [idleIcon] and [label], the whole pill one tap
/// target ([onTap]). Running: the stop circle and [label] — the elapsed
/// time. The body and the circle are separate tap zones; where both stop
/// the clock, leave [stopSemanticLabel] null and the circle is part of the
/// one button rather than a second one.
class DesignSystemTimerPill extends StatelessWidget {
  const DesignSystemTimerPill({
    required this.running,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    required this.onStop,
    this.semanticValue,
    this.stopSemanticLabel,
    this.idleIcon = LottiIcons.timer,
    this.widthLabel,
    this.stopKey = defaultStopKey,
    super.key,
  });

  /// The inset stop circle, unless the host names its own.
  static const Key defaultStopKey = ValueKey('design-system-timer-pill-stop');

  /// The idle glyph's size.
  static const double iconSize = 20;

  /// The widest elapsed time under an hour, for [widthLabel]: with tabular
  /// figures every digit is as wide as `0`.
  static const String elapsedWidthTemplate = '00:00';

  /// Elapsed time as the pill shows it: `mm:ss` under an hour, `hh:mm:ss`
  /// from then on.
  static String formatElapsed(Duration elapsed) {
    if (elapsed >= const Duration(hours: 1)) return formatDuration(elapsed);
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  final bool running;

  /// The elapsed time while running; the action's name while idle.
  final String label;

  /// What a screen reader hears for the pill's body.
  final String semanticLabel;

  /// What it hears after that, such as the elapsed time in words.
  final String? semanticValue;

  /// The body's tap; null holds the whole pill inert.
  final VoidCallback? onTap;

  /// The stop circle's tap; null holds it inert.
  final VoidCallback? onStop;

  /// The stop circle's own name, when it is a button of its own.
  final String? stopSemanticLabel;

  final IconData idleIcon;

  /// The longest label the pill keeps its width for, so it holds still as
  /// it changes — the idle action's name, so it does not shrink when it
  /// starts, or the widest time it will show; [label] when null.
  final String? widthLabel;

  final Key stopKey;

  /// The pill's width around [label] in its idle layout — the width it
  /// holds to — so a host can lay out beside it before it is built.
  static double heldWidth(BuildContext context, String label) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    return spacing.step5 * 2 +
        iconSize +
        spacing.step2 +
        _singleLineWidth(context, label, _labelStyle(tokens, _onRunning)) +
        spacing.step3;
  }

  static TextStyle _labelStyle(DsTokens tokens, Color color) =>
      tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: color,
        // Tabular figures, slashed zero and open 4/6/9, matching the
        // sidebar timer, so elapsed digits never shift width as they tick.
        fontFeatures: numericBadgeFontFeatures,
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final fillColor = running
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.interactive.enabled;
    // The error palette has no on-colour token of its own; the light
    // theme's ink for alert fills (white) marks the running clock in both
    // themes — the dark theme's is near-black, which on its lighter red
    // read as a hole, not a control. The interactive accent does have
    // one: `text.onInteractiveAlert`.
    final foreground = running
        ? _onRunning
        : tokens.colors.text.onInteractiveAlert;
    final pillRadius = BorderRadius.circular(tokens.radii.badgesPills);
    final textStyle = _labelStyle(tokens, foreground);
    // The pill's width is held to its idle layout around [widthLabel], so
    // it never shrinks when it starts nor grows as the time ticks.
    final minWidth = heldWidth(context, widthLabel ?? label);

    // The circle's inset from the round end: the same as from the top and
    // bottom.
    final circleInset = (spacing.step9 - spacing.step7) / 2;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      value: semanticValue,
      excludeSemantics: stopSemanticLabel == null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: pillRadius,
          onTap: onTap,
          child: Container(
            height: spacing.step9,
            // Running spends the idle layout's room differently — the
            // circle's concentric inset and the circle where the idle inset
            // and glyph sit, then step3 to the time and the pill's own
            // step5 after it — so
            // a time as wide as the held label fills the pill exactly with
            // the circle concentric in the round end, and more room keeps
            // circle and time together, centred.
            padding: EdgeInsets.only(
              left: running ? circleInset : spacing.step5,
              right: spacing.step5,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: pillRadius,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(
                  0,
                  minWidth -
                      (running ? circleInset : spacing.step5) -
                      spacing.step5,
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (running)
                      _StopCircle(
                        key: stopKey,
                        onStop: onStop,
                        semanticLabel: stopSemanticLabel,
                      )
                    else
                      Icon(idleIcon, size: iconSize, color: foreground),
                    SizedBox(
                      width: running ? spacing.step3 : spacing.step2,
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        right: running ? 0 : spacing.step3,
                      ),
                      child: ExcludeSemantics(
                        child: Text(label, style: textStyle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ink on the running pill's red, in either theme.
final Color _onRunning = dsTokensLight.colors.text.onInteractiveAlert;

double _singleLineWidth(BuildContext context, String text, TextStyle style) {
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

/// The inset stop circle on the running pill's leading edge. Its own
/// [InkWell] takes the tap, so it never reaches the body's.
class _StopCircle extends StatelessWidget {
  const _StopCircle({
    required this.onStop,
    required this.semanticLabel,
    super.key,
  });

  final VoidCallback? onStop;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final circle = Material(
      // The ink's own lift on the red: a translucent disc, not a second
      // colour.
      color: _onRunning.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onStop,
        child: SizedBox.square(
          dimension: spacing.step7,
          // Filled: the outlined square read as an empty checkbox on the
          // red pill, not as the stop control it is.
          child: Icon(
            LottiIconsFilled.square,
            size: IconSizes.m,
            color: _onRunning,
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return circle;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: circle,
    );
  }
}
