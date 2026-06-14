import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';

/// "Pick one of N" time-span selector for the Insights dashboards and the
/// Habits page.
///
/// Renders with the shared [DsSegmentedToggle] so the time-frame switch speaks
/// the same visual language as the Daily OS plan switch and the Time Analysis
/// chart-mode toggle. This widget just maps the integer day spans to labelled
/// segments ("30d", "90d", …) so both pages share one mapping.
class TimeSpanSegmentedControl extends StatelessWidget {
  const TimeSpanSegmentedControl({
    required this.timeSpanDays,
    required this.onValueChanged,
    this.segments = const [30, 90, 180, 365],
    super.key,
  });

  final int timeSpanDays;
  final void Function(int) onValueChanged;
  final List<int> segments;

  @override
  Widget build(BuildContext context) {
    return DsSegmentedToggle<int>(
      segments: [
        for (final days in segments) DsSegment(days, '${days}d'),
      ],
      selected: timeSpanDays,
      onChanged: onValueChanged,
    );
  }
}
