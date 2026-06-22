import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Reduced motion so the aurora/constellation backdrop controllers stop and
  // the panel settles deterministically under a bare `pump()`.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  Future<void> pumpPanel(
    WidgetTester tester, {
    void Function(InferenceProviderType)? onSelect,
    VoidCallback? onBack,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            type: MaterialType.transparency,
            child: OnboardingConnectPanel(
              onSelect: onSelect ?? (_) {},
              onBack: onBack ?? () {},
            ),
          ),
        ),
        mediaQueryData: mq,
      ),
    );
    await tester.pump();
  }

  /// The English localizations, for asserting against the curated copy.
  late AppLocalizations m;

  setUp(() async {
    m = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('OnboardingConnectPanel widget', () {
    testWidgets('renders the title and the primary provider tiles', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text(m.onboardingConnectTitle), findsOneWidget);

      // Each primary provider's curated name is shown.
      for (final type in onboardingPrimaryProviders) {
        expect(
          find.text(onboardingProviderName(m, type)),
          findsOneWidget,
          reason: 'expected primary tile for $type',
        );
      }
      // Concretely: Gemini, Mistral and Qwen.
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Mistral'), findsOneWidget);
      expect(find.text('Qwen'), findsOneWidget);

      // Primary taglines render under the names.
      expect(find.text(m.onboardingConnectGeminiTagline), findsOneWidget);
      expect(find.text(m.onboardingConnectMistralTagline), findsOneWidget);
      expect(find.text(m.onboardingConnectQwenTagline), findsOneWidget);

      // The "more options" disclosure starts collapsed: extra providers hidden.
      expect(find.text(m.onboardingConnectMoreOptions), findsOneWidget);
      expect(find.text(m.onboardingConnectLessOptions), findsNothing);
      expect(
        find.text(onboardingProviderName(m, InferenceProviderType.openAi)),
        findsNothing,
      );
    });

    testWidgets('tapping the back arrow invokes onBack', (tester) async {
      var backed = false;
      await pumpPanel(tester, onBack: () => backed = true);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();

      expect(backed, isTrue);
    });

    testWidgets('More options reveals the extra providers and toggles back', (
      tester,
    ) async {
      await pumpPanel(tester);

      // Hidden initially.
      for (final type in onboardingMoreProviders) {
        expect(find.text(onboardingProviderName(m, type)), findsNothing);
      }

      // Expand.
      await tester.tap(find.text(m.onboardingConnectMoreOptions));
      await tester.pump(); // start the AnimatedSize/Switcher
      await tester.pump(const Duration(milliseconds: 400)); // reveal settles

      // Label flips and the extra providers (OpenAI, Ollama) appear.
      expect(find.text(m.onboardingConnectLessOptions), findsOneWidget);
      expect(find.text(m.onboardingConnectMoreOptions), findsNothing);
      for (final type in onboardingMoreProviders) {
        expect(
          find.text(onboardingProviderName(m, type)),
          findsOneWidget,
          reason: 'expected revealed tile for $type',
        );
      }
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Ollama'), findsOneWidget);

      // Collapse again.
      await tester.tap(find.text(m.onboardingConnectLessOptions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(m.onboardingConnectMoreOptions), findsOneWidget);
      for (final type in onboardingMoreProviders) {
        expect(find.text(onboardingProviderName(m, type)), findsNothing);
      }
    });

    testWidgets('tapping a primary tile fires onSelect with its type', (
      tester,
    ) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      // Tap the Mistral tile via its localized name.
      await tester.tap(
        find.text(onboardingProviderName(m, InferenceProviderType.mistral)),
      );
      await tester.pump();

      expect(selected, [InferenceProviderType.mistral]);
    });

    testWidgets('tapping a revealed extra tile fires onSelect with its type', (
      tester,
    ) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      await tester.tap(find.text(m.onboardingConnectMoreOptions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(
        find.text(onboardingProviderName(m, InferenceProviderType.ollama)),
      );
      await tester.pump();

      expect(selected, [InferenceProviderType.ollama]);
    });
  });

  group('onboardingProviderBrandColor', () {
    test('returns a distinct brand color for every surfaced provider', () {
      final byType = <InferenceProviderType, Color>{
        for (final type in [
          ...onboardingPrimaryProviders,
          ...onboardingMoreProviders,
        ])
          type: onboardingProviderBrandColor(type),
      };

      // Every surfaced provider resolves to its own dedicated brand color
      // (none fall through to the teal fallback).
      const fallback = Color(0xFF5ED4B7);
      for (final entry in byType.entries) {
        expect(
          entry.value,
          isNot(fallback),
          reason: '${entry.key} should have a dedicated brand color',
        );
      }
      // Colors are distinct from one another.
      expect(byType.values.toSet().length, byType.length);

      // Spot-check the explicit brand hues for the listed arms.
      expect(
        onboardingProviderBrandColor(InferenceProviderType.gemini),
        const Color(0xFF4285F4),
      );
      expect(
        onboardingProviderBrandColor(InferenceProviderType.mistral),
        const Color(0xFFFF7000),
      );
      expect(
        onboardingProviderBrandColor(InferenceProviderType.alibaba),
        const Color(0xFF615CED),
      );
      expect(
        onboardingProviderBrandColor(InferenceProviderType.openAi),
        const Color(0xFF10A37F),
      );
      expect(
        onboardingProviderBrandColor(InferenceProviderType.ollama),
        const Color(0xFFC7C7CC),
      );
    });

    test('falls back to the brand teal for unlisted providers', () {
      const fallback = Color(0xFF5ED4B7);
      // Types not in the switch's explicit arms hit the `_` fallback.
      expect(
        onboardingProviderBrandColor(InferenceProviderType.anthropic),
        fallback,
      );
      expect(
        onboardingProviderBrandColor(InferenceProviderType.whisper),
        fallback,
      );
    });
  });

  group('onboardingProviderName / onboardingProviderTagline', () {
    test('curated names map to the welcome-specific copy', () {
      final cases = <InferenceProviderType, String>{
        InferenceProviderType.gemini: m.onboardingConnectGeminiName,
        InferenceProviderType.mistral: m.onboardingConnectMistralName,
        InferenceProviderType.alibaba: m.onboardingConnectQwenName,
        InferenceProviderType.openAi: m.onboardingConnectOpenAiName,
        InferenceProviderType.ollama: m.onboardingConnectOllamaName,
      };
      for (final entry in cases.entries) {
        expect(
          onboardingProviderName(m, entry.key),
          allOf(entry.value, isNotEmpty),
        );
      }
    });

    test(
      'an unlisted provider name falls back to the generic display name',
      () {
        // The `_` arm delegates to aiProviderDisplayName.
        final name = onboardingProviderName(m, InferenceProviderType.anthropic);
        expect(name, m.aiProviderAnthropicName);
        expect(name, isNotEmpty);
      },
    );

    test('primary providers expose a non-empty tagline', () {
      final cases = <InferenceProviderType, String>{
        InferenceProviderType.gemini: m.onboardingConnectGeminiTagline,
        InferenceProviderType.mistral: m.onboardingConnectMistralTagline,
        InferenceProviderType.alibaba: m.onboardingConnectQwenTagline,
      };
      for (final entry in cases.entries) {
        expect(
          onboardingProviderTagline(m, entry.key),
          allOf(entry.value, isNotEmpty),
        );
      }
    });

    test('providers without a curated tagline return empty', () {
      // The `_` arm returns ''.
      expect(
        onboardingProviderTagline(m, InferenceProviderType.openAi),
        isEmpty,
      );
      expect(
        onboardingProviderTagline(m, InferenceProviderType.ollama),
        isEmpty,
      );
    });
  });
}
