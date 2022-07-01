import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

num calculateBMI(num height, num weight) {
  final heightSquare = height * height;
  return weight / heightSquare;
}

num weightFromBmi(num height, num bmi) {
  final heightSquare = height * height;
  return bmi * heightSquare;
}

class BmiRangeSegment {
  BmiRangeSegment({
    required this.lowerBoundInclusive,
    required this.upperBoundExclusive,
    this.alwaysShow = false,
  });
  final num lowerBoundInclusive;
  final num upperBoundExclusive;
  final bool alwaysShow;
}

class BmiRange {
  BmiRange({
    required this.name,
    required this.hexColor,
    required this.lowerBoundInclusive,
    required this.upperBoundExclusive,
    required this.segments,
  });

  final String name;
  final String hexColor;
  final num lowerBoundInclusive;
  final num upperBoundExclusive;
  final List<BmiRangeSegment> segments;
}

List<BmiRange> bmiRanges = [
  BmiRange(
    name: 'NORMAL',
    hexColor: '#27B707',
    lowerBoundInclusive: 18.5,
    upperBoundExclusive: 25,
    segments: [
      BmiRangeSegment(
        lowerBoundInclusive: 18.5,
        upperBoundExclusive: 20,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 20,
        upperBoundExclusive: 23,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 23,
        upperBoundExclusive: 25,
        alwaysShow: true,
      ),
    ],
  ),
  BmiRange(
    name: 'OVERWEIGHT',
    hexColor: '#FCB004',
    lowerBoundInclusive: 25,
    upperBoundExclusive: 30,
    segments: [
      BmiRangeSegment(
        lowerBoundInclusive: 25,
        upperBoundExclusive: 27.5,
        alwaysShow: true,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 27.5,
        upperBoundExclusive: 30,
      ),
    ],
  ),
  BmiRange(
    name: 'OBESE',
    hexColor: '#FA6707',
    lowerBoundInclusive: 30,
    upperBoundExclusive: 35,
    segments: [
      BmiRangeSegment(
        lowerBoundInclusive: 30,
        upperBoundExclusive: 32,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 32,
        upperBoundExclusive: 34,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 34,
        upperBoundExclusive: 35,
      ),
    ],
  ),
  BmiRange(
    name: 'SEVERELY OBESE',
    hexColor: '#FF1700',
    lowerBoundInclusive: 35,
    upperBoundExclusive: 50,
    segments: [
      BmiRangeSegment(
        lowerBoundInclusive: 35,
        upperBoundExclusive: 37.5,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 37.5,
        upperBoundExclusive: 40,
      ),
    ],
  ),
  BmiRange(
    name: 'MORBIDLY OBESE',
    hexColor: '#7030A0',
    lowerBoundInclusive: 40,
    upperBoundExclusive: 50,
    segments: [
      BmiRangeSegment(
        lowerBoundInclusive: 40,
        upperBoundExclusive: 42.5,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 42.5,
        upperBoundExclusive: 45,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 45,
        upperBoundExclusive: 47.5,
      ),
      BmiRangeSegment(
        lowerBoundInclusive: 47.5,
        upperBoundExclusive: 50,
      ),
    ],
  ),
];

charts.RangeAnnotationSegment<num> makeRangeSegment(
  String hexColor,
  num from,
  num to,
) {
  final color = colorFromCssHex(hexColor);
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

List<charts.RangeAnnotationSegment<num>> makeRangeAnnotationSegments(
  List<Observation> observations,
  num height,
) {
  final min = findMin(observations);
  final max = findMax(observations);
  final rangeSegments = <charts.RangeAnnotationSegment<num>>[];

  for (final range in bmiRanges) {
    for (final segment in range.segments) {
      final lowerWeightBoundInclusive =
          weightFromBmi(height, segment.lowerBoundInclusive);
      final upperWeightBoundExclusive =
          weightFromBmi(height, segment.upperBoundExclusive);

      if (segment.alwaysShow ||
          nearRange(
            min: min,
            max: max,
            lowerBound: lowerWeightBoundInclusive,
            upperBound: upperWeightBoundExclusive,
          )) {
        rangeSegments.add(
          makeRangeSegment(
            range.hexColor,
            lowerWeightBoundInclusive,
            upperWeightBoundExclusive,
          ),
        );
      }
    }
  }

  return rangeSegments;
}
