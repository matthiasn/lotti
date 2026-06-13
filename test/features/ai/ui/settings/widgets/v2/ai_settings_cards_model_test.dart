import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../../widget_test_utils.dart';
import 'ai_settings_cards_test_helpers.dart';

void main() {
  group('AiModelCard rendering', () {
    testWidgets(
      'shows the model name, provider model id, and the capability chips '
      'derived from the model flags',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiModelCard(
              model: hModel(
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
              model: hModel(providerId: 'p1'),
              providerType: InferenceProviderType.gemini,
              onTap: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Switch), findsNothing);
      },
    );

    testWidgets('shows MLX download progress and opens the progress action', (
      tester,
    ) async {
      var installTaps = 0;

      await tester.pumpWidget(
        makeTestableWidget(
          AiModelCard(
            model: hModel(
              providerId: 'mlx-provider',
              name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
              providerModelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
              isReasoning: false,
              inputModalities: const [Modality.audio],
            ),
            providerType: InferenceProviderType.mlxAudio,
            modelDownloadProgress: const MlxAudioModelDownloadProgress(
              modelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
              status: MlxAudioModelStatus.downloading,
              completedUnitCount: 42,
              totalUnitCount: 100,
            ),
            onTap: () {},
            onInstallModel: () => installTaps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Downloading 42%'), findsOneWidget);
      expect(find.byTooltip('Show download progress'), findsOneWidget);

      await tester.tap(find.byTooltip('Show download progress'));
      await tester.pump();

      expect(installTaps, 1);
    });

    testWidgets(
      'shows the indeterminate MLX downloading label when no percent is known',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiModelCard(
              model: hModel(
                providerId: 'mlx-provider',
                name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
                providerModelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
                isReasoning: false,
                inputModalities: const [Modality.audio],
              ),
              providerType: InferenceProviderType.mlxAudio,
              modelDownloadProgress: const MlxAudioModelDownloadProgress(
                modelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
                status: MlxAudioModelStatus.downloading,
              ),
              onTap: () {},
              onInstallModel: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Downloading'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
      },
    );

    testWidgets('shows the MLX install action when a model is missing', (
      tester,
    ) async {
      var installTaps = 0;

      await tester.pumpWidget(
        makeTestableWidget(
          AiModelCard(
            model: hModel(
              providerId: 'mlx-provider',
              providerModelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
              isReasoning: false,
              inputModalities: const [Modality.audio],
            ),
            providerType: InferenceProviderType.mlxAudio,
            modelDownloadProgress: const MlxAudioModelDownloadProgress(
              modelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
              status: MlxAudioModelStatus.notInstalled,
            ),
            onTap: () {},
            onInstallModel: () => installTaps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not installed'), findsOneWidget);
      expect(find.byTooltip('Install model'), findsOneWidget);

      await tester.tap(find.byTooltip('Install model'));
      await tester.pump();

      expect(installTaps, 1);
    });

    testWidgets('renders MLX terminal and unknown download states', (
      tester,
    ) async {
      for (final statusCase in const [
        (null, 'Checking model status', null),
        (MlxAudioModelStatus.installed, 'Installed', null),
        (MlxAudioModelStatus.unsupported, 'Apple Silicon required', null),
        (MlxAudioModelStatus.failed, 'Download failed', 'Install model'),
      ]) {
        var installTaps = 0;

        await tester.pumpWidget(
          makeTestableWidget(
            AiModelCard(
              model: hModel(
                providerId: 'mlx-provider',
                providerModelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
                isReasoning: false,
                inputModalities: const [Modality.audio],
              ),
              providerType: InferenceProviderType.mlxAudio,
              modelDownloadProgress: statusCase.$1 == null
                  ? null
                  : MlxAudioModelDownloadProgress(
                      modelId: 'mlx-community/Qwen3-ASR-1.7B-8bit',
                      status: statusCase.$1!,
                    ),
              onTap: () {},
              onInstallModel: () => installTaps++,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(statusCase.$2), findsOneWidget);
        final tooltip = statusCase.$3;
        if (tooltip == null) {
          expect(find.byTooltip('Install model'), findsNothing);
          expect(find.byTooltip('Show download progress'), findsNothing);
        } else {
          expect(find.byTooltip(tooltip), findsOneWidget);
          await tester.tap(find.byTooltip(tooltip));
          await tester.pump();
          expect(installTaps, 1);
        }
      }
    });
  });

  group('AiProfileCard rendering', () {
    testWidgets(
      'default (isDefault: true) profiles render the Active badge',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProfileCard(
              profile: hProfile(
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
              profile: hProfile(name: 'Custom Profile'),
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
              profile: hProfile(
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
              profile: hProfile(thinking: 'deleted-model-id'),
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
          profile: hProfile(isDefault: true),
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
