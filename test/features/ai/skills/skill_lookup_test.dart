import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/skills/skill_lookup.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';

void main() {
  late MockAiConfigRepository aiConfigRepository;

  /// A skill that only exists in the config store — the shape a demo seed or
  /// the future per-user layer produces. Deliberately not a built-in id.
  AiConfigSkill storedSkill({String id = 'skill-stored-001'}) => AiConfigSkill(
    id: id,
    name: 'Stored Skill',
    skillType: SkillType.transcription,
    requiredInputModalities: const [Modality.audio],
    contextPolicy: ContextPolicy.dictionaryOnly,
    createdAt: DateTime(2026),
    systemInstructions: 'Transcribe.',
    userInstructions: 'Audio attached.',
  );

  Future<AiConfigSkill?> resolve(String skillId) => resolveAssignedSkill(
    skillId: skillId,
    aiConfigRepository: aiConfigRepository,
  );

  setUp(() {
    aiConfigRepository = MockAiConfigRepository();
    when(
      () => aiConfigRepository.getConfigById(any()),
    ).thenAnswer((_) async => null);
  });

  group('built-in ids', () {
    // The regression this function exists for. Nothing writes `builtInSkills`
    // into `ai_config.sqlite`, so on a fresh install the store answers `null`
    // for every assignment a profile carries. Resolving through the store
    // alone silently disabled every automated capability on that device.
    test('resolve from the registry even when the store has no row', () async {
      final skill = await resolve(skillTranscribeContextId);

      expect(skill, isNotNull);
      expect(skill!.id, skillTranscribeContextId);
      expect(skill.skillType, SkillType.transcription);
    });

    test('do not hit the store at all', () async {
      await resolve(skillTranscribeContextId);

      verifyNever(() => aiConfigRepository.getConfigById(any()));
    });

    // Built-in skills "always reflect the current code" (see [builtInSkills]),
    // so a row seeded by an earlier release must not pin stale instructions.
    test('the registry wins over a stored row with the same id', () async {
      when(
        () => aiConfigRepository.getConfigById(skillTranscribeContextId),
      ).thenAnswer((_) async => storedSkill(id: skillTranscribeContextId));

      final skill = await resolve(skillTranscribeContextId);

      expect(skill, findBuiltInSkill(skillTranscribeContextId));
      expect(skill!.name, isNot('Stored Skill'));
    });

    test('every registry id resolves without the store', () async {
      for (final builtIn in builtInSkills) {
        expect(await resolve(builtIn.id), builtIn, reason: builtIn.id);
      }
    });
  });

  group('ids the registry does not know', () {
    test('fall through to the store', () async {
      final stored = storedSkill();
      when(
        () => aiConfigRepository.getConfigById(stored.id),
      ).thenAnswer((_) async => stored);

      expect(await resolve(stored.id), stored);
    });

    test('resolve to null when the store has nothing either', () async {
      expect(await resolve('skill-nobody-has-heard-of'), isNull);
    });

    // Ids are not namespaced per config type, so a stored row under this id
    // may be something else entirely. Returning it would hand the runner a
    // provider where it expects a skill.
    test('resolve to null when the stored config is not a skill', () async {
      when(
        () => aiConfigRepository.getConfigById('not-a-skill'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'not-a-skill'));

      expect(await resolve('not-a-skill'), isNull);
    });
  });
}
