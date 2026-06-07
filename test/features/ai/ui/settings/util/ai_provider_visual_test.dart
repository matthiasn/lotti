import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../test_utils.dart';

void main() {
  final messages = AppLocalizationsEn();

  group('aiProviderAccent / aiProviderSurface', () {
    test('every supported provider type resolves to a non-null Color', () {
      for (final type in InferenceProviderType.values) {
        expect(
          aiProviderAccent(type: type, tokens: dsTokensDark),
          isNotNull,
          reason: 'aiProviderAccent must not be null for $type',
        );
        expect(
          aiProviderSurface(type: type, tokens: dsTokensDark),
          isNotNull,
          reason: 'aiProviderSurface must not be null for $type',
        );
      }
    });

    test(
      'Gemini / OpenAI / Anthropic / Ollama / Alibaba accents are distinct',
      () {
        final accents = {
          aiProviderAccent(
            type: InferenceProviderType.gemini,
            tokens: dsTokensDark,
          ),
          aiProviderAccent(
            type: InferenceProviderType.openAi,
            tokens: dsTokensDark,
          ),
          aiProviderAccent(
            type: InferenceProviderType.anthropic,
            tokens: dsTokensDark,
          ),
          aiProviderAccent(
            type: InferenceProviderType.ollama,
            tokens: dsTokensDark,
          ),
          aiProviderAccent(
            type: InferenceProviderType.alibaba,
            tokens: dsTokensDark,
          ),
        };
        expect(
          accents.length,
          equals(5),
          reason:
              'The five first-class providers must each carry a distinct '
              'accent so the cards / tiles / rail are differentiable at a '
              'glance.',
        );
      },
    );

    test(
      'unsupported provider types resolve to the neutral interactive '
      'accent — the fallback is keyed off `interactive.enabled`, not the '
      'Gemini brand token (the v1 regression this guards against).',
      () {
        final neutralAccent = dsTokensDark.colors.interactive.enabled;
        for (final type in const [
          InferenceProviderType.mistral,
          InferenceProviderType.openRouter,
          InferenceProviderType.nebiusAiStudio,
          InferenceProviderType.genericOpenAi,
        ]) {
          expect(
            aiProviderAccent(type: type, tokens: dsTokensDark),
            equals(neutralAccent),
            reason: '$type should fall back to interactive.enabled',
          );
        }
      },
    );

    test(
      'Alibaba now carries its own brand accent, not the neutral fallback',
      () {
        final alibabaAccent = aiProviderAccent(
          type: InferenceProviderType.alibaba,
          tokens: dsTokensDark,
        );
        expect(
          alibabaAccent,
          equals(dsTokensDark.colors.aiProvider.alibaba.color),
          reason:
              'Alibaba was promoted to a first-class FTUE tile and now has '
              'its own brand token rather than the interactive.enabled '
              'fallback.',
        );
        expect(
          alibabaAccent,
          isNot(equals(dsTokensDark.colors.interactive.enabled)),
        );
      },
    );

    test(
      'null type falls back to the neutral interactive accent — for '
      'callers that cannot resolve an owning provider',
      () {
        expect(
          aiProviderAccent(type: null, tokens: dsTokensDark),
          equals(dsTokensDark.colors.interactive.enabled),
        );
      },
    );

    test(
      'light + dark variants are distinct hex values for first-class types',
      () {
        for (final type in const [
          InferenceProviderType.gemini,
          InferenceProviderType.openAi,
          InferenceProviderType.anthropic,
          InferenceProviderType.ollama,
          InferenceProviderType.alibaba,
        ]) {
          final lightAccent = aiProviderAccent(
            type: type,
            tokens: dsTokensLight,
          );
          final darkAccent = aiProviderAccent(type: type, tokens: dsTokensDark);
          expect(
            lightAccent,
            isNot(equals(darkAccent)),
            reason:
                'Light and dark accents for $type should differ — the dark '
                'mode uses lifted hues so cards stay readable on the dark sheet.',
          );
        }
      },
    );
  });

  group('aiProviderDisplayName', () {
    test('returns a non-empty label for every supported provider type', () {
      for (final type in InferenceProviderType.values) {
        final name = aiProviderDisplayName(type: type, messages: messages);
        expect(
          name,
          isNotEmpty,
          reason: 'aiProviderDisplayName for $type must be non-empty',
        );
      }
    });

    test('first-class providers carry their expected display names', () {
      expect(
        aiProviderDisplayName(
          type: InferenceProviderType.gemini,
          messages: messages,
        ),
        equals('Google Gemini'),
      );
      expect(
        aiProviderDisplayName(
          type: InferenceProviderType.openAi,
          messages: messages,
        ),
        equals('OpenAI'),
      );
      expect(
        aiProviderDisplayName(
          type: InferenceProviderType.anthropic,
          messages: messages,
        ),
        equals('Anthropic Claude'),
      );
      expect(
        aiProviderDisplayName(
          type: InferenceProviderType.ollama,
          messages: messages,
        ),
        equals('Ollama'),
      );
      expect(
        aiProviderDisplayName(
          type: InferenceProviderType.mlxAudio,
          messages: messages,
        ),
        equals('MLX Audio (local)'),
      );
    });
  });

  group('aiProviderTagline', () {
    test(
      'only first-class providers carry taglines — others return empty',
      () {
        const expectingTagline = {
          InferenceProviderType.gemini,
          InferenceProviderType.openAi,
          InferenceProviderType.anthropic,
          InferenceProviderType.ollama,
          InferenceProviderType.alibaba,
          InferenceProviderType.mlxAudio,
        };
        for (final type in InferenceProviderType.values) {
          final tagline = aiProviderTagline(type: type, messages: messages);
          if (expectingTagline.contains(type)) {
            expect(
              tagline,
              isNotEmpty,
              reason: '$type should have a tagline',
            );
          } else {
            expect(
              tagline,
              isEmpty,
              reason:
                  '$type should NOT have a tagline — only first-class '
                  'providers carry one.',
            );
          }
        }
      },
    );
  });

  group('aiProviderIcon', () {
    test('returns a non-null icon for every provider type and for null', () {
      for (final type in InferenceProviderType.values) {
        expect(
          aiProviderIcon(type),
          isNotNull,
          reason: 'aiProviderIcon should never return null for $type',
        );
      }
      // Null-type callers (e.g. an AiModelCard whose owning provider
      // hasn't loaded yet) get the generic robot icon.
      expect(aiProviderIcon(null), isNotNull);
    });

    test('first-class providers each carry a distinct icon', () {
      final icons = <IconData>{
        aiProviderIcon(InferenceProviderType.gemini),
        aiProviderIcon(InferenceProviderType.openAi),
        aiProviderIcon(InferenceProviderType.anthropic),
        aiProviderIcon(InferenceProviderType.ollama),
        aiProviderIcon(InferenceProviderType.mistral),
        aiProviderIcon(InferenceProviderType.alibaba),
      };
      expect(
        icons.length,
        equals(6),
        reason: 'Each named provider should have a distinct icon glyph',
      );
    });
  });

  group('aiProviderDisplayName + tagline — null fallbacks', () {
    test(
      'null type resolves to the "AI provider" placeholder label so cards '
      'can render without a resolved owner',
      () {
        expect(
          aiProviderDisplayName(type: null, messages: messages),
          equals('AI provider'),
        );
      },
    );

    test(
      'null type produces an empty tagline (caller can guard on isEmpty)',
      () {
        expect(
          aiProviderTagline(type: null, messages: messages),
          isEmpty,
        );
      },
    );

    test(
      'aiProviderVisual on a null type bundles neutral chrome and the '
      'unknown-provider label',
      () {
        final visual = aiProviderVisual(
          type: null,
          tokens: dsTokensDark,
          messages: messages,
        );
        expect(visual.displayName, equals('AI provider'));
        expect(visual.tagline, isEmpty);
        expect(visual.accent, equals(dsTokensDark.colors.interactive.enabled));
      },
    );
  });

  group('aiProviderKeyConsoleUrl', () {
    test(
      'cloud providers that have a public API-key console resolve to their '
      'documented host (the form renders these as a "Get a key at …" link)',
      () {
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.gemini),
          equals('aistudio.google.com'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.openAi),
          equals('platform.openai.com'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.anthropic),
          equals('console.anthropic.com'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.mistral),
          equals('console.mistral.ai'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.alibaba),
          equals('dashscope.console.aliyun.com'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.openRouter),
          equals('openrouter.ai'),
        );
        expect(
          aiProviderKeyConsoleUrl(InferenceProviderType.nebiusAiStudio),
          equals('studio.nebius.ai'),
        );
      },
    );

    test(
      'local-only providers (Ollama / Whisper / Voxtral), generic OpenAI '
      '(arbitrary user-supplied endpoint), and a null type resolve to null '
      '— there is no public console URL to link to.',
      () {
        for (final type in const [
          InferenceProviderType.ollama,
          InferenceProviderType.mlxAudio,
          InferenceProviderType.whisper,
          InferenceProviderType.voxtral,
          InferenceProviderType.genericOpenAi,
        ]) {
          expect(
            aiProviderKeyConsoleUrl(type),
            isNull,
            reason:
                '$type has no hosted key console, so the form should not '
                'render a "Get a key at …" link for it.',
          );
        }
        expect(aiProviderKeyConsoleUrl(null), isNull);
      },
    );
  });

  group('aiProviderVisual', () {
    test(
      'bundles accent + surface + displayName + tagline into one record',
      () {
        final visual = aiProviderVisual(
          type: InferenceProviderType.gemini,
          tokens: dsTokensDark,
          messages: messages,
        );
        expect(visual.displayName, equals('Google Gemini'));
        expect(visual.tagline, isNotEmpty);
        expect(
          visual.accent,
          equals(
            aiProviderAccent(
              type: InferenceProviderType.gemini,
              tokens: dsTokensDark,
            ),
          ),
        );
        expect(
          visual.surface,
          equals(
            aiProviderSurface(
              type: InferenceProviderType.gemini,
              tokens: dsTokensDark,
            ),
          ),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Glados properties for the pure helpers.
  // ---------------------------------------------------------------------------
  group('ai_provider_visual — properties', () {
    glados.Glados2(
      glados.AnyUtils(glados.any).choose(InferenceProviderType.values),
      glados.AnyUtils(glados.any).choose(const ['', '   ', '\t', 'sk-key']),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isProviderDraft is false for keyless types and otherwise mirrors '
      'the trimmed-key emptiness',
      (type, apiKey) {
        final provider = AiTestDataFactory.createTestProvider(
          type: type,
          apiKey: apiKey,
        );
        final expected =
            !ProviderConfig.noApiKeyRequired.contains(type) &&
            apiKey.trim().isEmpty;
        expect(
          isProviderDraft(provider),
          expected,
          reason: '$type / "$apiKey"',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(0, 16),
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'modelCapabilityLabels is deterministic and ordered '
      'thinking → vision → transcription → image generation',
      (mask) {
        List<String> labelsFor() => modelCapabilityLabels(
          messages: messages,
          isReasoning: mask & 1 != 0,
          inputModalities: [
            Modality.text,
            if (mask & 2 != 0) Modality.image,
            if (mask & 4 != 0) Modality.audio,
          ],
          outputModalities: [
            Modality.text,
            if (mask & 8 != 0) Modality.image,
          ],
        );

        final labels = labelsFor();
        // Idempotence: same inputs always produce the same ordered list.
        expect(labelsFor(), labels, reason: 'mask=$mask');

        final expected = <String>[
          if (mask & 1 != 0) messages.aiCapabilityChipThinking,
          if (mask & 2 != 0) messages.aiCapabilityChipImageRecognition,
          if (mask & 4 != 0) messages.aiCapabilityChipTranscription,
          if (mask & 8 != 0) messages.aiCapabilityChipImageGeneration,
        ];
        expect(labels, expected, reason: 'mask=$mask');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.AnyUtils(glados.any).choose(InferenceProviderType.values),
      glados.ExploreConfig(numRuns: 60),
    ).test('aiProviderKeyConsoleUrl never returns an empty string', (type) {
      final url = aiProviderKeyConsoleUrl(type);
      expect(url, anyOf(isNull, isNotEmpty), reason: '$type');
    }, tags: 'glados');
  });
}
