import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.FragmentProgram> hFailingProgramLoader() {
  return Future<ui.FragmentProgram>.error(StateError('shader unavailable'));
}

CustomPaint hCustomPaintUnder<T extends Widget>(WidgetTester tester) {
  return tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(T),
      matching: find.byType(CustomPaint),
    ),
  );
}

void hPaintWith(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

class TestSurface extends StatelessWidget {
  const TestSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }
}
