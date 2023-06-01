import 'package:flutter/material.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/utils/segmented_button.dart';

class TimeSpanSegmentedControl extends StatelessWidget {
  const TimeSpanSegmentedControl({
    required this.timeSpanDays,
    required this.onValueChanged,
    super.key,
  });

  final int timeSpanDays;
  final void Function(int) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final shortLabels = MediaQuery.of(context).size.width < 450;

    ButtonSegment<int> segment(int days) {
      return buttonSegment(
        value: days,
        selected: timeSpanDays,
        label: shortLabels ? '{$days}d' : '$days days',
      );
    }

    return SegmentedButton<int>(
      selected: {timeSpanDays},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onValueChanged(selected.first),
      segments: [
        segment(7),
        segment(14),
        segment(30),
        segment(90),
        if (isDesktop) segment(180),
      ],
    );
  }
}
