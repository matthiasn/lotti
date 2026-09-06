import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'generate_test_optimizer.dart';

/// Executes selected suites once and propagates the test process status.
Future<int> runTestSuites(
  List<String> arguments, {
  required String packageRoot,
  required String flutterExecutable,
}) async {
  await generateTestOptimizer(
    packageRoot: packageRoot,
    excludedSuiteTags: _excludedSuiteTags(arguments),
  );
  final targets =
      (jsonDecode(
                await File(
                  path.join(packageRoot, testTargetsRelativePath),
                ).readAsString(),
              )
              as List<dynamic>)
          .cast<String>();
  final process = await Process.start(
    flutterExecutable,
    ['test', ...arguments, ...targets],
    workingDirectory: packageRoot,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

// Positive disjunctions are safe to apply before discovering child-test tags:
// adding tags cannot make them false. Leave all other expressions to Flutter.
Set<String> _excludedSuiteTags(List<String> arguments) {
  final tags = <String>{};
  final disjunction = RegExp(
    r'^[a-zA-Z_][a-zA-Z0-9_-]*(\s*\|\|\s*[a-zA-Z_][a-zA-Z0-9_-]*)*$',
  );
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--') break;
    String? expression;
    if (argument.startsWith('--exclude-tags=')) {
      expression = argument.substring('--exclude-tags='.length);
    } else if (argument == '--exclude-tags' && index + 1 < arguments.length) {
      expression = arguments[++index];
    }
    if (expression != null && disjunction.hasMatch(expression.trim())) {
      tags.addAll(expression.split('||').map((tag) => tag.trim()));
    }
  }
  return tags;
}

/// Runs with the Flutter SDK containing the Dart executable that launched us.
Future<void> main(List<String> arguments) async {
  final flutterBin = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent;
  exitCode = await runTestSuites(
    arguments,
    packageRoot: Directory.current.path,
    flutterExecutable: path.join(
      flutterBin.path,
      Platform.isWindows ? 'flutter.bat' : 'flutter',
    ),
  );
}
