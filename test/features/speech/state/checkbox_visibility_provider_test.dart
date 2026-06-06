// Tests for lib/features/speech/state/checkbox_visibility_provider.dart.
//
// Covers hasProfileTranscription (delegation to ProfileAutomationService and
// invalidation when profiles change) and checkboxVisibility (null linkedId,
// loading, error, and data branches).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
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
        taskId: any(named: 'taskId'),
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
          taskId: 'task-1',
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
          taskId: 'task-1',
          skillType: SkillType.transcription,
        ),
      ).called(2);
    });
  });

  group('checkboxVisibility', () {
    test('hides speech and never queries the service without a linkedId', () {
      final container = makeContainer();

      final visibility = container.read(
        checkboxVisibilityProvider(categoryId: 'cat-1'),
      );

      expect(visibility.speech, isFalse);
      expect(visibility.none, isTrue);
      verifyNever(
        () => automationService.hasAutomatedSkillType(
          taskId: any(named: 'taskId'),
          skillType: any(named: 'skillType'),
        ),
      );
    });

    test('treats a still-loading transcription check as hidden', () {
      // Never-completing future keeps hasProfileTranscription in loading.
      when(
        () => automationService.hasAutomatedSkillType(
          taskId: any(named: 'taskId'),
          skillType: any(named: 'skillType'),
        ),
      ).thenAnswer((_) => Completer<bool>().future);
      final container = makeContainer();

      final visibility = container.read(
        checkboxVisibilityProvider(categoryId: 'cat-1', linkedId: 'task-1'),
      );

      expect(visibility.speech, isFalse);
    });

    test('treats a failed transcription check as hidden', () async {
      when(
        () => automationService.hasAutomatedSkillType(
          taskId: any(named: 'taskId'),
          skillType: any(named: 'skillType'),
        ),
      ).thenThrow(Exception('profile lookup failed'));
      final container = makeContainer();

      // Hold subscriptions so the autoDispose providers survive long enough
      // to surface the error state.
      final transcriptionSub = container.listen(
        hasProfileTranscriptionProvider('task-1'),
        (_, _) {},
      );
      addTearDown(transcriptionSub.close);
      final visibilitySub = container.listen(
        checkboxVisibilityProvider(categoryId: 'cat-1', linkedId: 'task-1'),
        (_, _) {},
      );
      addTearDown(visibilitySub.close);

      await pumpEventQueue();

      // Riverpod's retry handling may have already flipped the state back to
      // AsyncLoading-with-error, so assert on hasError rather than AsyncError.
      expect(transcriptionSub.read().hasError, isTrue);
      expect(visibilitySub.read().speech, isFalse);
    });

    test(
      'shows speech once the linked task has profile transcription',
      () async {
        stubHasTranscription(result: true);
        final container = makeContainer();

        await container.read(hasProfileTranscriptionProvider('task-1').future);
        final visibility = container.read(
          checkboxVisibilityProvider(categoryId: 'cat-1', linkedId: 'task-1'),
        );

        expect(visibility.speech, isTrue);
        expect(visibility.none, isFalse);
      },
    );

    test(
      'keeps speech hidden when the linked task has no transcription',
      () async {
        stubHasTranscription(result: false);
        final container = makeContainer();

        await container.read(hasProfileTranscriptionProvider('task-1').future);
        final visibility = container.read(
          checkboxVisibilityProvider(categoryId: 'cat-1', linkedId: 'task-1'),
        );

        expect(visibility.speech, isFalse);
      },
    );
  });
}
