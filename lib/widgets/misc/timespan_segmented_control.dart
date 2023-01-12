import 'package:flutter/cupertino.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/segmented_control.dart';

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

    return CupertinoSegmentedControl<int>(
      selectedColor: styleConfig().primaryColor,
      unselectedColor: styleConfig().negspace,
      borderColor: styleConfig().primaryColor,
      groupValue: timeSpanDays,
      onValueChanged: onValueChanged,
      children: {
        7: TextSegment(shortLabels ? '7d' : '7 days'),
        14: TextSegment(shortLabels ? '14d' : '14 days'),
        30: TextSegment(shortLabels ? '30d' : '30 days'),
        90: TextSegment(shortLabels ? '90d' : '90 days'),
        180: TextSegment(shortLabels ? '180d' : '180 days'),
        if (isDesktop) 365: TextSegment(shortLabels ? '1y' : '1 year'),
      },
    );
  }
}
