import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

/// The geometry one day track draws on: the column pitch, the square inside
/// each column, whether the weekday captions still fit at full length, and
/// how tall a caption row has to be.
///
/// The caption height rides along so a caption track does not re-measure
/// the same seven strings the pitch was already derived from.
typedef DayTrackMetrics = ({
  double pitch,
  double cellSize,
  bool narrowLabels,
  double labelHeight,
});

/// The widest and tallest weekday caption a track will paint.
///
/// Measured over the SEVEN distinct weekday names, not over the track's days:
/// a ninety-day span still draws only seven different strings, and laying out
/// one TextPainter per day put ninety layouts in the middle of `build` to
/// learn what seven already answer.
({double width, double height}) _weekdayLabelMetrics(BuildContext context) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final style = context.designTokens.typography.styles.others.caption;
  final format = DateFormat.E(locale);
  // Any seven consecutive days cover every weekday exactly once.
  final week = DateTime.utc(2024, 1, 8);
  var width = 0.0;
  var height = 0.0;
  for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
    final painter = TextPainter(
      text: TextSpan(
        text: format.format(week.add(Duration(days: offset))),
        style: style,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    width = math.max(width, painter.width);
    height = math.max(height, painter.height);
  }
  return (width: width, height: height);
}

/// The narrowest column a day is still legible in — a 12px square with a
/// hairline of air either side. Below this a track scrolls instead of
/// shrinking further.
double _minimumDayPitch(DsTokens tokens) => IconSizes.xs + tokens.spacing.step2;

/// The column pitch every day row on a page shares.
///
/// One pitch, one origin, one width: the whole-goal verdict strip, the habit
/// squares and the metric bars all draw the SAME week, and drawn on three
/// different grids the same Wednesday landed in three different places on one
/// scroll. A reader cannot follow a day across the page unless the columns
/// line up.
///
/// Wide enough for the weekday label at raised text scales, which is what
/// makes the axis readable rather than merely aligned — and, when
/// [availableWidth] is known, narrow enough that a span longer than a week
/// still FITS. A fourteen-day track at the authored pitch is wider than a
/// phone card, and the trailing-edge scroller that resulted opened with the
/// first days of the span cut in half off the left edge.
DayTrackMetrics dayTrackMetrics(
  BuildContext context, {
  required int dayCount,
  double? availableWidth,
}) {
  final tokens = context.designTokens;
  final defaultPitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
  final label = _weekdayLabelMetrics(context);
  final labelWidth = label.width;
  final expandedPitch = labelWidth + tokens.spacing.step1;
  final textScaledUp = MediaQuery.textScalerOf(context).scale(1) > 1;
  var pitch = textScaledUp && expandedPitch > defaultPitch
      ? expandedPitch
      : defaultPitch;
  if (availableWidth != null && availableWidth > 0 && dayCount > 0) {
    // Floored, so `pitch * days` can never round up past the width it was
    // derived from and reintroduce a one-pixel scroller.
    final fitted = (availableWidth / dayCount).floorToDouble();
    if (fitted < pitch) {
      pitch = math.max(fitted, _minimumDayPitch(tokens));
    }
  }
  return (
    pitch: pitch,
    labelHeight: math.max(IconSizes.s, label.height),
    // The square shrinks with its column, or neighbouring cells would touch
    // and the track would read as one bar — but it never GROWS past the
    // authored chip size: spreading the span means wider gutters between
    // same-sized nodes, not inflated squares.
    cellSize: math.min(
      ControlSizes.iconChipCompact,
      math.max(IconSizes.xs, pitch - tokens.spacing.step2),
    ),
    // "Mon" needs its own width; a SQUEEZED column takes the one-letter form
    // rather than letting neighbouring captions overlap into mush. Only a
    // squeezed one: at the authored pitch the captions are centered and
    // overhang their cell into the gap by design, which is the established
    // rendering and stays untouched.
    narrowLabels: pitch < defaultPitch && pitch < labelWidth,
  );
}

/// One horizontal scroller per extended day track, all linked through the
/// page's [LinkedScrollGroup] and anchored at the TRAILING edge
/// (`reverse: true`): a span longer than the viewport opens with TODAY on
/// screen, dragging any track moves every track, and because reversed
/// offsets measure from the trailing edge, the same date stays vertically
/// aligned across cards even where extents differ.
class LinkedDayTrackScroller extends StatefulWidget {
  const LinkedDayTrackScroller({required this.child, this.group, super.key});

  final LinkedScrollGroup? group;
  final Widget child;

  @override
  State<LinkedDayTrackScroller> createState() => _LinkedDayTrackScrollerState();
}

class _LinkedDayTrackScrollerState extends State<LinkedDayTrackScroller> {
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.group?.attach();
  }

  @override
  void didUpdateWidget(covariant LinkedDayTrackScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.group, widget.group)) {
      final old = _controller;
      if (old != null) oldWidget.group?.detach(old);
      _controller = widget.group?.attach();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) widget.group?.detach(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    reverse: true,
    controller: _controller,
    child: widget.child,
  );
}

/// A day track, panning only where it genuinely cannot fit.
///
/// ONE policy for every track — the whole-goal strip, the habit squares and
/// the metric bars. They each used to decide for themselves, and the strip
/// decided by day COUNT, so it wrapped a span that provably fitted in a
/// trailing-anchored scroller and opened it with the first days cut off.
Widget fitOrScrollDayTrack({
  required double contentWidth,
  required double availableWidth,
  required LinkedScrollGroup? group,
  required Widget child,
}) {
  if (contentWidth <= availableWidth) return child;
  // Trailing-anchored, and joined to the page's group: a span wider than the
  // viewport opens with today on screen, and every track pans together so the
  // same date stays aligned down the page.
  return LinkedDayTrackScroller(group: group, child: child);
}

/// One row of day slots on a shared column grid: every child is centered in
/// a slot exactly [pitch] wide, so tracks stacked on one page line up
/// column-for-column regardless of what each slot draws.
class DayTrack extends StatelessWidget {
  const DayTrack({
    required this.height,
    required this.pitch,
    required this.children,
    super.key,
  });

  final double height;
  final double pitch;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    // Slots span the full pitch, so adjacent hit regions touch without
    // overlapping — each editable cell gets the widest tap area the
    // authored density allows, and labels stay centered over their cells.
    final width = pitch * children.length;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < children.length; index++)
            Positioned(
              left: pitch * index,
              width: pitch,
              height: height,
              child: Center(child: children[index]),
            ),
        ],
      ),
    );
  }
}
