import 'package:flutter/material.dart';
import 'package:lotti/utils/segmented_button.dart';

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
    final shortLabels = MediaQuery.of(context).size.width < 450;

    ButtonSegment<int> segment(int days) {
      return buttonSegment(
        context: context,
        value: days,
        selected: timeSpanDays,
        label: shortLabels ? '${days}d' : '$days days',
      );
    }

    return SegmentedButton<int>(
      selected: {timeSpanDays},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onValueChanged(selected.first),
      segments: [
        ...segments.map(segment),
      ],
    );
  }
}
