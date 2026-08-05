import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/seed/demo_world_ai.dart';

String _en(String en, String de) => en;

void main() {
  final now = DateTime(2026, 7, 17, 10, 30);

  group('demo AI config functions', () {
    test('build the fixture roster with referential integrity intact', () {
      final providers = demoAiProviders(_en, now);
      final models = demoAiModels(_en, now);
      final profiles = demoAiProfiles(_en, now);
      final skills = demoAiSkills(_en, now);

      expect(providers, hasLength(4));
      expect(models, hasLength(6));
      expect(profiles, hasLength(3));
      expect(skills, hasLength(4));

      final providerIds = providers.map((p) => p.id).toSet();
      for (final model in models) {
        expect(
          providerIds,
          contains(model.inferenceProviderId),
          reason: 'model ${model.id} references an unknown provider',
        );
      }
      final modelIds = models.map((m) => m.id).toSet();
      for (final profile in profiles) {
        expect(modelIds, contains(profile.thinkingModelId));
      }
      expect(
        profiles.where((profile) => profile.isDefault).map((p) => p.id),
        [manualProjectWaddleProfileId],
      );
    });

    test('resolve names through the given DemoSeedText', () {
      final de = demoSeedTextForLocale(const Locale('de'));
      expect(
        demoAiProviders(de, now).first.name,
        'Missionskontroll-Router',
      );
      expect(demoAiModels(de, now).first.name, 'Watschelkommando 70B');
      expect(
        demoAiProfiles(de, now).first.name,
        'Project-Waddle-Kommando',
      );
      expect(
        demoAiSkills(de, now).first.name,
        'Habitat-Briefing transkribieren',
      );
    });

    test('anchor their created-at history on the given clock', () {
      final shiftedNow = DateTime(2027, 1, 4, 6);
      expect(
        demoAiProviders(_en, shiftedNow).first.createdAt,
        shiftedNow.subtract(const Duration(days: 90)),
      );
      expect(
        demoAiModels(_en, shiftedNow).first.createdAt,
        shiftedNow.subtract(const Duration(days: 80)),
      );
      expect(
        demoAiProfiles(_en, shiftedNow).first.createdAt,
        shiftedNow.subtract(const Duration(days: 33)),
      );
      expect(demoAiSkills(_en, shiftedNow).first.createdAt, shiftedNow);
    });
  });
}
