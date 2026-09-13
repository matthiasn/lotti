import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void expectTextStyle(TextStyle actual, TextStyle expected, Color color) {
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.height, expected.height);
  expect(actual.color, color);
}
