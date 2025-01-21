import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

const gridAlpha = 76;
const labelOpacity = 0.5;
const maxScale = 20.0;

class ChartLabel extends StatelessWidget {
  const ChartLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: labelOpacity,
      child: Text(
        text,
        style: context.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}

final gridLine = FlLine(
  color: chartTextColor.withAlpha(gridAlpha),
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
