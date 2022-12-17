import 'package:flutter/cupertino.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';

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
        7: DaysSegment(shortLabels ? '7d' : '7 days'),
        14: DaysSegment(shortLabels ? '14d' : '14 days'),
        30: DaysSegment(shortLabels ? '30d' : '30 days'),
        90: DaysSegment(shortLabels ? '90d' : '90 days'),
        180: DaysSegment(shortLabels ? '180d' : '180 days'),
        if (isDesktop) 365: DaysSegment(shortLabels ? '1y' : '1 year'),
      },
    );
  }
}
