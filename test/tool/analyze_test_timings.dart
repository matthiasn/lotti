import 'dart:convert';
import 'dart:io';

/// Parses a Dart test JSON reporter output (newline-delimited JSON)
/// and surfaces tests with large gaps before they completed.
///
/// Usage: dart run test/tool/analyze_test_timings.dart reports/tests.json `thresholdMs`
///
/// Default threshold is 2000ms. The script prints a concise list of tests
/// where the time since the previous test completion exceeds the threshold.
void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
        'Usage: dart run test/tool/analyze_test_timings.dart <jsonFile> [thresholdMs]');
    exitCode = 64;
    return;
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final thresholdMs = args.length > 1 ? int.tryParse(args[1]) ?? 2000 : 2000;

  final testsById =
      <int, Map<String, dynamic>>{}; // id -> {name,url,line,suiteID}
  final suitePathById = <int, String>{}; // suiteID -> path
  final doneEvents = <Map<String, dynamic>>[]; // {id,time,hidden}

  final stream =
      file.openRead().transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in stream) {
    if (line.trim().isEmpty) continue;
    dynamic json;
    try {
      json = jsonDecode(line);
    } catch (_) {
      // Skip malformed lines (partial writes etc.)
      continue;
    }
    if (json is! Map<String, dynamic>) continue;
    final type = json['type'];
    final time = json['time'];

    if (type == 'suite') {
      final suite = json['suite'] as Map<String, dynamic>?;
      if (suite != null) {
        final sid = suite['id'];
        final path = suite['path'];
        if (sid is int && path is String) {
          suitePathById[sid] = path;
        }
      }
    } else if (type == 'testStart') {
      final test = json['test'] as Map<String, dynamic>?;
      if (test == null) continue;
      final id = test['id'];
      if (id is! int) continue;
      final suiteID = test['suiteID'];
      final name = (test['name'] ?? 'unknown').toString();
      // Prefer root_url, then url, then suite path fallback
      final rootUrl = test['root_url'];
      final url = test['url'];
      var resolvedUrl = 'unknown';
      if (rootUrl is String && rootUrl.isNotEmpty) {
        resolvedUrl = rootUrl;
      } else if (url is String && url.isNotEmpty) {
        resolvedUrl = url;
      } else if (suiteID is int && suitePathById.containsKey(suiteID)) {
        resolvedUrl = suitePathById[suiteID] ?? 'unknown';
      } else if (name.startsWith('loading ')) {
        // Try to extract path from the name for loading tests
        final idx = name.indexOf('/test/');
        if (idx != -1) {
          resolvedUrl = name.substring(name.indexOf('/', idx));
        }
      }

      testsById[id] = {
        'name': name,
        'url': resolvedUrl,
        'line': test['root_line'] ?? test['line'],
        'suiteID': suiteID,
      };
    } else if (type == 'testDone') {
      final testID = json['testID'];
      final hidden = json['hidden'] == true;
      if (testID is int && time is int) {
        doneEvents.add({'id': testID, 'time': time, 'hidden': hidden});
      }
    }
  }

  if (doneEvents.isEmpty) {
    stdout.writeln(
        'No test completion events found. Ensure reporter=json was used.');
    return;
  }

  doneEvents.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));

  stdout.writeln('Slow boundaries (gap >= ${thresholdMs}ms):');
  int? prevTime;
  for (final e in doneEvents) {
    final t = e['time'] as int;
    final id = e['id'] as int;
    final hidden = e['hidden'] == true;
    final info = testsById[id] ?? const {};
    final name = (info['name'] ?? 'unknown').toString();
    // Exclude internal/loading tests to reduce noise
    if (hidden || name.startsWith('loading ')) {
      prevTime = t;
      continue;
    }
    if (prevTime != null) {
      final gap = t - prevTime;
      if (gap >= thresholdMs) {
        final url = (info['url'] ?? 'unknown').toString();
        final line = info['line'];
        final mm = (t ~/ 60000).toString().padLeft(2, '0');
        final ss = ((t % 60000) ~/ 1000).toString().padLeft(2, '0');
        final gapSec = (gap / 1000).toStringAsFixed(2);
        stdout.writeln(
            '- $mm:$ss  gap=${gapSec}s  name="$name"  file=$url${line == null ? '' : ':$line'}');
      }
    }
    prevTime = t;
  }
}
