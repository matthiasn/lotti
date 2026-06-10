import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';
import 'eval_scenario_catalog.dart';
import 'eval_scenarios.dart';

void main() {
  test('uses the public scenario catalog when no external path is set', () {
    final catalog = EvalScenarioCatalogLoader.fromEnvironment(const {});

    expect(catalog.scenarios, allEvalScenarios);
    expect(catalog.protectedHoldoutEvidence, isFalse);
    expect(catalog.sourceDescription, 'public catalog');
    expect(catalog.evidence.usesExternalCatalog, isFalse);
    expect(
      catalog.evidence.scenarioSetDigest,
      EvalProvenance.scenarioSetDigest(allEvalScenarios),
    );
  });

  test('loads protected external holdout scenarios from dart define path', () {
    final file = _writeCatalog(
      {
        'schemaVersion': 1,
        'catalogId': 'private-production-replay-v1',
        'protectedHoldout': true,
        'scenarios': [_scenarioJson(id: 'private_task_holdout')],
      },
    );

    final catalog = EvalScenarioCatalogLoader.fromEnvironment(
      const {},
      dartDefinePath: file.path,
    );

    expect(catalog.scenarios, hasLength(allEvalScenarios.length + 1));
    expect(catalog.scenarios.last.id, 'private_task_holdout');
    expect(catalog.scenarios.last.metadata.split, EvalScenarioSplit.holdout);
    expect(catalog.protectedHoldoutEvidence, isTrue);
    expect(catalog.sourceDescription, 'public catalog + scenarios.json');
    expect(catalog.evidence.externalCatalogId, 'private-production-replay-v1');
    expect(catalog.evidence.externalCatalogDigest, startsWith('sha256:'));
    expect(catalog.evidence.externalSourceLabel, 'scenarios.json');
    expect(
      catalog.evidence.scenarioSetDigest,
      EvalProvenance.scenarioSetDigest(catalog.scenarios),
    );
    expect(catalog.evidence.protectedScenarioIds, ['private_task_holdout']);
    expect(
      catalog.evidence.protectedHoldoutScenarioIds,
      ['private_task_holdout'],
    );
  });

  test(
    'loads plain scenario lists from environment path without protection',
    () {
      final file = _writeCatalog([
        _scenarioJson(id: 'env_task_holdout'),
      ]);

      final catalog = EvalScenarioCatalogLoader.fromEnvironment({
        kEvalScenarioCatalogPathEnv: file.path,
      });

      expect(catalog.scenarios.last.id, 'env_task_holdout');
      expect(catalog.protectedHoldoutEvidence, isFalse);
    },
  );

  test('rejects protected catalogs without holdout scenarios', () {
    final scenario = _scenarioJson(id: 'not_a_holdout');
    scenario['metadata'] = <String, dynamic>{
      ...(scenario['metadata'] as Map<String, dynamic>),
      'split': EvalScenarioSplit.development.name,
    };
    final file = _writeCatalog({
      'schemaVersion': 1,
      'catalogId': 'private-production-replay-v1',
      'protectedHoldout': true,
      'scenarios': [scenario],
    });

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('protectedHoldout=true but contains no holdout scenarios'),
        ),
      ),
    );
  });

  test('rejects protected catalogs without a catalog id', () {
    final file = _writeCatalog({
      'schemaVersion': 1,
      'protectedHoldout': true,
      'scenarios': [_scenarioJson(id: 'private_task_holdout')],
    });

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('must declare catalogId'),
        ),
      ),
    );
  });

  test('rejects protected holdouts that are not production replay', () {
    final scenario = _scenarioJson(id: 'hand_authored_holdout');
    scenario['metadata'] = <String, dynamic>{
      ...(scenario['metadata'] as Map<String, dynamic>),
      'source': EvalScenarioSource.synthetic.name,
    };
    final file = _writeCatalog({
      'schemaVersion': 1,
      'catalogId': 'private-production-replay-v1',
      'protectedHoldout': true,
      'scenarios': [scenario],
    });

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('holdout scenarios are not production replay'),
        ),
      ),
    );
  });

  test('rejects external scenarios that collide with public scenario ids', () {
    final file = _writeCatalog([
      _scenarioJson(id: taskReleaseNotesScenario.id),
    ]);

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('duplicate scenario id'),
        ),
      ),
    );
  });

  test('rejects unsafe external scenario ids before writing traces', () {
    final scenario = _scenarioJson(id: 'private/task/holdout');
    final file = _writeCatalog([scenario]);

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unsafe scenario id private/task/holdout'),
        ),
      ),
    );
  });

  test('rejects malformed external review metadata with row context', () {
    final scenario = _scenarioJson(id: 'private_bad_review');
    scenario['metadata'] = <String, dynamic>{
      ...(scenario['metadata'] as Map<String, dynamic>),
      'review': {'status': 'needs_review'},
    };
    final file = _writeCatalog([scenario]);

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('invalid scenario at index 0'),
            contains('metadata.review.reviewer must be a string'),
          ),
        ),
      ),
    );
  });

  test('rejects unknown external review status with row context', () {
    final scenario = _scenarioJson(id: 'private_unknown_review_status');
    scenario['metadata'] = <String, dynamic>{
      ...(scenario['metadata'] as Map<String, dynamic>),
      'review': {
        'status': 'rubber_stamped',
        'reviewer': 'human-reviewer',
        'reviewedAt': '2026-06-10T12:00:00.000Z',
        'subjectDigest': EvalProvenance.digestText('placeholder'),
        'rationale': 'Unknown status should fail during parse.',
      },
    };
    final file = _writeCatalog([scenario]);

    expect(
      () => EvalScenarioCatalogLoader.fromEnvironment(
        const {},
        dartDefinePath: file.path,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('invalid scenario at index 0'),
            contains('metadata.review.status is unknown: rubber_stamped'),
          ),
        ),
      ),
    );
  });
}

Map<String, dynamic> _scenarioJson({required String id}) {
  final json = taskReleaseNotesScenario.toJson();
  json['id'] = id;
  json['metadata'] = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'split': EvalScenarioSplit.holdout.name,
    'source': EvalScenarioSource.productionReplay.name,
    'capabilityIds': ['task.private.holdout'],
    'tags': ['private', 'production-replay'],
  };
  return json;
}

File _writeCatalog(Object json) {
  final tempDir = Directory.systemTemp.createTempSync('lotti-eval-catalog-');
  addTearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });
  final file = File('${tempDir.path}/scenarios.json')
    ..writeAsStringSync(jsonEncode(json));
  return file;
}
