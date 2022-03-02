import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

num calculateBMI(num height, num weight) {
  num heightSquare = height * height;
  return weight / heightSquare;
}

charts.RangeAnnotationSegment<num> makeRange(
  Color color,
  num from,
  num to,
) {
  return charts.RangeAnnotationSegment(
    from,
    to,
    charts.RangeAnnotationAxisType.measure,
    color: charts.Color(
      r: color.red,
      g: color.green,
      b: color.blue,
      a: 100,
    ),
  );
}

List<charts.RangeAnnotationSegment<num>> makeRangeAnnotations(
  List<Observation> observations,
) {
  num min = findMin(observations);
  num max = findMax(observations);

  List<charts.RangeAnnotationSegment<num>> ranges = [
    makeRange(Colors.green, 20, 24.99),
    makeRange(Colors.yellow, 25, 29.99),
  ];

  num lowerGreenLower = 18.5;
  num lowerGreenUpper = 19.99;
  num orangeLower = 30;
  num orangeUpper = 34.99;
  num redLower = 35;
  num redUpper = 39.99;
  num purpleLower = 40;
  num purpleUpper = 49.99;

  void addNearRange(Color color, num lowerBound, num upperBound) {
    if (nearRange(
      min: min,
      max: max,
      lowerBound: lowerBound,
      upperBound: upperBound,
    )) {
      ranges.add(makeRange(color, lowerBound, upperBound));
    }
  }

  addNearRange(Colors.green, lowerGreenLower, lowerGreenUpper);
  addNearRange(Colors.orange, orangeLower, orangeUpper);
  addNearRange(Colors.red, redLower, redUpper);
  addNearRange(Colors.purple, purpleLower, purpleUpper);

  return ranges;
}
