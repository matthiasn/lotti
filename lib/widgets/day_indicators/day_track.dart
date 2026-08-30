import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

/// The geometry one day track draws on: the column pitch, whether the weekday
/// captions still fit at full length, and how tall a caption row has to be.
/// The square inside each column is always [daySquareSize] for the window.
///
/// The caption height rides along so a caption track does not re-measure
/// the same seven strings the pitch was already derived from.
typedef DayTrackMetrics = ({
  double pitch,
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

/// The column pitch every day row on a page shares: one day square and
/// `step2` of air — the handover's 3px gap on an 11px square, at the nearest
/// tokens.
///
/// One pitch, one origin, one width: the whole-goal verdict strip, the habit
/// squares and the metric bars all draw the SAME week, and drawn on three
/// different grids the same Wednesday landed in three different places on one
/// scroll. A reader cannot follow a day across the page unless the columns
/// line up.
///
/// The square never sizes to its content — the handover draws one square,
/// one size up on a desktop window (see [daySquareSize]) — so a span that
/// does not fit its width scrolls (see [fitOrScrollDayTrack]) rather than
/// shrinking. At raised text scales the pitch widens to hold the weekday
/// caption, which is what keeps the axis readable rather than merely aligned.
DayTrackMetrics dayTrackMetrics(BuildContext context) {
  final tokens = context.designTokens;
  final defaultPitch = daySquareSize(context) + tokens.spacing.step2;
  final label = _weekdayLabelMetrics(context);
  final labelWidth = label.width;
  final expandedPitch = labelWidth + tokens.spacing.step2;
  final textScaledUp = MediaQuery.textScalerOf(context).scale(1) > 1;
  final pitch = textScaledUp && expandedPitch > defaultPitch
      ? expandedPitch
      : defaultPitch;
  return (
    pitch: pitch,
    labelHeight: math.max(IconSizes.s, label.height),
    // "Mon" does not fit a 16px column; the captions take the one-letter
    // form unless the pitch has been widened past the full caption.
    narrowLabels: pitch < labelWidth,
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
