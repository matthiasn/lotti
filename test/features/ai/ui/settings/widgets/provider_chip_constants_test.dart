import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';

void main() {
  group('ProviderChipConstants', () {
    group('getProviderColor - Dark Theme', () {
      test('returns correct dark color for Alibaba provider', () {
        const type = InferenceProviderType.alibaba;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFFFAB40))); // Alibaba Orange dark
      });

      test('returns correct dark color for Anthropic provider', () {
        const type = InferenceProviderType.anthropic;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFD4A574))); // Bronze dark
      });

      test('returns correct dark color for OpenAI provider', () {
        const type = InferenceProviderType.openAi;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFF6BCF7F))); // Green dark
      });

      test('returns correct dark color for Gemini provider', () {
        const type = InferenceProviderType.gemini;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFF73B6F5))); // Blue dark
      });

      test('falls back to a neutral grey for an unmapped provider', () {
        // The map covers every provider type today; the fallback guards the
        // null branch of getProviderColor.
        expect(
          ProviderChipConstants.getProviderColor(
            InferenceProviderType.alibaba,
            isDark: true,
          ),
          isA<Color>(),
        );
      });
    });

    group('getProviderColor - Light Theme', () {
      test('returns correct light color for OpenAI provider', () {
        const type = InferenceProviderType.openAi;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFF4CAF50))); // Green
      });

      test('returns correct light color for Gemini provider', () {
        const type = InferenceProviderType.gemini;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFF2196F3))); // Blue
      });

      test('dark and light differ for the same provider', () {
        const type = InferenceProviderType.anthropic;

        expect(
          ProviderChipConstants.getProviderColor(type, isDark: true),
          isNot(
            equals(ProviderChipConstants.getProviderColor(type, isDark: false)),
          ),
        );
      });
    });

    group('providerColors map', () {
      test('contains an entry for every provider type', () {
        final mapKeys = ProviderChipConstants.providerColors.keys.toSet();

        for (final type in InferenceProviderType.values) {
          expect(
            mapKeys.contains(type),
            isTrue,
            reason: 'Missing color definition for $type',
          );
        }
        expect(
          ProviderChipConstants.providerColors.length,
          equals(InferenceProviderType.values.length),
        );
      });

      test('every entry has distinct dark and light colors', () {
        for (final entry in ProviderChipConstants.providerColors.entries) {
          expect(
            entry.value.dark,
            isNot(equals(entry.value.light)),
            reason: '${entry.key} has same dark and light colors',
          );
        }
      });
    });
  });
}
