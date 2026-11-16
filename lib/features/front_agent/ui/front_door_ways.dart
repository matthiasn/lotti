import 'dart:math' as math;

import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One way an inbox item can go: what it becomes ([label]), what choosing
/// it does ([hint]), and the choosing itself.
class FrontDoorWay {
  const FrontDoorWay({
    required this.name,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.suggested = false,
    this.inFlight = false,
  });

  /// The way's name in its row's key: `front-door-<name>-<index>`.
  final String name;
  final String label;
  final String hint;
  final IconData icon;

  /// Null while the item's action is in flight: the row is not offered.
  final VoidCallback? onTap;

  /// Whether this is the router's guess: the one tinted row, tagged
  /// *Suggested*, which says so in place of its [hint].
  final bool suggested;

  /// Whether this is the way that was taken and is being done: its row
  /// shows progress where its glyph was, and stays at full strength while
  /// the others step back.
  final bool inFlight;
}

/// The ways an inbox item's card lists for the ways she [picked] for its
/// words, by name; null when she picked none, and every way is offered.
typedef FrontDoorWaysFor = List<FrontDoorWay> Function(List<String>? picked);

/// What an inbox item's card gives the `InboxWays` of its surface to draw
/// its list from: which ways go with the ones she picked ([waysFor]) and
/// the way out. The catalog stays static; what a way does comes from here.
class FrontDoorWaysScope extends InheritedWidget {
  const FrontDoorWaysScope({
    required this.index,
    required this.waysFor,
    required this.leave,
    required super.child,
    super.key,
  });

  final int index;
  final FrontDoorWaysFor waysFor;
  final FrontDoorWay leave;

  static FrontDoorWaysScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FrontDoorWaysScope>();
    assert(scope != null, 'An InboxWays is drawn in a FrontDoorWaysScope');
    return scope!;
  }

  /// The ways are built anew with every card: a row's tap, and whether it
  /// takes one, are never yesterday's.
  @override
  bool updateShouldNotify(FrontDoorWaysScope oldWidget) => true;
}

/// The ways an inbox item can go, as its card's choices: one list of rows
/// of one height, every way in sight, a tap on a row doing it.
///
/// The router's guess ([FrontDoorWay.suggested]) is the one tinted row,
/// tagged *Suggested*; every other way is a neutral row that says under its
/// name what choosing it does. [leave], the way that makes nothing, is no
/// row: a quiet button under the list, so it never competes with the ways.
class FrontDoorWays extends StatelessWidget {
  const FrontDoorWays({
    required this.index,
    required this.ways,
    required this.leave,
    super.key,
  });

  /// The item's segment index, which its rows' keys carry.
  final int index;
  final List<FrontDoorWay> ways;
  final FrontDoorWay leave;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // While one way is being done the others step back, the way out too.
    final busy = ways.any((way) => way.inFlight) || leave.inFlight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (position, way) in ways.indexed) ...[
          if (position > 0) SizedBox(height: tokens.spacing.step2),
          _WayRow(way: way, index: index, dimmed: busy && !way.inFlight),
        ],
        SizedBox(height: tokens.spacing.step2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            key: ValueKey('front-door-${leave.name}-$index'),
            label: leave.label,
            variant: DesignSystemButtonVariant.quiet,
            isLoading: leave.inFlight,
            // A thumb's target, as the rows over it have.
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: leave.onTap,
          ),
        ),
      ],
    );
  }
}

/// One way as a row of the list: its glyph, its name, and under it what
/// choosing it does — or, for the router's guess, the tint, the outline
/// and the *Suggested* tag in place of that line. Every row has the height
/// of two lines, so the guess stands no shorter than the rest.
class _WayRow extends StatelessWidget {
  const _WayRow({required this.way, required this.index, required this.dimmed});

  final FrontDoorWay way;
  final int index;

  /// Whether another way is being done: this one steps back.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final lines = tokens.typography.lineHeight;
    final scaler = MediaQuery.textScalerOf(context);
    final suggested = way.suggested;
    final tag = context.messages.frontDoorSuggested;
    final radius = BorderRadius.circular(tokens.radii.m);
    final accent = tokens.colors.interactive.enabled;
    // Grows with the text, short of crowding its row.
    final glyphSize = math.min(scaler.scale(IconSizes.m), IconSizes.l);
    return Semantics(
      key: ValueKey('front-door-${way.name}-$index'),
      button: true,
      enabled: way.onTap != null,
      // The guess is said, not only tinted.
      label: suggested ? '${way.label}. $tag' : '${way.label}. ${way.hint}',
      onTap: way.onTap,
      child: ExcludeSemantics(
        child:
            Material(
              type: MaterialType.transparency,
              child: Ink(
                key: ValueKey('front-door-${way.name}-row-$index'),
                decoration: BoxDecoration(
                  color: suggested
                      ? DesignSystemListPalette.activatedFill(tokens)
                      : tokens.colors.surface.enabled,
                  borderRadius: radius,
                  // Every row keeps the outline's room, so none is a hair
                  // smaller than the tinted one.
                  border: Border.all(
                    color: suggested ? accent : Colors.transparent,
                  ),
                ),
                child: InkWell(
                  onTap: way.onTap,
                  borderRadius: radius,
                  hoverColor: DesignSystemListPalette.hoverFill(tokens),
                  highlightColor: DesignSystemListPalette.pressedFill(tokens),
                  focusColor: tokens.colors.surface.focusPressed,
                  splashFactory: NoSplash.splashFactory,
                  child: ConstrainedBox(
                    // Two lines of text — a name and what it does — whether or
                    // not this row has the second.
                    constraints: BoxConstraints(
                      minHeight:
                          tokens.spacing.step3 * 2 +
                          scaler.scale(lines.subtitle2 + lines.caption),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.step4,
                        vertical: tokens.spacing.step3,
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: glyphSize,
                            child: way.inFlight
                                ? DesignSystemSpinner(
                                    key: ValueKey(
                                      'front-door-${way.name}-progress-$index',
                                    ),
                                    style: DesignSystemSpinnerStyle.plain,
                                    size: glyphSize,
                                    color: accent,
                                  )
                                : Icon(
                                    way.icon,
                                    size: glyphSize,
                                    color: suggested
                                        ? accent
                                        : tokens.colors.text.highEmphasis,
                                  ),
                          ),
                          SizedBox(width: tokens.spacing.step4),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  way.label,
                                  style: styles.subtitle.subtitle2.copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                  ),
                                ),
                                if (!suggested)
                                  Text(
                                    way.hint,
                                    style: styles.others.caption.copyWith(
                                      color: tokens.colors.text.mediumEmphasis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (suggested) ...[
                            SizedBox(width: tokens.spacing.step3),
                            // The interactive colour filled, under the ink a filled
                            // button wears on it: the design system's badge has the
                            // alert tones only.
                            DecoratedBox(
                              key: ValueKey(
                                'front-door-${way.name}-tag-$index',
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(
                                  tokens.radii.s,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: tokens.spacing.step3,
                                  vertical: tokens.spacing.step1,
                                ),
                                child: Text(
                                  tag,
                                  style: styles.others.caption.copyWith(
                                    color:
                                        tokens.colors.text.onInteractiveAlert,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).withDisabledOpacity(
              enabled: !dimmed,
              disabledOpacity: tokens.colors.text.lowEmphasis.a,
            ),
      ),
    );
  }
}
