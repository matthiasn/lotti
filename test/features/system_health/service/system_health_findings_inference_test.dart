import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/service/system_health_findings_inference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';

void main() {
  late MockCloudInferenceRepository inference;
  late MockAiConfigRepository configs;
  late SystemHealthFindingsInference subject;

  final provider = testInferenceProvider(apiKey: 'k-123');
  final model = testAiModel(inferenceProviderId: provider.id);

  Stream<CreateChatCompletionStreamResponse> streamOf(List<String?> parts) =>
      Stream.fromIterable([
        const CreateChatCompletionStreamResponse(
          id: 'keepalive',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [],
        ),
        for (final part in parts)
          CreateChatCompletionStreamResponse(
            id: 'chunk',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: part),
              ),
            ],
          ),
      ]);

  setUpAll(() {
    registerFallbackValue(provider);
  });

  setUp(() {
    inference = MockCloudInferenceRepository();
    configs = MockAiConfigRepository();
    subject = SystemHealthFindingsInference(
      inferenceRepository: inference,
      aiConfigRepository: configs,
    );
  });

  test('resolves the provider and accumulates the streamed text', () async {
    when(
      () => configs.getConfigById(provider.id),
    ).thenAnswer((_) async => provider);
    Invocation? call;
    when(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
        impactCollector: any(named: 'impactCollector'),
      ),
    ).thenAnswer((invocation) {
      call = invocation;
      return streamOf(['### One', null, '\nTwo']);
    });

    final text = await subject.write(
      systemMessage: 'system',
      prompt: 'digest',
      model: model,
    );

    expect(text, '### One\nTwo');
    final named = call!.namedArguments;
    expect(call!.positionalArguments.single, 'digest');
    expect(named[#model], model.providerModelId);
    expect(named[#temperature], 0.2);
    expect(named[#baseUrl], provider.baseUrl);
    expect(named[#apiKey], 'k-123');
    expect(named[#systemMessage], 'system');
    expect(named[#maxCompletionTokens], 2048);
    expect(named[#provider], provider);
    expect(named[#geminiThinkingMode], model.geminiThinkingMode);
    expect(named[#impactCollector], isNotNull);
  });

  test('throws when the provider is missing', () async {
    when(
      () => configs.getConfigById(provider.id),
    ).thenAnswer((_) async => null);

    await expectLater(
      subject.write(systemMessage: 's', prompt: 'p', model: model),
      throwsA(isA<StateError>()),
    );
    verifyNever(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
      ),
    );
  });

  test('throws when the provider has no API key', () async {
    final keyless = testInferenceProvider(apiKey: '');
    when(() => configs.getConfigById(provider.id)).thenAnswer(
      (_) async => keyless,
    );

    await expectLater(
      subject.write(systemMessage: 's', prompt: 'p', model: model),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('missing or has no API key'),
        ),
      ),
    );
  });

  test('throws when the config is not a provider', () async {
    when(() => configs.getConfigById(provider.id)).thenAnswer(
      (_) async => testAiModel(),
    );

    await expectLater(
      subject.write(systemMessage: 's', prompt: 'p', model: model),
      throwsA(isA<StateError>()),
    );
  });
}
