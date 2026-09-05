import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'generate_test_optimizer.dart';

/// Executes every suite exactly once and propagates the test process status.
Future<int> runTestSuites(
  List<String> arguments, {
  required String packageRoot,
  required String flutterExecutable,
}) async {
  await generateTestOptimizer(packageRoot: packageRoot);
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
