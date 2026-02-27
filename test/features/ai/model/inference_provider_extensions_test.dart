import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('InferenceProviderTypeExtension', () {
    group('icon', () {
      test('returns distinct icon for each provider type', () {
        final icons = <InferenceProviderType, IconData>{
          InferenceProviderType.alibaba: Icons.cloud_queue,
          InferenceProviderType.anthropic: Icons.auto_awesome,
          InferenceProviderType.openAi: Icons.psychology,
          InferenceProviderType.gemini: Icons.diamond,
          InferenceProviderType.mistral: Icons.record_voice_over,
          InferenceProviderType.openRouter: Icons.hub,
          InferenceProviderType.ollama: Icons.computer,
          InferenceProviderType.genericOpenAi: Icons.cloud,
          InferenceProviderType.nebiusAiStudio: Icons.rocket_launch,
          InferenceProviderType.whisper: Icons.mic,
          InferenceProviderType.voxtral: Icons.graphic_eq,
        };

        for (final entry in icons.entries) {
          expect(
            entry.key.icon,
            equals(entry.value),
            reason: '${entry.key} should have icon ${entry.value}',
          );
        }
      });

      test('covers all provider types', () {
        // Every enum value must return an icon without throwing
        for (final type in InferenceProviderType.values) {
          expect(type.icon, isA<IconData>(), reason: '$type missing icon');
        }
      });
    });

    group('displayName', () {
      testWidgets('returns localized name for alibaba',
          (WidgetTester tester) async {
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

      testWidgets('returns localized name for all provider types',
          (WidgetTester tester) async {
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

    group('description', () {
      testWidgets('returns localized description for alibaba',
          (WidgetTester tester) async {
        late String desc;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                desc = InferenceProviderType.alibaba.description(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(desc, isNotEmpty);
        expect(desc, contains('Qwen'));
      });

      testWidgets('returns localized description for all provider types',
          (WidgetTester tester) async {
        final descriptions = <InferenceProviderType, String>{};
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                for (final type in InferenceProviderType.values) {
                  descriptions[type] = type.description(context);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        for (final entry in descriptions.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason: '${entry.key} should have a non-empty description',
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
