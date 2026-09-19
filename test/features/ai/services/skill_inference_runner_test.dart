import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/image_generation_error.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/service/image_path_migration_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';
import '../../ai_consumption/test_utils.dart';

part 'skill_inference_runner_cases/audio_summary.dart';
part 'skill_inference_runner_cases/entity_disappeared.dart';
part 'skill_inference_runner_cases/image_analysis_inputs.dart';
part 'skill_inference_runner_cases/image_analysis_persistence.dart';
part 'skill_inference_runner_cases/image_analysis_tiers.dart';
part 'skill_inference_runner_cases/image_generation_errors.dart';
part 'skill_inference_runner_cases/image_generation_inputs.dart';
part 'skill_inference_runner_cases/image_generation_results.dart';
part 'skill_inference_runner_cases/prompt_generation_inputs.dart';
part 'skill_inference_runner_cases/prompt_generation_links.dart';
part 'skill_inference_runner_cases/prompt_generation_persistence.dart';
part 'skill_inference_runner_cases/prompt_generation_properties.dart';
part 'skill_inference_runner_cases/prompt_generation_routing.dart';
part 'skill_inference_runner_cases/prompt_generation_scenarios.dart';
part 'skill_inference_runner_cases/test_setup.dart';
part 'skill_inference_runner_cases/transcription.dart';
part 'skill_inference_runner_cases/transcription_context_and_errors.dart';
part 'skill_inference_runner_cases/transcription_summary.dart';

void main() {
  final setup = _SkillInferenceTestSetup()..registerLifecycle();

  group('SkillInferenceRunner', () {
    group('runTranscription', () {
      setup
        ..registerTranscription()
        ..registerTranscriptionContextAndErrors();
    });
    group('runImageAnalysis', () {
      setup
        ..registerImageAnalysisGuards()
        ..registerImageAnalysisTiers()
        ..registerImageAnalysisPersistence()
        ..registerImageAnalysisInputsAndOverrides();
    });
    setup
      ..registerTranscriptionSummary()
      ..registerAudioSummary();
    group('runPromptGeneration', () {
      setup
        ..registerPromptGenerationGuards()
        ..registerPromptGenerationImages()
        ..registerPromptGenerationAttribution()
        ..registerPromptGenerationNoteInputs()
        ..registerPromptGenerationModelSelection()
        ..registerPromptGenerationPersistence()
        ..registerPromptGenerationTranscriptInputs()
        ..registerPromptGenerationProperties()
        ..registerPromptGenerationFailure()
        ..registerPromptGenerationSkillIdentity()
        ..registerPromptGenerationLinks();
    });
    group('runImageGeneration', () {
      setup
        ..registerImageGenerationGuards()
        ..registerImageGenerationSourceAndCoverArt()
        ..registerImageGenerationOverrides()
        ..registerImageGenerationAccountingAndErrors()
        ..registerImageGenerationTranscriptInput()
        ..registerImageGenerationFailure()
        ..registerImageGenerationResult()
        ..registerImageGenerationPersistenceErrors()
        ..registerImageGenerationReferenceImages();
    });
    setup.registerEntityDisappeared();

    test(
      'skillInferenceRunnerProvider wires the runner to the watched input '
      'repository and reports its failures on the container it lives in',
      () async {
        final providerContainer = ProviderContainer(
          overrides: [
            cloudInferenceRepositoryProvider.overrideWithValue(
              setup.mockCloudRepo,
            ),
            aiInputRepositoryProvider.overrideWithValue(setup.mockAiInputRepo),
            journalRepositoryProvider.overrideWithValue(setup.mockJournalRepo),
            aiConfigRepositoryProvider.overrideWithValue(
              setup.mockAiConfigRepo,
            ),
          ],
        );
        addTearDown(providerContainer.dispose);
        when(
          () => setup.mockAiInputRepo.getEntity('audio-gone'),
        ).thenAnswer((_) async => null);

        await providerContainer
            .read(skillInferenceRunnerProvider)
            .runTranscription(
              audioEntryId: 'audio-gone',
              automationResult: setup.makeTranscriptionResult(),
            );

        verify(() => setup.mockAiInputRepo.getEntity('audio-gone')).called(1);
        expect(
          providerContainer.read(
            inferenceStatusControllerProvider((
              id: 'audio-gone',
              aiResponseType: AiResponseType.audioTranscription,
            )),
          ),
          InferenceStatus.error,
        );
      },
    );

    group('AutomationResult', () {
      test('transcription result has correct fields', () {
        final result = setup.makeTranscriptionResult();

        expect(result.handled, isTrue);
        expect(result.skill!.skillType, SkillType.transcription);
        expect(result.resolvedProfile!.transcriptionProvider, isNotNull);
        expect(result.resolvedProfile!.transcriptionModelId, 'whisper-1');
      });

      test('image analysis result has correct fields', () {
        final result = setup.makeImageAnalysisResult();

        expect(result.handled, isTrue);
        expect(result.skill!.skillType, SkillType.imageAnalysis);
        expect(
          result.resolvedProfile!.imageRecognitionProvider,
          isNotNull,
        );
        expect(
          result.resolvedProfile!.imageRecognitionModelId,
          'vision-model',
        );
      });
    });
  });
}
