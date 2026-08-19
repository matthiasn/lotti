import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('InferenceProviderTypeExtension', () {
    group('icon', () {
      test('returns distinct icon for each provider type', () {
        final icons = <InferenceProviderType, IconData>{
          InferenceProviderType.alibaba: LottiIcons.cloud,
          InferenceProviderType.anthropic: LottiIcons.aiSpark,
          InferenceProviderType.openAi: LottiIcons.reasoning,
          InferenceProviderType.gemini: LottiIcons.gem,
          InferenceProviderType.melious: LottiIcons.eco,
          InferenceProviderType.mistral: LottiIcons.voice,
          InferenceProviderType.openRouter: LottiIcons.hub,
          InferenceProviderType.ollama: LottiIcons.computer,
          InferenceProviderType.genericOpenAi: LottiIcons.cloud,
          InferenceProviderType.nebiusAiStudio: LottiIcons.rocket,
          InferenceProviderType.omlx: LottiIcons.memory,
          InferenceProviderType.whisper: LottiIcons.mic,
          InferenceProviderType.voxtral: LottiIcons.waveform,
          InferenceProviderType.mlxAudio: LottiIcons.memory,
        };

        for (final entry in icons.entries) {
          expect(
            entry.key.icon,
            equals(entry.value),
            reason: '${entry.key} should have icon ${entry.value}',
          );
        }
      });

      test('the icon table is exhaustive over the enum', () {
        // Guards against new provider types silently missing a pinned icon.
        final pinned = <InferenceProviderType>{
          InferenceProviderType.alibaba,
          InferenceProviderType.anthropic,
          InferenceProviderType.openAi,
          InferenceProviderType.gemini,
          InferenceProviderType.melious,
          InferenceProviderType.mistral,
          InferenceProviderType.openRouter,
          InferenceProviderType.ollama,
          InferenceProviderType.genericOpenAi,
          InferenceProviderType.nebiusAiStudio,
          InferenceProviderType.omlx,
          InferenceProviderType.whisper,
          InferenceProviderType.voxtral,
          InferenceProviderType.mlxAudio,
        };
        expect(pinned, InferenceProviderType.values.toSet());
      });

      test('covers all provider types', () {
        // Every enum value must return an icon without throwing
        for (final type in InferenceProviderType.values) {
          expect(type.icon, isA<IconData>(), reason: '$type missing icon');
        }
      });
    });

    group('displayName', () {
      testWidgets('returns localized name for alibaba', (
        WidgetTester tester,
      ) async {
        late String name;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                name = InferenceProviderType.alibaba.displayName(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(name, isNotEmpty);
        expect(name, contains('Alibaba'));
      });

      testWidgets('returns localized name for all provider types', (
        WidgetTester tester,
      ) async {
        final names = <InferenceProviderType, String>{};
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                for (final type in InferenceProviderType.values) {
                  names[type] = type.displayName(context);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        for (final entry in names.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason: '${entry.key} should have a non-empty displayName',
          );
        }
      });
    });

    group('requiresDataUriForAudio', () {
      test('returns true only for alibaba', () {
        expect(
          InferenceProviderType.alibaba.requiresDataUriForAudio,
          isTrue,
        );
      });

      test('returns false for all other providers', () {
        for (final type in InferenceProviderType.values) {
          if (type == InferenceProviderType.alibaba) continue;
          expect(
            type.requiresDataUriForAudio,
            isFalse,
            reason: '$type should not require data URI for audio',
          );
        }
      });
    });
  });
}
