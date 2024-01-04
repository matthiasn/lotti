import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

const gridOpacity = 0.3;
const labelOpacity = 0.5;

class ChartLabel extends StatelessWidget {
  const ChartLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: labelOpacity,
      child: Text(
        text,
        style: chartTitleStyleSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}

final gridLine = FlLine(
  color: chartTextColor.withOpacity(gridOpacity),
  strokeWidth: 1,
);

List<Color> gradientColors = [
  oldPrimaryColorLight,
  oldPrimaryColor,
];

final gridLineEmphasized = FlLine(
  color: chartTextColor,
  dashArray: [5, 3],
);
