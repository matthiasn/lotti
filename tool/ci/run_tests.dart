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
  final selection = _shardArguments(arguments);
  stdout.writeln('Preparing test targets...');
  final preparation = Stopwatch()..start();
  await generateTestOptimizer(
    packageRoot: packageRoot,
    excludedSuiteTags: _excludedSuiteTags(arguments),
    totalShards: selection.total,
    shardIndex: selection.index,
  );
  final targets =
      (jsonDecode(
                await File(
                  path.join(packageRoot, testTargetsRelativePath),
                ).readAsString(),
              )
              as List<dynamic>)
          .cast<String>();
  preparation.stop();
  stdout.writeln(
    'Prepared ${targets.length} test targets in '
    '${preparation.elapsedMilliseconds} ms; starting Flutter.',
  );
  final process = await Process.start(
    flutterExecutable,
    ['test', ...selection.remaining, ...targets],
    workingDirectory: packageRoot,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

// Consume the shard flags here: forwarding them would shard the already
// partitioned files a second time and silently omit tests.
({int total, int index, List<String> remaining}) _shardArguments(
  List<String> arguments,
) {
  final remaining = <String>[];
  final values = <String, int>{};
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (argument == '--') {
      remaining.addAll(arguments.skip(i));
      break;
    }
    final name = argument.split('=').first;
    if (name != '--total-shards' && name != '--shard-index') {
      remaining.add(argument);
      continue;
    }
    final raw = argument.contains('=')
        ? argument.substring(name.length + 1)
        : i + 1 < arguments.length
        ? arguments[++i]
        : '';
    final value = int.tryParse(raw);
    if (value == null || values.containsKey(name)) {
      throw ArgumentError('Invalid or repeated $name: $raw');
    }
    values[name] = value;
  }
  if (values.length == 1) {
    throw ArgumentError('Specify both --total-shards and --shard-index');
  }
  return (
    total: values['--total-shards'] ?? 1,
    index: values['--shard-index'] ?? 0,
    remaining: remaining,
  );
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
