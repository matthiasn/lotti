import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/lotti_gym_catalog.dart';
import '../features/ai/eval/support/penguin_wake_scenarios.dart';

void main() {
  late Map<String, Object?> catalog;
  late List<Map<String, Object?>> suites;
  setUpAll(() async {
    catalog = await buildLottiGymCatalog();
    suites = (catalog['suites']! as List).cast<Map<String, Object?>>();
  });

  test('every live harness has an exercise or a documented exclusion', () {
    final registered = {
      for (final suite in suites) suite['entryPoint'],
      ...(catalog['excludedEntryPoints']! as Map).keys,
    };
    final liveFiles = {
      for (final path in [
        'test/features/ai/eval',
        'test/features/agents/eval',
        'test/features/daily_os_next/eval',
      ])
        for (final file in Directory(path).listSync(recursive: true))
          if (file.path.endsWith('_live_test.dart')) file.path,
    };
    expect(registered, liveFiles);
  });

  test('exercise IDs and scenarios are unique and dependencies resolve', () {
    final ids = suites.map((s) => s['id']).toSet();
    expect(ids.length, suites.length);
    for (final suite in suites) {
      final cases = suite['cases']! as List;
      expect(cases, isNotEmpty, reason: '${suite['id']}');
      expect(cases.toSet().length, cases.length, reason: '${suite['id']}');
      expect(
        (suite['dependencies']! as List).toSet().difference(ids),
        isEmpty,
      );
      expect(File(suite['entryPoint']! as String).existsSync(), isTrue);
    }
  });

  test('wake restraint cases and query prerequisites cannot disappear', () {
    final byId = {for (final suite in suites) suite['id']: suite};
    expect(
      byId['task-wake']!['cases'],
      PenguinWakeScenarioId.values.map((s) => s.name).toList(),
    );
    expect(byId['query']!['grouped'], isTrue);
    expect(byId['query']!['dependencies'], ['query-reports']);
    expect(byId['query-actions']!['dependencies'], ['query-reports']);
    expect(
      byId['task-conversation']!['environment'],
      containsPair(
        'LOCAL_TASK_AGENT_EVAL_EXECUTION_MODE',
        'productionRouting',
      ),
    );
  });
}
