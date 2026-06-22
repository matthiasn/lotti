import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_task_structuring_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../../ai/test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  late MockCloudInferenceRepository cloudRepo;
  late MockAiConfigRepository aiConfigRepo;
  late MockCategoryRepository categoryRepo;
  late MockDomainLogger logger;
  late OnboardingTaskStructuringService service;

  const categoryId = 'cat-1';
  final provider = AiTestDataFactory.createTestProvider(
    id: 'prov-1',
    apiKey: 'sk-test',
    baseUrl: 'https://api.test',
  );

  /// Captured invocation of the last stubbed `generate()` call, so tests can
  /// assert the resolved model id, temperature, and trimmed transcript.
  Invocation? lastGenerate;

  CreateChatCompletionStreamResponse chunk(String content) =>
      CreateChatCompletionStreamResponse(
        id: 'r',
        object: 'chat.completion.chunk',
        created: 0,
        choices: [
          ChatCompletionStreamResponseChoice(
            delta: ChatCompletionStreamResponseDelta(content: content),
            index: 0,
          ),
        ],
      );

  void stubCategory({String? defaultProfileId}) {
    when(() => categoryRepo.getCategoryById(categoryId)).thenAnswer(
      (_) async => CategoryTestUtils.createTestCategory(
        id: categoryId,
        name: 'AI',
        defaultProfileId: defaultProfileId,
      ),
    );
  }

  void stubConfig(String id, AiConfig? config) {
    when(() => aiConfigRepo.getConfigById(id)).thenAnswer((_) async => config);
  }

  void stubHappyResolution({bool isReasoningModel = false}) {
    stubCategory(defaultProfileId: 'prof-1');
    stubConfig(
      'prof-1',
      AiTestDataFactory.createTestProfile(
        id: 'prof-1',
        thinkingModelId: 'model-1',
      ),
    );
    stubConfig(
      'model-1',
      AiTestDataFactory.createTestModel(
        id: 'model-1',
        providerModelId: 'gemini-x',
        inferenceProviderId: 'prov-1',
        isReasoningModel: isReasoningModel,
      ),
    );
    stubConfig('prov-1', provider);
  }

  void stubGenerate(List<String> chunks) {
    when(
      () => cloudRepo.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
      ),
    ).thenAnswer((invocation) {
      lastGenerate = invocation;
      return Stream.fromIterable(chunks.map(chunk));
    });
  }

  void stubGenerateError(Object error) {
    when(
      () => cloudRepo.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
      ),
    ).thenAnswer(
      (_) => Stream<CreateChatCompletionStreamResponse>.error(error),
    );
  }

  Matcher throwsFailure(OnboardingStructuringFailure failure) => throwsA(
    isA<OnboardingStructuringException>().having(
      (e) => e.failure,
      'failure',
      failure,
    ),
  );

  setUp(() {
    cloudRepo = MockCloudInferenceRepository();
    aiConfigRepo = MockAiConfigRepository();
    categoryRepo = MockCategoryRepository();
    logger = MockDomainLogger();
    lastGenerate = null;
    service = OnboardingTaskStructuringService(
      cloudInferenceRepository: cloudRepo,
      aiConfigRepository: aiConfigRepo,
      categoryRepository: categoryRepo,
      logger: logger,
    );
  });

  group('structure — happy paths', () {
    test(
      'parses a title and ordered checklist items from streamed JSON',
      () async {
        stubHappyResolution();
        // Split across chunks to exercise stream accumulation.
        stubGenerate([
          '{"title":"Call the dentist",',
          '"items":["Find the number","Book a slot"]}',
        ]);

        final result = await service.structure(
          transcript: 'remind me to call the dentist and book a slot',
          categoryId: categoryId,
        );

        expect(result.title, 'Call the dentist');
        expect(result.checklistItems, ['Find the number', 'Book a slot']);
      },
    );

    test('strips code fences and surrounding prose before parsing', () async {
      stubHappyResolution();
      stubGenerate([
        'Sure! ```json\n{"title":"Buy milk","items":[]}\n``` done',
      ]);

      final result = await service.structure(
        transcript: 'buy milk',
        categoryId: categoryId,
      );

      expect(result.title, 'Buy milk');
      expect(result.checklistItems, isEmpty);
    });

    test('accepts object-shaped items and drops non-text entries', () async {
      stubHappyResolution();
      const json =
          '{"title":"Trip","items":['
          '{"title":"a"},{"text":"b"},{"name":"c"},{"foo":"d"},"e",123,""'
          ']}';
      stubGenerate([json]);

      final result = await service.structure(
        transcript: 'plan a trip',
        categoryId: categoryId,
      );

      // {"foo":"d"} has no text field, 123 is not a string/map, "" is empty.
      expect(result.checklistItems, ['a', 'b', 'c', 'e']);
    });

    test('returns an empty checklist when the model omits items', () async {
      stubHappyResolution();
      stubGenerate(['{"title":"Water the plants"}']);

      final result = await service.structure(
        transcript: 'water the plants',
        categoryId: categoryId,
      );

      expect(result.title, 'Water the plants');
      expect(result.checklistItems, isEmpty);
    });

    test('caps the checklist at eight items', () async {
      stubHappyResolution();
      final items = List.generate(12, (i) => '"step $i"').join(',');
      stubGenerate(['{"title":"Big","items":[$items]}']);

      final result = await service.structure(
        transcript: 'lots to do',
        categoryId: categoryId,
      );

      expect(result.checklistItems, hasLength(8));
      expect(result.checklistItems.first, 'step 0');
      expect(result.checklistItems.last, 'step 7');
    });

    test('clamps over-long title and items to their max lengths', () async {
      stubHappyResolution();
      final longTitle = 'A' * 200;
      final longItem = 'B' * 200;
      stubGenerate(['{"title":"$longTitle","items":["$longItem"]}']);

      final result = await service.structure(
        transcript: 'verbose',
        categoryId: categoryId,
      );

      expect(result.title.length, 120);
      expect(result.checklistItems.single.length, 100);
    });

    test(
      'sends the trimmed transcript and resolved provider settings',
      () async {
        stubHappyResolution();
        stubGenerate(['{"title":"X","items":[]}']);

        await service.structure(
          transcript: '   hello there   ',
          categoryId: categoryId,
        );

        expect(lastGenerate!.positionalArguments.first, 'hello there');
        expect(lastGenerate!.namedArguments[#temperature], 0.3);
        expect(lastGenerate!.namedArguments[#model], 'gemini-x');
        expect(lastGenerate!.namedArguments[#baseUrl], 'https://api.test');
        expect(lastGenerate!.namedArguments[#apiKey], 'sk-test');
        expect(
          lastGenerate!.namedArguments[#systemMessage],
          OnboardingTaskStructuringService.systemPrompt,
        );
      },
    );

    test('uses temperature 1.0 for reasoning models', () async {
      stubHappyResolution(isReasoningModel: true);
      stubGenerate(['{"title":"X","items":[]}']);

      await service.structure(transcript: 'hi', categoryId: categoryId);

      expect(lastGenerate!.namedArguments[#temperature], 1.0);
    });
  });

  group('structure — resolution failures map to noModel', () {
    test('missing category yields noModel and never calls the model', () async {
      when(
        () => categoryRepo.getCategoryById(categoryId),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.noModel),
      );
      verifyNever(
        () => cloudRepo.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
        ),
      );
    });

    test('category without a default profile yields noModel', () async {
      stubCategory();

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.noModel),
      );
    });

    test('unresolved profile yields noModel', () async {
      stubCategory(defaultProfileId: 'prof-1');
      stubConfig('prof-1', null);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.noModel),
      );
    });

    test('unresolved model yields noModel', () async {
      stubCategory(defaultProfileId: 'prof-1');
      stubConfig(
        'prof-1',
        AiTestDataFactory.createTestProfile(
          id: 'prof-1',
          thinkingModelId: 'model-1',
        ),
      );
      stubConfig('model-1', null);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.noModel),
      );
    });

    test('unresolved provider yields noModel', () async {
      stubCategory(defaultProfileId: 'prof-1');
      stubConfig(
        'prof-1',
        AiTestDataFactory.createTestProfile(
          id: 'prof-1',
          thinkingModelId: 'model-1',
        ),
      );
      stubConfig(
        'model-1',
        AiTestDataFactory.createTestModel(
          id: 'model-1',
          inferenceProviderId: 'prov-1',
        ),
      );
      stubConfig('prov-1', null);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.noModel),
      );
    });
  });

  group('structure — transcript and response failures', () {
    test(
      'empty transcript yields emptyTranscript without resolving a model',
      () async {
        await expectLater(
          service.structure(transcript: '   ', categoryId: categoryId),
          throwsFailure(OnboardingStructuringFailure.emptyTranscript),
        );
        verifyNever(() => categoryRepo.getCategoryById(any()));
      },
    );

    test('request error yields requestFailed', () async {
      stubHappyResolution();
      stubGenerateError(Exception('network down'));

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.requestFailed),
      );
    });

    test('blank completion yields emptyResponse', () async {
      stubHappyResolution();
      stubGenerate(['   ']);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.emptyResponse),
      );
    });

    test('completion with no JSON object yields parseError', () async {
      stubHappyResolution();
      stubGenerate(['no json here at all']);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.parseError),
      );
    });

    test('reversed braces (no real object) yields parseError', () async {
      stubHappyResolution();
      stubGenerate(['}{']);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.parseError),
      );
    });

    test('malformed JSON inside braces yields parseError', () async {
      stubHappyResolution();
      stubGenerate(['{title: not valid, }']);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.parseError),
      );
    });

    test('JSON without a usable title yields parseError', () async {
      stubHappyResolution();
      stubGenerate(['{"title":"  ","items":["a"]}']);

      await expectLater(
        service.structure(transcript: 'x', categoryId: categoryId),
        throwsFailure(OnboardingStructuringFailure.parseError),
      );
    });
  });

  group('value object', () {
    test('equality is structural over title and items', () {
      const a = OnboardingStructuredTask(
        title: 'T',
        checklistItems: ['x', 'y'],
      );
      const b = OnboardingStructuredTask(
        title: 'T',
        checklistItems: ['x', 'y'],
      );
      const c = OnboardingStructuredTask(title: 'T', checklistItems: ['x']);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('T'));
    });

    test('exception stringifies its failure reason', () {
      const ex = OnboardingStructuringException(
        OnboardingStructuringFailure.parseError,
      );
      expect(ex.toString(), contains('parseError'));
    });
  });

  group('provider wiring', () {
    setUp(() {
      // The provider builds the service without an explicit logger, so the
      // getIt fallback must resolve.
      if (!getIt.isRegistered<DomainLogger>()) {
        getIt.registerSingleton<DomainLogger>(MockDomainLogger());
      }
    });
    tearDown(() async {
      await getIt.reset();
    });

    test(
      'builds a service from the app providers that structures end-to-end',
      () async {
        final container = ProviderContainer(
          overrides: [
            cloudInferenceRepositoryProvider.overrideWithValue(cloudRepo),
            aiConfigRepositoryProvider.overrideWithValue(aiConfigRepo),
            categoryRepositoryProvider.overrideWithValue(categoryRepo),
          ],
        );
        addTearDown(container.dispose);

        stubHappyResolution();
        stubGenerate(['{"title":"Wired","items":[]}']);

        final wired = container.read(onboardingTaskStructuringServiceProvider);
        final result = await wired.structure(
          transcript: 'hello',
          categoryId: categoryId,
        );

        // Proves the provider resolved the real cloud/ai-config/category repos.
        expect(result.title, 'Wired');
      },
    );
  });
}
