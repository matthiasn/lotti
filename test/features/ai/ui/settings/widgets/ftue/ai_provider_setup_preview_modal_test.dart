import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_modal.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../widget_test_utils.dart';

AiConfigModel _existingModel({
  required String providerModelId,
  required String name,
  String providerId = 'provider-id',
}) {
  return AiConfigModel(
    id: 'model-$providerModelId',
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: providerId,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: const [Modality.text, Modality.image],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  );
}

void main() {
  group('AiProviderSetupPreviewModal.presetFor', () {
    test('returns models for Gemini', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.gemini,
      );
      expect(preset, isNotNull);
      expect(preset!.providerName, equals('Gemini'));
      expect(preset.profileName, equals('Gemini Flash'));
      expect(preset.categoryName, equals(ftueGeminiCategoryName));
      // Flash + Pro + Image.
      expect(preset.models, hasLength(3));
    });

    test('returns models for OpenAI', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.openAi,
      );
      expect(preset, isNotNull);
      expect(preset!.providerName, equals('OpenAI'));
      // Flash + Reasoning + Audio + Image.
      expect(preset.models, hasLength(4));
    });

    test('returns models for Mistral', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.mistral,
      );
      expect(preset, isNotNull);
      expect(preset!.providerName, equals('Mistral'));
      // Flash + Reasoning + Audio (no image gen).
      expect(preset.models, hasLength(3));
    });

    test('returns models for Melious', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.melious,
      );
      expect(preset, isNotNull);
      expect(preset!.providerName, equals('Melious.ai'));
      expect(preset.profileName, equals('Melious.ai'));
      expect(preset.categoryName, equals(ftueMeliousCategoryName));
      expect(
        preset.models.map((model) => model.providerModelId),
        containsAll([
          meliousMistralSmall4119BInstructModelId,
          meliousDeepseekV4ProModelId,
          meliousFlux2Klein9BModelId,
          meliousWhisperLargeV3TurboModelId,
          meliousWhisperLargeV3ModelId,
        ]),
      );
    });

    test('returns models for Alibaba', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.alibaba,
      );
      expect(preset, isNotNull);
      // Flash + Reasoning + Vision + Audio + Image.
      expect(preset!.models, hasLength(5));
    });

    test('returns models for Anthropic', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.anthropic,
      );
      expect(preset, isNotNull);
      expect(preset!.providerName, equals('Anthropic'));
      expect(preset.profileName, equals('Anthropic Claude'));
      // Reasoning (Sonnet) + Flash (Haiku).
      expect(preset.models, hasLength(2));
    });

    test('returns an empty preset for Ollama — no canonical model list', () {
      final preset = AiProviderSetupPreviewModal.presetFor(
        InferenceProviderType.ollama,
      );
      expect(preset, isNotNull);
      expect(preset!.models, isEmpty);
      expect(preset.categoryName, equals(ftueOllamaCategoryName));
    });

    test('returns null for provider types without an FTUE preset', () {
      expect(
        AiProviderSetupPreviewModal.presetFor(InferenceProviderType.openRouter),
        isNull,
      );
      expect(
        AiProviderSetupPreviewModal.presetFor(
          InferenceProviderType.genericOpenAi,
        ),
        isNull,
      );
    });
  });

  group('AiProviderSetupPreviewModal.skipsPreviewFor', () {
    test('skips the preview for Ollama (no model preset)', () {
      expect(
        AiProviderSetupPreviewModal.skipsPreviewFor(
          InferenceProviderType.ollama,
        ),
        isTrue,
      );
    });

    test('does not skip the preview for any cloud provider with a preset', () {
      for (final type in const [
        InferenceProviderType.gemini,
        InferenceProviderType.openAi,
        InferenceProviderType.melious,
        InferenceProviderType.mistral,
        InferenceProviderType.alibaba,
        InferenceProviderType.anthropic,
      ]) {
        expect(
          AiProviderSetupPreviewModal.skipsPreviewFor(type),
          isFalse,
          reason: '$type should NOT skip the preview',
        );
      }
    });

    test('skips the preview for unknown provider types (no preset)', () {
      expect(
        AiProviderSetupPreviewModal.skipsPreviewFor(
          InferenceProviderType.openRouter,
        ),
        isTrue,
      );
    });
  });

  group('AiProviderSetupPreviewModal.show', () {
    testWidgets(
      'treats preset models under a usable synced provider as already '
      'configured',
      (tester) async {
        final repository = MockAiConfigRepository();
        final geminiPreset = AiProviderSetupPreviewModal.presetFor(
          InferenceProviderType.gemini,
        )!;
        final existingProvider = AiConfig.inferenceProvider(
          id: 'synced-gemini-provider',
          name: 'Synced Gemini',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
          apiKey: 'synced-key',
          createdAt: DateTime(2024, 3, 15),
          inferenceProviderType: InferenceProviderType.gemini,
        );
        final existingModels = [
          for (final knownModel in geminiPreset.models)
            _existingModel(
              providerModelId: knownModel.providerModelId,
              name: knownModel.name,
              providerId: 'synced-gemini-provider',
            ),
        ];

        when(
          () => repository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => repository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [existingProvider]);

        AiProviderSetupPreviewResult? result;
        await tester.pumpWidget(
          makeTestableWidget(
            Consumer(
              builder: (context, ref, _) {
                return TextButton(
                  onPressed: () async {
                    result = await AiProviderSetupPreviewModal.show(
                      context: context,
                      ref: ref,
                      providerType: InferenceProviderType.gemini,
                      providerId: 'new-gemini-provider',
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
            overrides: [
              aiConfigRepositoryProvider.overrideWithValue(repository),
            ],
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.confirmed, isTrue);
        expect(result!.excludedProviderModelIds, isEmpty);
        expect(find.byType(AiProviderSetupPreviewModal), findsNothing);
      },
    );
  });

  group('AiProviderSetupPreviewModal widget body', () {
    final geminiPreset = AiProviderSetupPreviewModal.presetFor(
      InferenceProviderType.gemini,
    )!;

    testWidgets(
      'renders connected banner, profile preview, models section, '
      'category footer, and action buttons',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupPreviewModal(
              providerType: InferenceProviderType.gemini,
              preset: geminiPreset,
              existingModels: const <AiConfigModel>[],
            ),
          ),
        );
        await tester.pump();

        // Connected banner header and Live badge.
        expect(find.textContaining('Gemini connected'), findsOneWidget);
        expect(find.text('Live'), findsOneWidget);

        // Profile preview card carries the seeded profile name + "Set active".
        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Set active'), findsOneWidget);

        // Three model rows for Gemini — each row's provider model id is
        // rendered alongside the name.
        for (final km in geminiPreset.models) {
          expect(find.text(km.providerModelId), findsOneWidget);
        }

        // Footer actions.
        expect(find.text('Customize'), findsOneWidget);
        expect(find.text('Accept & finish'), findsOneWidget);
      },
    );

    testWidgets(
      'no "Already added" section when existingModels is empty',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupPreviewModal(
              providerType: InferenceProviderType.gemini,
              preset: geminiPreset,
              existingModels: const <AiConfigModel>[],
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Already added'), findsNothing);
      },
    );

    testWidgets(
      'renders a read-only "Already added" section when the provider already '
      'has models — confirms the per-row tweak that already-set models are '
      'displayed but cannot be unticked',
      (tester) async {
        final existing = [
          _existingModel(
            providerModelId: 'gpt-5-nano-old',
            name: 'GPT-5 Nano (Old)',
          ),
          _existingModel(
            providerModelId: 'gpt-5-pro-experimental',
            name: 'GPT-5 Pro Experimental',
          ),
        ];

        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupPreviewModal(
              providerType: InferenceProviderType.openAi,
              preset: AiProviderSetupPreviewModal.presetFor(
                InferenceProviderType.openAi,
              )!,
              existingModels: existing,
            ),
          ),
        );
        await tester.pump();

        // Section header.
        expect(find.textContaining('Already added'), findsOneWidget);

        // Read-only rows: names and ids are visible.
        expect(find.text('GPT-5 Nano (Old)'), findsOneWidget);
        expect(find.text('gpt-5-nano-old'), findsOneWidget);
        expect(find.text('GPT-5 Pro Experimental'), findsOneWidget);
        expect(find.text('gpt-5-pro-experimental'), findsOneWidget);

        // Checkbox semantics — there should be exactly one checkbox per
        // proposed new model (4 for OpenAI's preset). Read-only rows
        // intentionally have no checkbox; finding by the DS widget type
        // confirms the count without picking up any incidental Flutter
        // Checkbox the Material theme might render elsewhere.
        expect(find.byType(DesignSystemCheckbox), findsNWidgets(4));
      },
    );

    testWidgets(
      'Customize button pops with a cancelled result; Accept & finish pops '
      'with confirmed:true and the unticked-model set',
      (tester) async {
        AiProviderSetupPreviewResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    captured = await Navigator.of(context)
                        .push<AiProviderSetupPreviewResult>(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: SingleChildScrollView(
                                child: AiProviderSetupPreviewModal(
                                  providerType: InferenceProviderType.gemini,
                                  preset: geminiPreset,
                                  existingModels: const <AiConfigModel>[],
                                ),
                              ),
                            ),
                          ),
                        );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        );

        // Customize variant.
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Customize'));
        await tester.pumpAndSettle();
        expect(captured, isNotNull);
        expect(captured!.confirmed, isFalse);
        expect(captured!.excludedProviderModelIds, isEmpty);

        // Accept variant — untick the first model row first.
        captured = null;
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        // Tap the first DS checkbox to untick it.
        await tester.tap(find.byType(DesignSystemCheckbox).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accept & finish'));
        await tester.pumpAndSettle();
        expect(captured, isNotNull);
        expect(captured!.confirmed, isTrue);
        // The first preset model's id should now be in the excluded set.
        expect(
          captured!.excludedProviderModelIds,
          contains(geminiPreset.models.first.providerModelId),
        );
      },
    );

    /// Modular coverage for the connected-banner localised provider
    /// name resolution. The preset's `providerName` is the English
    /// brand alias used downstream by the result modal's accent map;
    /// the banner header itself MUST surface the localised display
    /// name (e.g. "Google Gemini") so the modal title and the banner
    /// header agree on what the provider is called in the user's
    /// locale.
    testWidgets(
      'banner header uses the localised AppLocalizations name '
      '(aiProviderGeminiName) for Gemini, NOT the English-only preset '
      'alias — guards against the regression where the title said '
      '"Google Gemini" while the banner said "Gemini"',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupPreviewModal(
              providerType: InferenceProviderType.gemini,
              preset: geminiPreset,
              existingModels: const <AiConfigModel>[],
            ),
          ),
        );
        await tester.pump();
        // Banner copy: "{Google Gemini} connected"
        expect(find.textContaining('Google Gemini'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'banner header uses the localised AppLocalizations name for OpenAI '
      '— covers the second per-provider arm of aiProviderDisplayName',
      (tester) async {
        final preset = AiProviderSetupPreviewModal.presetFor(
          InferenceProviderType.openAi,
        )!;
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupPreviewModal(
              providerType: InferenceProviderType.openAi,
              preset: preset,
              existingModels: const <AiConfigModel>[],
            ),
          ),
        );
        await tester.pump();
        // OpenAI's localized name is just "OpenAI" — but the banner
        // copy must include "OpenAI connected" assembled by the
        // localised template, not literal English-glued text.
        expect(find.textContaining('OpenAI connected'), findsOneWidget);
      },
    );
  });
}
