import 'package:lotti/main.dart' as app;
import 'package:flutter/material.dart';

import 'package:fluttium_test_runner/fluttium_test_runner.dart' as test_runner;

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized()
    ..setSemanticsEnabled(true);

  await Future(app.main);
  await binding.endOfFrame;
  await test_runner.run(binding);
}
