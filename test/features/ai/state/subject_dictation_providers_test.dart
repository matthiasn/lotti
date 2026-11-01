import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/audio_transcription_service.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/ai/util/inference_provider_resolver.dart';
import 'package:lotti/providers/service_providers.dart'
    show domainLoggerProvider;
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';

void main() {
  late MockProfileAutomationResolver resolver;
  late MockAudioTranscriptionService transcriber;
  late MockSherpaModelRepository embeddedModels;
  late MockDomainLogger logger;
  late ProviderContainer container;

  const subjectId = 'goal-entry';

  AiConfigModel speechModel({
    String providerModelId = 'whisper-1',
    List<Modality> output = const [Modality.text],
  }) => testAiModel(providerModelId: providerModelId).copyWith(
    inputModalities: const [Modality.audio],
    outputModalities: output,
  );

  final whisper = testInferenceProvider(
    id: 'whisper',
    inferenceProviderType: InferenceProviderType.whisper,
  );
  final editor = testAiModel(
    id: 'editor',
    providerModelId: 'editor-native',
  ).copyWith(supportsFunctionCalling: true);

  ResolvedProfile profile({
    AiConfigInferenceProvider? provider,
    AiConfigModel? model,
    AiConfigModel? postProcessing,
  }) => ResolvedProfile(
    profileId: 'goals-profile',
    thinkingModelId: 'thinking',
    thinkingProvider: testInferenceProvider(),
    transcriptionModelId: (model ?? speechModel()).providerModelId,
    transcriptionProvider: provider ?? whisper,
    transcriptionModel: model ?? speechModel(),
    audioPostProcessingModelId: postProcessing?.providerModelId,
    audioPostProcessingProvider: postProcessing == null
        ? null
        : testInferenceProvider(id: 'editor-provider'),
    audioPostProcessingModel: postProcessing,
  );

  void stubCategory(String? categoryId) => when(
    () => resolver.categoryOfSubject(subjectId),
  ).thenAnswer((_) async => categoryId);

  void stubProfile(ResolvedProfile? value) => when(
    () => resolver.resolveTranscriptionProfile(
      categoryId: any(named: 'categoryId'),
    ),
  ).thenAnswer((_) async => value);

  SubjectDictation dictation() =>
      container.read(subjectDictationProvider(subjectId));

  setUpAll(registerAllFallbackValues);

  setUp(() {
    resolver = MockProfileAutomationResolver();
    transcriber = MockAudioTranscriptionService();
    embeddedModels = MockSherpaModelRepository();
    logger = MockDomainLogger();
    when(() => embeddedModels.isAvailable(any())).thenAnswer((_) async => true);
    stubCategory('goals');
    stubProfile(profile());
    container = ProviderContainer(
      overrides: [
        profileAutomationResolverProvider.overrideWithValue(resolver),
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
        sherpaModelRepositoryProvider.overrideWithValue(embeddedModels),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);
  });

  group('resolveTarget', () {
    test(
      "is the transcription slot of the subject's category's profile",
      () async {
        final target = await dictation().resolveTarget();

        expect(target.provider, same(whisper));
        expect(target.model.providerModelId, 'whisper-1');
        verify(
          () => resolver.resolveTranscriptionProfile(categoryId: 'goals'),
        ).called(1);
      },
    );

    test('a subject in no category asks for the default', () async {
      stubCategory(null);

      await dictation().resolveTarget();

      verify(() => resolver.resolveTranscriptionProfile()).called(1);
    });

    final unusable = <String, void Function()>{
      'no profile can transcribe': () => stubProfile(null),
      'the slot names no model row': () => stubProfile(
        ResolvedProfile(
          thinkingModelId: 'thinking',
          thinkingProvider: testInferenceProvider(),
          transcriptionModelId: 'whisper-1',
          transcriptionProvider: whisper,
        ),
      ),
      'the model does not take audio': () =>
          stubProfile(profile(model: testAiModel())),
      'the model does not answer in text': () => stubProfile(
        profile(model: speechModel(output: const [Modality.audio])),
      ),
      'the model serves only the realtime API': () => stubProfile(
        profile(
          provider: testInferenceProvider(
            inferenceProviderType: InferenceProviderType.mistral,
          ),
          model: speechModel(
            providerModelId: 'voxtral-mini-transcribe-realtime-2602',
          ),
        ),
      ),
      'the embedded model is not installed here': () {
        when(
          () => embeddedModels.isAvailable('whisper-1'),
        ).thenAnswer((_) async => false);
        stubProfile(
          profile(
            provider: testInferenceProvider(
              inferenceProviderType: InferenceProviderType.sherpa,
            ),
          ),
        );
      },
    };
    for (final MapEntry(key: name, value: arrange) in unusable.entries) {
      test('fails as "no audio model" when $name — never a discovered '
          'model', () async {
        arrange();

        await expectLater(
          dictation().resolveTarget(),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('No audio-capable models'),
            ),
          ),
        );
        verifyNever(() => transcriber.discoverTarget());
      });
    }
  });

  group('correct', () {
    final heardByWhisper = (provider: whisper, model: speechModel());

    void stubCorrection() => when(
      () => transcriber.correctTranscript(
        any(),
        target: any(named: 'target'),
        dictionaryCategoryId: any(named: 'dictionaryCategoryId'),
      ),
    ).thenAnswer((call) async => '${call.positionalArguments.first}!');

    test(
      "corrects a speech-to-text engine's words on the profile's "
      'post-processing model, against the category dictionary',
      () async {
        stubProfile(profile(postProcessing: editor));
        stubCorrection();

        final words = await dictation().correct('Pip', heardByWhisper);

        expect(words, 'Pip!');
        final target =
            verify(
                  () => transcriber.correctTranscript(
                    'Pip',
                    target: captureAny(named: 'target'),
                    dictionaryCategoryId: 'goals',
                  ),
                ).captured.single
                as ResolvedInferenceProvider;
        expect(target.model, same(editor));
      },
    );

    test(
      'leaves a multimodal model alone: it read the dictionary itself',
      () async {
        final words = await dictation().correct('Pip', (
          provider: testInferenceProvider(),
          model: testAiModel(),
        ));

        expect(words, 'Pip');
        verifyNever(() => resolver.categoryOfSubject(any()));
      },
    );

    test(
      'keeps the words when no model can call the correction tool',
      () async {
        // The thinking fallback has no model row, so nothing can correct.
        final words = await dictation().correct('Pip', heardByWhisper);

        expect(words, 'Pip');
        verifyNever(
          () => transcriber.correctTranscript(
            any(),
            target: any(named: 'target'),
            dictionaryCategoryId: any(named: 'dictionaryCategoryId'),
          ),
        );
      },
    );

    test('a correction that fails is logged and keeps the words', () async {
      stubProfile(profile(postProcessing: editor));
      when(
        () => transcriber.correctTranscript(
          any(),
          target: any(named: 'target'),
          dictionaryCategoryId: any(named: 'dictionaryCategoryId'),
        ),
      ).thenThrow(StateError('offline'));

      final words = await dictation().correct('Pip', heardByWhisper);

      expect(words, 'Pip');
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'SubjectDictation',
          message:
              'Could not correct dictation for '
              '${DomainLogger.sanitizeId(subjectId)}',
        ),
      ).called(1);
    });
  });
}
