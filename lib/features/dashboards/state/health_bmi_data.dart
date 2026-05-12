import 'dart:core';

class BmiRange {
  BmiRange({
    required this.name,
    required this.hexColor,
  });

  final String name;
  final String hexColor;
}

List<BmiRange> bmiRanges = [
  BmiRange(name: 'NORMAL', hexColor: '#27B707'),
  BmiRange(name: 'OVERWEIGHT', hexColor: '#FCB004'),
  BmiRange(name: 'OBESE', hexColor: '#FA6707'),
  BmiRange(name: 'SEVERELY OBESE', hexColor: '#FF1700'),
  BmiRange(name: 'MORBIDLY OBESE', hexColor: '#7030A0'),
];
