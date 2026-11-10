import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One stretch of the [DayCapacityBar]: a share of the day in [color].
@immutable
class DayCapacitySegment {
  const DayCapacitySegment({
    required this.color,
    required this.minutes,
    required this.label,
  });

  final Color color;
  final int minutes;

  /// What the segment is, for its tooltip ("Deep work · 3h 30m").
  final String label;
}

/// How full the day is, in one thin line: [segments] laid end to end over a
/// `decorative.level01` track, each as wide as its share of
/// [capacityMinutes]; the rest of the track is what is still free.
///
/// Honest when over: segments that add up to more than the capacity fill
/// the whole bar, scaled to their own total, so the bar never claims room
/// the day does not have — the caption beside it says by how much. With no
/// capacity the segments also fill the bar, as a mix rather than a measure.
/// Segments of no minutes take no room.
///
/// A `step2`-tall line at `radii.xs`. Each segment carries its [DayCapacitySegment.label] as a
/// tooltip; the bar as a whole is one semantics node, [semanticsLabel].
class DayCapacityBar extends StatelessWidget {
  const DayCapacityBar({
    required this.segments,
    required this.capacityMinutes,
    this.semanticsLabel,
    super.key,
  });

  final List<DayCapacitySegment> segments;
  final int capacityMinutes;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final shown = [
      for (final segment in segments)
        if (segment.minutes > 0) segment,
    ];
    final total = shown.fold<int>(0, (sum, s) => sum + s.minutes);
    final free = capacityMinutes - total;
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          child: ColoredBox(
            color: tokens.colors.decorative.level01,
            child: SizedBox(
              height: tokens.spacing.step2,
              child: Row(
                // Segments are bare colour with no child of their own, so the
                // line's height has to be handed to them.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, segment) in shown.indexed)
                    Expanded(
                      key: ValueKey('daily_os_capacity_segment_$index'),
                      flex: segment.minutes,
                      child: Tooltip(
                        message: segment.label,
                        child: ColoredBox(color: segment.color),
                      ),
                    ),
                  if (free > 0) Spacer(flex: free),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
