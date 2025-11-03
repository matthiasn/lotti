import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';

void main() {
  group('ProviderChipConstants', () {
    group('getProviderColor - Dark Theme', () {
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

      test('returns correct dark color for Ollama provider', () {
        const type = InferenceProviderType.ollama;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFFF9F68))); // Orange dark
      });

      test('returns correct dark color for OpenRouter provider', () {
        const type = InferenceProviderType.openRouter;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFF4ECDC4))); // Teal dark
      });

      test('returns correct dark color for GenericOpenAI provider', () {
        const type = InferenceProviderType.genericOpenAi;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFA78BFA))); // Purple dark
      });

      test('returns correct dark color for NebiusAiStudio provider', () {
        const type = InferenceProviderType.nebiusAiStudio;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFF06292))); // Pink dark
      });

      test('returns correct dark color for Whisper provider', () {
        const type = InferenceProviderType.whisper;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFFFF8A65))); // Deep Orange dark
      });

      test('returns correct dark color for Gemma3n provider', () {
        const type = InferenceProviderType.gemma3n;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: true,
        );

        expect(color, equals(const Color(0xFF81C784))); // Light Green dark
      });
    });

    group('getProviderColor - Light Theme', () {
      test('returns correct light color for Anthropic provider', () {
        const type = InferenceProviderType.anthropic;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFFB8864E))); // Warm bronze
      });

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

      test('returns correct light color for Ollama provider', () {
        const type = InferenceProviderType.ollama;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFFFF7043))); // Orange
      });

      test('returns correct light color for OpenRouter provider', () {
        const type = InferenceProviderType.openRouter;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFF00BCD4))); // Teal
      });

      test('returns correct light color for GenericOpenAI provider', () {
        const type = InferenceProviderType.genericOpenAi;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFF9C27B0))); // Purple
      });

      test('returns correct light color for NebiusAiStudio provider', () {
        const type = InferenceProviderType.nebiusAiStudio;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFFE91E63))); // Pink
      });

      test('returns correct light color for Whisper provider', () {
        const type = InferenceProviderType.whisper;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFFFF5722))); // Deep Orange
      });

      test('returns correct light color for Gemma3n provider', () {
        const type = InferenceProviderType.gemma3n;

        final color = ProviderChipConstants.getProviderColor(
          type,
          isDark: false,
        );

        expect(color, equals(const Color(0xFF66BB6A))); // Light Green
      });
    });

    group('providerColors map', () {
      test('contains entry for all provider types', () {
        const allTypes = InferenceProviderType.values;
        final mapKeys = ProviderChipConstants.providerColors.keys.toSet();

        for (final type in allTypes) {
          expect(
            mapKeys.contains(type),
            isTrue,
            reason: 'Missing color definition for $type',
          );
        }
      });

      test('has correct number of entries', () {
        final expectedCount = InferenceProviderType.values.length;
        final actualCount = ProviderChipConstants.providerColors.length;

        expect(actualCount, equals(expectedCount));
      });

      test('all entries have both dark and light colors', () {
        for (final entry in ProviderChipConstants.providerColors.entries) {
          expect(
            entry.value.dark,
            isA<Color>(),
            reason: '${entry.key} missing dark color',
          );
          expect(
            entry.value.light,
            isA<Color>(),
            reason: '${entry.key} missing light color',
          );
        }
      });

      test('dark and light colors are different for each provider', () {
        for (final entry in ProviderChipConstants.providerColors.entries) {
          expect(
            entry.value.dark,
            isNot(equals(entry.value.light)),
            reason: '${entry.key} has same dark and light colors',
          );
        }
      });
    });

    group('Constant values', () {
      test('modal sizing constants have expected values', () {
        expect(ProviderChipConstants.modalHeightFactor, equals(0.65));
      });

      test('chip styling constants have expected values', () {
        expect(ProviderChipConstants.chipFontSize, equals(13));
        expect(ProviderChipConstants.chipBorderRadius, equals(20));
        expect(ProviderChipConstants.chipHorizontalPadding, equals(12));
        expect(ProviderChipConstants.chipVerticalPadding, equals(6));
        expect(ProviderChipConstants.chipBorderWidth, equals(1.5));
        expect(ProviderChipConstants.chipLetterSpacing, equals(0.2));
        expect(
          ProviderChipConstants.chipFontWeight,
          equals(FontWeight.w600),
        );
      });

      test('spacing constants have expected values', () {
        expect(ProviderChipConstants.chipSpacing, equals(6));
      });

      test('alpha constants are within valid range 0.0-1.0', () {
        expect(ProviderChipConstants.surfaceAlpha, inInclusiveRange(0.0, 1.0));
        expect(
          ProviderChipConstants.primaryContainerAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(ProviderChipConstants.primaryAlpha, inInclusiveRange(0.0, 1.0));
        expect(
          ProviderChipConstants.primaryContainerBorderAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.onSurfaceVariantAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.selectedAlphaDark,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.selectedAlphaLight,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.unselectedAlphaDark,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.unselectedAlphaLight,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.selectedBorderAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.unselectedBorderAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.avatarGradientAlpha,
          inInclusiveRange(0.0, 1.0),
        );
        expect(
          ProviderChipConstants.avatarShadowAlpha,
          inInclusiveRange(0.0, 1.0),
        );
      });

      test('avatar constants have expected values', () {
        expect(ProviderChipConstants.avatarSize, equals(8));
        expect(ProviderChipConstants.avatarShadowBlurRadius, equals(4));
        expect(
          ProviderChipConstants.avatarShadowOffset,
          equals(const Offset(0, 2)),
        );
      });

      test('alpha values have reasonable relationships', () {
        // Selected state should be more opaque than unselected
        expect(
          ProviderChipConstants.selectedAlphaDark,
          greaterThan(ProviderChipConstants.unselectedAlphaDark),
        );
        expect(
          ProviderChipConstants.selectedAlphaLight,
          greaterThan(ProviderChipConstants.unselectedAlphaLight),
        );

        // Selected border should be more opaque than unselected
        expect(
          ProviderChipConstants.selectedBorderAlpha,
          greaterThan(ProviderChipConstants.unselectedBorderAlpha),
        );
      });
    });
  });
}
