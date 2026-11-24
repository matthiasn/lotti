// Tests for lib/features/speech/state/profile_transcription_provider.dart:
// hasProfileTranscription's delegation to ProfileAutomationService and its
// invalidation when profiles change.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/state/profile_transcription_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// Stream-backed fake so tests can push new profile lists and observe
/// hasProfileTranscription invalidating.
class _FakeInferenceProfileController extends InferenceProfileController {
  _FakeInferenceProfileController(this._profiles);

  final Stream<List<AiConfig>> _profiles;

  @override
  Stream<List<AiConfig>> build() => _profiles;
}

void main() {
  late MockProfileAutomationService automationService;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    automationService = MockProfileAutomationService();
  });

  ProviderContainer makeContainer({
    Stream<List<AiConfig>>? profiles,
  }) {
    final container = ProviderContainer(
      overrides: [
        profileAutomationServiceProvider.overrideWithValue(automationService),
        inferenceProfileControllerProvider.overrideWith(
          () => _FakeInferenceProfileController(
            profiles ?? Stream.value(const <AiConfig>[]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubHasTranscription({required bool result}) {
    when(
      () => automationService.hasAutomatedSkillType(
        subjectId: any(named: 'subjectId'),
        skillType: any(named: 'skillType'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('hasProfileTranscription', () {
    test('asks the automation service for transcription on the task', () async {
      stubHasTranscription(result: true);
      final container = makeContainer();

      final result = await container.read(
        hasProfileTranscriptionProvider('task-1').future,
      );

      expect(result, isTrue);
      verify(
        () => automationService.hasAutomatedSkillType(
          subjectId: 'task-1',
          skillType: SkillType.transcription,
        ),
      ).called(1);
    });

    test('returns false when the service reports no automation', () async {
      stubHasTranscription(result: false);
      final container = makeContainer();

      final result = await container.read(
        hasProfileTranscriptionProvider('task-1').future,
      );

      expect(result, isFalse);
    });

    test('re-evaluates when the profiles stream emits', () async {
      stubHasTranscription(result: false);
      final profilesController = StreamController<List<AiConfig>>();
      addTearDown(profilesController.close);
      final container = makeContainer(profiles: profilesController.stream);

      // Keep the provider alive across the profile change.
      final sub = container.listen(
        hasProfileTranscriptionProvider('task-1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      profilesController.add(const []);
      expect(
        await container.read(hasProfileTranscriptionProvider('task-1').future),
        isFalse,
      );

      // A profile edit lands: the service now reports transcription support.
      stubHasTranscription(result: true);
      profilesController.add(const []);
      await pumpEventQueue();

      expect(
        await container.read(hasProfileTranscriptionProvider('task-1').future),
        isTrue,
      );
      verify(
        () => automationService.hasAutomatedSkillType(
          subjectId: 'task-1',
          skillType: SkillType.transcription,
        ),
      ).called(2);
    });
  });
}
