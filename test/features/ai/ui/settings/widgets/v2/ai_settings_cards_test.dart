import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../../widget_test_utils.dart';

AiConfigInferenceProvider _provider({
  required InferenceProviderType type,
  String name = 'My Provider',
  String apiKey = 'sk-test',
  String baseUrl = 'https://api.example.com',
  String id = 'provider-1',
}) {
  return AiConfigInferenceProvider(
    id: id,
    name: name,
    inferenceProviderType: type,
    apiKey: apiKey,
    baseUrl: baseUrl,
    createdAt: DateTime(2024, 3, 15),
  );
}

AiConfigModel _model({
  required String providerId,
  String id = 'model-1',
  String name = 'Test Model',
  String providerModelId = 'test-model-id',
  bool isReasoning = true,
  List<Modality> inputModalities = const [Modality.text, Modality.image],
  List<Modality> outputModalities = const [Modality.text],
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: providerId,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: inputModalities,
    outputModalities: outputModalities,
    isReasoningModel: isReasoning,
  );
}

AiConfigInferenceProfile _profile({
  String id = 'profile-1',
  String name = 'Test Profile',
  String? description = 'A test profile',
  bool isDefault = false,
  String thinking = 'test-model-id',
  String? imageRecognition,
  String? transcription,
  String? imageGeneration,
}) {
  return AiConfigInferenceProfile(
    id: id,
    name: name,
    description: description,
    thinkingModelId: thinking,
    imageRecognitionModelId: imageRecognition,
    transcriptionModelId: transcription,
    imageGenerationModelId: imageGeneration,
    isDefault: isDefault,
    createdAt: DateTime(2024, 3, 15),
  );
}

void main() {
  group('AiProviderCard.statusFor', () {
    test('cloud provider with non-empty API key → connected', () {
      expect(
        AiProviderCard.statusFor(
          provider: _provider(
            type: InferenceProviderType.anthropic,
            apiKey: 'sk-ant-test',
          ),
          modelCount: 2,
        ),
        equals(AiProviderCardStatus.connected),
      );
    });

    test('cloud provider with blank API key → invalidKey', () {
      expect(
        AiProviderCard.statusFor(
          provider: _provider(
            type: InferenceProviderType.openAi,
            apiKey: '   ',
          ),
          modelCount: 0,
        ),
        equals(AiProviderCardStatus.invalidKey),
      );
    });

    test('Ollama with base URL + at least one model → connected', () {
      expect(
        AiProviderCard.statusFor(
          provider: _provider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: 'http://localhost:11434',
          ),
          modelCount: 1,
        ),
        equals(AiProviderCardStatus.connected),
      );
    });

    test('Ollama with no models → offline (even with base URL)', () {
      expect(
        AiProviderCard.statusFor(
          provider: _provider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: 'http://localhost:11434',
          ),
          modelCount: 0,
        ),
        equals(AiProviderCardStatus.offline),
      );
    });

    test('Ollama with blank base URL → offline', () {
      expect(
        AiProviderCard.statusFor(
          provider: _provider(
            type: InferenceProviderType.ollama,
            apiKey: '',
            baseUrl: '',
          ),
          modelCount: 5,
        ),
        equals(AiProviderCardStatus.offline),
      );
    });

    // Local providers (`ProviderConfig.noApiKeyRequired`) all share the
    // base-URL + model-count gate. Voxtral and Whisper used to fall
    // through the cloud branch and surface `invalidKey` because they
    // never carry an API key — same shape as Ollama, different enum.
    for (final type in const [
      InferenceProviderType.voxtral,
      InferenceProviderType.whisper,
    ]) {
      test('$type with base URL + at least one model → connected', () {
        expect(
          AiProviderCard.statusFor(
            provider: _provider(
              type: type,
              apiKey: '',
              baseUrl: 'http://localhost:11344',
            ),
            modelCount: 2,
          ),
          equals(AiProviderCardStatus.connected),
        );
      });

      test('$type with no models → offline (never invalidKey)', () {
        expect(
          AiProviderCard.statusFor(
            provider: _provider(
              type: type,
              apiKey: '',
              baseUrl: 'http://localhost:11344',
            ),
            modelCount: 0,
          ),
          equals(AiProviderCardStatus.offline),
        );
      });

      test('$type with blank base URL → offline (never invalidKey)', () {
        expect(
          AiProviderCard.statusFor(
            provider: _provider(type: type, apiKey: '', baseUrl: ''),
            modelCount: 5,
          ),
          equals(AiProviderCardStatus.offline),
        );
      });
    }
  });

  group('AiProviderCard rendering', () {
    testWidgets(
      'connected variant shows the provider name, tagline, and connected '
      'status with a model count',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(
                type: InferenceProviderType.gemini,
                name: 'My Google Gemini',
              ),
              modelCount: 3,
              status: AiProviderCardStatus.connected,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('My Google Gemini'), findsOneWidget);
        expect(
          find.textContaining('Multimodal'),
          findsOneWidget,
          reason: 'Gemini tagline should render',
        );
        expect(find.text('Connected'), findsOneWidget);
        expect(find.textContaining('3 models'), findsOneWidget);
      },
    );

    testWidgets(
      'invalidKey variant shows the generic "Invalid key" copy and exposes '
      'the inline Fix CTA when onFix is non-null',
      (tester) async {
        var fixTaps = 0;
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(
                type: InferenceProviderType.openAi,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.invalidKey,
              onTap: () {},
              onFix: () => fixTaps++,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Invalid key'), findsOneWidget);
        expect(find.text('Fix'), findsOneWidget);

        await tester.tap(find.text('Fix'));
        await tester.pump();
        expect(fixTaps, equals(1));
      },
    );

    testWidgets(
      'invalidKey variant hides the Fix CTA when onFix is null',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(
                type: InferenceProviderType.openAi,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.invalidKey,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Invalid key'), findsOneWidget);
        expect(find.text('Fix'), findsNothing);
      },
    );

    testWidgets(
      'offline variant shows the Ollama hint instead of a model-count tail',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(
                type: InferenceProviderType.ollama,
                apiKey: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.offline,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Offline'), findsOneWidget);
        expect(
          find.textContaining('Ollama is running'),
          findsOneWidget,
          reason: 'The offline-variant card surfaces the Ollama hint.',
        );
      },
    );

    testWidgets('tapping anywhere on the card body fires onTap', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          AiProviderCard(
            provider: _provider(type: InferenceProviderType.gemini),
            modelCount: 1,
            status: AiProviderCardStatus.connected,
            onTap: () => tapped++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(AiProviderCard));
      await tester.pump();
      expect(tapped, equals(1));
    });

    testWidgets(
      'a provider record with an empty `name` falls back to the visual '
      'displayName (the localised provider label)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(
                type: InferenceProviderType.anthropic,
                name: '',
              ),
              modelCount: 0,
              status: AiProviderCardStatus.connected,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        // Falls back to the visual.displayName mapping in
        // ai_provider_visual.dart, which for Anthropic is
        // `aiProviderAnthropicName` ("Anthropic Claude" in en).
        expect(find.text('Anthropic Claude'), findsOneWidget);
      },
    );

    testWidgets(
      'connected variant with a lastUsedLabel renders the "{n} models · '
      '{label}" tail copy',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderCard(
              provider: _provider(type: InferenceProviderType.gemini),
              modelCount: 2,
              status: AiProviderCardStatus.connected,
              onTap: () {},
              lastUsedLabel: 'last 2m ago',
            ),
          ),
        );
        await tester.pump();
        // The combined-tail localisation pairs the model count and the
        // last-used clause.
        expect(find.textContaining('2 models'), findsOneWidget);
        expect(find.textContaining('last 2m ago'), findsOneWidget);
      },
    );
  });

  group('AiModelCard rendering', () {
    testWidgets(
      'shows the model name, provider model id, and the capability chips '
      'derived from the model flags',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiModelCard(
              model: _model(
                providerId: 'p1',
                name: 'Gemini 3 Flash',
                providerModelId: 'gemini-3-flash-preview',
              ),
              providerType: InferenceProviderType.gemini,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Gemini 3 Flash'), findsOneWidget);
        expect(find.text('gemini-3-flash-preview'), findsOneWidget);
        // Reasoning + image modality should yield two chips.
        expect(find.text('Thinking'), findsOneWidget);
        expect(find.text('Image recognition'), findsOneWidget);
      },
    );

    testWidgets(
      'does NOT render an on/off toggle — tweak 2 explicitly removed it',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiModelCard(
              model: _model(providerId: 'p1'),
              providerType: InferenceProviderType.gemini,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Switch), findsNothing);
      },
    );
  });

  group('AiProfileCard rendering', () {
    testWidgets(
      'default (isDefault: true) profiles render the Active badge',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProfileCard(
              profile: _profile(
                name: 'Gemini Flash',
                description: 'Fast multimodal default',
                isDefault: true,
              ),
              isActive: true,
              providerTypeFor: () => InferenceProviderType.gemini,
              modelLookup: (id) => 'Gemini 3 Flash',
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Fast multimodal default'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
      },
    );

    testWidgets(
      'non-active profiles render without the Active badge',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProfileCard(
              profile: _profile(name: 'Custom Profile'),
              isActive: false,
              providerTypeFor: () => InferenceProviderType.gemini,
              modelLookup: (id) => 'Some Model',
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Active'), findsNothing);
      },
    );

    testWidgets(
      'task→model mapping rows render only for assigned slots; unassigned '
      'slots are skipped',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProfileCard(
              profile: _profile(
                thinking: 'reasoning-id',
                imageRecognition: 'vision-id',
                // transcription + imageGeneration left null.
              ),
              isActive: false,
              providerTypeFor: () => InferenceProviderType.anthropic,
              modelLookup: (id) =>
                  id == 'reasoning-id' ? 'Reasoning Model' : 'Vision Model',
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Thinking'), findsOneWidget);
        expect(find.text('Reasoning Model'), findsOneWidget);
        expect(find.text('Image recognition'), findsOneWidget);
        expect(find.text('Vision Model'), findsOneWidget);
        expect(
          find.text('Transcription'),
          findsNothing,
          reason: 'Unassigned slot should not render a row.',
        );
        expect(find.text('Image generation'), findsNothing);
      },
    );

    testWidgets(
      'unresolved model ids render the "missing" placeholder in the warning '
      'tone — surfaces dangling references after a model was deleted',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProfileCard(
              profile: _profile(thinking: 'deleted-model-id'),
              isActive: false,
              providerTypeFor: () => InferenceProviderType.anthropic,
              modelLookup: (id) => null,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('missing'), findsOneWidget);
      },
    );
  });

  group('modelCapabilityLabels (shared helper)', () {
    test('reasoning flag emits the Thinking chip', () {
      final labels = modelCapabilityLabels(
        messages: AppLocalizationsEn(),
        isReasoning: true,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
      );
      expect(labels, contains('Thinking'));
    });

    test('image input emits Image recognition', () {
      final labels = modelCapabilityLabels(
        messages: AppLocalizationsEn(),
        isReasoning: false,
        inputModalities: const [Modality.image],
        outputModalities: const [Modality.text],
      );
      expect(labels, contains('Image recognition'));
    });

    test('audio input emits Transcription', () {
      final labels = modelCapabilityLabels(
        messages: AppLocalizationsEn(),
        isReasoning: false,
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
      );
      expect(labels, contains('Transcription'));
    });

    test('image output emits Image generation', () {
      final labels = modelCapabilityLabels(
        messages: AppLocalizationsEn(),
        isReasoning: false,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.image],
      );
      expect(labels, contains('Image generation'));
    });

    test('text-only / no-flags model returns no chips', () {
      final labels = modelCapabilityLabels(
        messages: AppLocalizationsEn(),
        isReasoning: false,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
      );
      expect(labels, isEmpty);
    });
  });

  // Helper assertion the test bodies above lean on: badges render as
  // DesignSystemBadge widgets so they're tappable / styled per DS, not
  // raw Container chips.
  testWidgets('Active + capability chips render as DesignSystemBadge widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        AiProfileCard(
          profile: _profile(isDefault: true),
          isActive: true,
          providerTypeFor: () => InferenceProviderType.gemini,
          modelLookup: (id) => 'Mock Model',
          onTap: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DesignSystemBadge), findsWidgets);
  });
}
