import 'dart:convert';
import 'dart:io';

/// Summarizes JSON reporter events using each test's own start/end timestamps.
/// Concurrent tests do not distort one another's measured duration.
String summarizeTestEvents(Iterable<String> lines, {int thresholdMs = 2000}) {
  final starts = <int, Map<String, dynamic>>{};
  final completed = <int>{};
  final slow = <({String name, int duration})>[];
  final failures = <String>[];
  final skips = <String>[];
  var passed = 0;
  var malformed = 0;
  var runFinished = false;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      malformed++;
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      malformed++;
      continue;
    }
    switch (decoded['type']) {
      case 'testStart':
        final test = decoded['test'] as Map<String, dynamic>;
        starts[test['id'] as int] = {...test, 'startedAt': decoded['time']};
      case 'testDone':
        final id = decoded['testID'] as int;
        completed.add(id);
        final test = starts[id];
        final name = test?['name'] as String? ?? 'test $id';
        final failed = decoded['result'] != 'success';
        // Loading failures matter even though successful loaders are hidden.
        if (failed) {
          failures.add(name);
        }
        if (decoded['hidden'] == true || name.startsWith('loading ')) continue;
        if (decoded['skipped'] == true) {
          skips.add(name);
        } else if (!failed) {
          passed++;
        }
        if (test != null && decoded['skipped'] != true) {
          final duration =
              (decoded['time'] as int) - (test['startedAt'] as int);
          if (duration >= thresholdMs)
            slow.add((name: name, duration: duration));
        }
      case 'done':
        runFinished = true;
    }
  }
  slow.sort((a, b) => b.duration.compareTo(a.duration));
  final incomplete = [
    for (final entry in starts.entries)
      if (!completed.contains(entry.key)) entry.value['name'] as String,
  ];
  final report = StringBuffer()
    ..writeln(
      'Passed: $passed; failed: ${failures.length}; skipped: ${skips.length}; '
      'incomplete: ${incomplete.length}.',
    )
    ..writeln(
      'Runner completion event: ${runFinished ? "present" : "missing"}.',
    );
  if (malformed > 0) report.writeln('Malformed/truncated records: $malformed.');
  for (final name in failures) {
    report.writeln('FAIL: $name');
  }
  for (final name in skips) {
    report.writeln('SKIP: $name');
  }
  for (final name in incomplete) {
    report.writeln('INCOMPLETE: $name');
  }
  report.writeln('Slow tests (>= ${thresholdMs}ms):');
  for (final test in slow) {
    report.writeln('${test.duration}ms: ${test.name}');
  }
  return report.toString();
}

/// Usage: dart run test/tool/analyze_test_timings.dart report.json [thresholdMs]
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: analyze_test_timings.dart <jsonFile> [thresholdMs]');
    exitCode = 64;
    return;
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }
  stdout.write(
    summarizeTestEvents(
      await file.readAsLines(),
      thresholdMs: args.length > 1 ? int.parse(args[1]) : 2000,
    ),
  );
}
