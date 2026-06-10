import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_models.dart';
import 'eval_profile_catalog.dart';
import 'profiles.dart';

void main() {
  test('defaults to built-in profiles when EVAL_PROFILES is unset', () {
    final catalog = EvalProfileCatalogLoader.fromEnvironment(const {});

    expect(catalog.usesExternalProfiles, isFalse);
    expect(catalog.sourceLabel, 'built-in default profiles');
    expect(catalog.profiles, kDefaultProfiles);
  });

  test('loads profiles from an object catalog file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'lotti-eval-profiles-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final file = File('${tempDir.path}/profiles.json');
    await file.writeAsString(
      jsonEncode({
        'profiles': [
          const EvalProfile(
            name: 'gemini-fast-low-thinking',
            isLocal: false,
            modelClass: EvalModelClass.frontierFast,
            modelId: 'gemini-fast-low-thinking-model',
            temperature: 0.2,
            maxCompletionTokens: 4096,
            tokenBudget: 60000,
            trialCount: 2,
          ).toJson(),
          const EvalProfile(
            name: 'local-qwen-reasoning',
            isLocal: true,
            modelClass: EvalModelClass.localReasoning,
            modelId: 'local-qwen-reasoning-model',
            temperature: 0.4,
            maxCompletionTokens: 2048,
            tokenBudget: 12000,
          ).toJson(),
        ],
      }),
    );

    final catalog = EvalProfileCatalogLoader.fromEnvironment(
      {kEvalProfilesPathEnv: file.path},
    );

    expect(catalog.usesExternalProfiles, isTrue);
    expect(catalog.sourceLabel, file.path);
    expect(catalog.profiles.map((profile) => profile.name), [
      'gemini-fast-low-thinking',
      'local-qwen-reasoning',
    ]);
    expect(catalog.profiles.first.trialCount, 2);
  });

  test('loads profiles from inline JSON', () {
    final catalog = EvalProfileCatalogLoader.fromEnvironment(
      const {},
      dartDefineValue: jsonEncode([
        const EvalProfile(
          name: 'frontier-inline',
          isLocal: false,
          modelClass: EvalModelClass.frontierReasoning,
          modelId: 'frontier-inline-model',
        ).toJson(),
      ]),
    );

    expect(catalog.usesExternalProfiles, isTrue);
    expect(catalog.sourceLabel, 'inline JSON');
    expect(catalog.profiles.single.name, 'frontier-inline');
  });

  test('rejects duplicate names and inconsistent local class labels', () {
    final duplicateJson = jsonEncode([
      kFrontierFastProfile.toJson(),
      kFrontierFastProfile.toJson(),
    ]);
    final inconsistentJson = jsonEncode([
      const EvalProfile(
        name: 'bad-local-frontier',
        isLocal: true,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'bad-local-frontier-model',
      ).toJson(),
    ]);

    expect(
      () => EvalProfileCatalogLoader.fromJsonSource(duplicateJson),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Duplicate eval profile name: frontier-fast'),
        ),
      ),
    );
    expect(
      () => EvalProfileCatalogLoader.fromJsonSource(inconsistentJson),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('inconsistent isLocal/modelClass'),
        ),
      ),
    );
  });
}
