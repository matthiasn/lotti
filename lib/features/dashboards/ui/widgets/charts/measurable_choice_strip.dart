import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurable_choice_series.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The colour of each choice of [dataType], keyed by choice id.
///
/// The user's own order is the only structure a choice set has, so it is
/// read as an ordinal scale: one hue — the accent — stepped from faint to
/// full across the list (index over **every** choice, archived ones
/// included, so a retired choice keeps the colour its history was drawn
/// in). Both ends are existing tokens; the steps between are computed, not
/// authored, which is what keeps a five-choice ramp from needing five new
/// colour tokens. A choice the definition no longer knows draws in the
/// neutral decorative step.
Map<String, Color> choiceColorsFor(
  MeasurableDataType dataType,
  DsTokens tokens,
) {
  final choices = dataType.choices ?? const <MeasurableChoice>[];
  final faint = tokens.colors.background.level03;
  final full = tokens.colors.interactive.enabled;
  return {
    for (final (index, choice) in choices.indexed)
      choice.id: Color.lerp(faint, full, (index + 1) / choices.length)!,
  };
}

/// One cell per day of the range, coloured by the day's latest choice, under
/// the same left inset as the bar and line charts so the shared date axis
/// reads across it. Hovering or long-pressing a recorded day names the date
/// and the choice.
///
/// The cells are painted, not laid out: a dashboard range runs to a year,
/// and a row of one flex child per day with fixed gaps between them is wider
/// than a phone long before that. [ChoiceStripPainter] fits the range to
/// whatever width it gets and drops the gaps once a cell would be narrower
/// than one, at which point neighbouring days of the same choice merge into
/// one run — the strip stays a picture of the range at every width.
class MeasurableChoiceStrip extends StatefulWidget {
  const MeasurableChoiceStrip({
    required this.days,
    required this.dataType,
    super.key,
  });

  final List<ChoiceDay> days;
  final MeasurableDataType dataType;

  @override
  State<MeasurableChoiceStrip> createState() => _MeasurableChoiceStripState();
}

class _MeasurableChoiceStripState extends State<MeasurableChoiceStrip> {
  /// The day under the pointer, for the tooltip; `null` off the strip.
  int? _pointerIndex;

  void _trackPointer(Offset local, double width) {
    final days = widget.days;
    if (days.isEmpty || width <= 0) return;
    final index = (local.dx / width * days.length).floor().clamp(
      0,
      days.length - 1,
    );
    if (index != _pointerIndex) setState(() => _pointerIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final colors = choiceColorsFor(widget.dataType, tokens);
    final days = widget.days;
    final index = _pointerIndex;
    final hovered = index != null && index < days.length ? days[index] : null;
    final String? message;
    if (hovered?.choiceId case final choiceId?) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final title =
          widget.dataType.choiceById(choiceId)?.title ??
          messages.measurableChoiceNotFound;
      message = '${DateFormat.yMMMd(locale).format(hovered!.day)} · $title';
    } else {
      message = null;
    }

    return Padding(
      padding: const EdgeInsets.only(left: kChartLeftAxisWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final strip = Listener(
            onPointerHover: (event) =>
                _trackPointer(event.localPosition, width),
            onPointerDown: (event) => _trackPointer(event.localPosition, width),
            child: CustomPaint(
              key: const ValueKey('measurable-choice-strip'),
              painter: ChoiceStripPainter(
                colors: [
                  for (final day in days)
                    if (day.choiceId case final choiceId?)
                      colors[choiceId] ?? tokens.colors.decorative.level02
                    else
                      tokens.colors.background.level03,
                ],
                gap: tokens.spacing.step1,
                radius: tokens.radii.xs,
              ),
              child: const SizedBox.expand(),
            ),
          );
          // One tooltip for the whole strip, worded for the day under the
          // pointer; an empty day has nothing to say, so no tooltip at all.
          if (message == null) return strip;
          return Tooltip(
            key: const ValueKey('measurable-choice-strip-tooltip'),
            message: message,
            child: strip,
          );
        },
      ),
    );
  }
}

/// Paints [colors] as equal-width cells across the canvas: [gap] between
/// cells while a cell is at least that wide, otherwise contiguous, with
/// same-coloured neighbours drawn as one run so no seams appear.
class ChoiceStripPainter extends CustomPainter {
  const ChoiceStripPainter({
    required this.colors,
    required this.gap,
    required this.radius,
  });

  final List<Color> colors;
  final double gap;
  final double radius;

  /// The gap actually drawn at [width]: [gap], or none when a cell would be
  /// narrower than it.
  double gapFor(double width) {
    final n = colors.length;
    if (n < 2) return 0;
    final cell = (width - gap * (n - 1)) / n;
    return cell >= gap ? gap : 0;
  }

  /// The width of one cell at [width] (never negative).
  double cellWidthFor(double width) {
    final n = colors.length;
    if (n == 0) return 0;
    return math.max(0, (width - gapFor(width) * (n - 1)) / n);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = colors.length;
    if (n == 0 || size.isEmpty) return;
    final drawnGap = gapFor(size.width);
    final cell = cellWidthFor(size.width);
    final stride = cell + drawnGap;
    final paint = Paint();
    var start = 0;
    while (start < n) {
      // With gaps every cell is its own rect; without, a run of one colour
      // is one rect so anti-aliasing draws no hairlines between its days.
      var end = start + 1;
      if (drawnGap == 0) {
        while (end < n && colors[end] == colors[start]) {
          end++;
        }
      }
      final left = start * stride;
      final right = (end - 1) * stride + cell;
      final rect = Rect.fromLTRB(left, 0, right, size.height);
      final corner = Radius.circular(math.min(radius, rect.width / 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, corner),
        paint..color = colors[start],
      );
      start = end;
    }
  }

  @override
  bool shouldRepaint(ChoiceStripPainter old) =>
      old.gap != gap || old.radius != radius || !_sameColors(old.colors);

  bool _sameColors(List<Color> other) {
    if (other.length != colors.length) return false;
    for (var i = 0; i < colors.length; i++) {
      if (other[i] != colors[i]) return false;
    }
    return true;
  }
}

/// The strip's key: every active choice in order, plus any retired choice
/// that still colours a day in [days], each as a swatch and its title.
class MeasurableChoiceLegend extends StatelessWidget {
  const MeasurableChoiceLegend({
    required this.days,
    required this.dataType,
    super.key,
  });

  final List<ChoiceDay> days;
  final MeasurableDataType dataType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = choiceColorsFor(dataType, tokens);
    final shown = {for (final day in days) day.choiceId};
    final entries = [
      for (final choice in dataType.choices ?? const <MeasurableChoice>[])
        if (choice.archived != true || shown.contains(choice.id)) choice,
    ];
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: kChartLeftAxisWidth,
        top: tokens.spacing.step2,
      ),
      child: Wrap(
        spacing: tokens.spacing.step3,
        runSpacing: tokens.spacing.step1,
        children: [
          for (final choice in entries)
            Row(
              key: ValueKey('choice-legend-${choice.id}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors[choice.id],
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                  ),
                  child: SizedBox.square(dimension: tokens.spacing.step3),
                ),
                SizedBox(width: tokens.spacing.step1),
                Text(choice.title, style: captionStyle),
              ],
            ),
        ],
      ),
    );
  }
}
