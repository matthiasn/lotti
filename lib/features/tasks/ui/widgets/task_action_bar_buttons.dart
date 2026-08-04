// The action bar's Track time pill widgets. The pill is the bar's single
// primary and carries a solid `interactive.enabled` fill; the round
// affordances beside it use `DsGlassRoundButton` and the shared glass-chip
// styling from `glass_action_bar.dart`.
import 'package:flutter/material.dart';
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
    // The bar's one primary. Idle it carries the interactive accent as a
    // solid fill; the round affordances beside it stay on the translucent
    // glass chip. Sharing that chip made all five controls the same weight —
    // a row of equal grey lozenges with nothing leading it, and (in light
    // theme) the heaviest ink on an otherwise near-white page.
    final fillColor = isTracking
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.interactive.enabled;
    // The error palette has no dedicated on-color token — its
    // defaultColor is a vivid red across both themes, so a fixed white
    // foreground stays legible on top. The interactive accent does have
    // one: `text.onInteractiveAlert`.
    final foreground = isTracking
        ? Colors.white
        : tokens.colors.text.onInteractiveAlert;
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

/// Labeled "Add" trigger for the action bar, on a tonal pill treatment.
///
/// The bare "+" circle was the page's most prominent creation control and
/// the one that broke the page's own glyph grammar: everywhere else "+"
/// means creates-in-place, while this one opens the Add sheet. A label
/// resolves the lie the way the sheet's own title does — trigger and
/// destination say the same word. The bar renders this pill wherever the
/// row has width for it and falls back to the bare circle only below the
/// narrow-width threshold.
class AddMenuPill extends StatelessWidget {
  const AddMenuPill({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.tooltip,
    super.key,
  });

  /// Leading glyph. The full-sheet "Add" wears the plus; the first-run
  /// "Attach" wears the paperclip, because on this page "+" is the
  /// commits-immediately glyph and this trigger opens a sheet.
  final IconData icon;
  final String label;

  /// Optional long-form scent: names what the sheet actually holds, so a
  /// pointer hover (or assistive tech) can route between the card and the
  /// sheet BEFORE the tap. The visible label stays the one word the sheet
  /// titles itself with.
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    // Tonal surface fill, quiet border, neutral high-emphasis ink: the bar
    // keeps a single accent budget, spent on the Track time primary.
    final style = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    final pill = Semantics(
      button: true,
      label: tooltip ?? label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Container(
            height: TaskActionBar.buttonSize,
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            decoration: BoxDecoration(
              color: tokens.colors.surface.enabled,
              borderRadius: radius,
              border: Border.all(color: tokens.colors.decorative.level02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: TaskActionBar.iconSize,
                  color: tokens.colors.text.highEmphasis,
                ),
                SizedBox(width: spacing.step2),
                Text(label, style: style),
                SizedBox(width: spacing.step2),
                // The opens-further-UI marker, in the exact caret grammar
                // the Open/Medium chips use for "tap reveals options". The
                // page teaches that a plain glyph+word commits immediately;
                // this trigger opens a sheet and must say so from the
                // pixels — the tooltip never surfaces on touch.
                Icon(
                  Icons.expand_more_rounded,
                  size: TaskActionBar.iconSize,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return pill;
    // The Semantics above already carries the long label; without the
    // exclusion the tooltip would announce it a second time.
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: pill,
    );
  }
}
