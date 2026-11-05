import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

void main() {
  // Reduced motion so the aurora/constellation backdrop controllers stop and
  // the panel settles deterministically under a bare `pump()`.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  Future<void> pumpPanel(
    WidgetTester tester, {
    void Function(InferenceProviderType)? onSelect,
    VoidCallback? onBack,
    Widget? companion,
  }) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidget(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            type: MaterialType.transparency,
            child: OnboardingConnectPanel(
              onSelect: onSelect ?? (_) {},
              onBack: onBack ?? () {},
              companion: companion,
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
    testWidgets('leads with one card: the recommended provider, badged, '
        'with what its one key covers', (tester) async {
      await pumpPanel(tester);

      expect(find.text(m.onboardingConnectOneKeyTitle), findsOneWidget);
      expect(onboardingRecommendedProvider, InferenceProviderType.mistral);
      expect(find.text('Mistral'), findsOneWidget);
      expect(find.text(m.onboardingConnectRecommended), findsOneWidget);
      // The pitch takes the tagline's place on the recommended card.
      expect(find.text(m.onboardingConnectMistralPitch), findsOneWidget);
      expect(find.text(m.onboardingConnectMistralTagline), findsNothing);
      // The badge sits on the Mistral card, beside its name.
      expect(
        (tester.getCenter(find.text(m.onboardingConnectRecommended)).dy -
                tester.getCenter(find.text('Mistral')).dy)
            .abs(),
        lessThan(24),
      );
    });

    testWidgets('every other provider waits behind the closed disclosure', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text(m.onboardingConnectOtherProviders), findsOneWidget);
      expect(find.text(m.onboardingConnectHideOtherProviders), findsNothing);
      for (final type in onboardingOtherProviders) {
        expect(
          find.text(onboardingProviderName(m, type)),
          findsNothing,
          reason: '$type should wait behind the disclosure',
        );
      }
      expect(
        onboardingOtherProviders,
        isNot(contains(onboardingRecommendedProvider)),
      );
    });

    testWidgets('without the companion the recommendation is a plain '
        'subtitle', (tester) async {
      await pumpPanel(tester);

      expect(find.text(m.onboardingConnectNotSure), findsOneWidget);
      expect(find.text(m.onboardingConnectGuide), findsNothing);
      expect(find.byType(OnboardingSpeechBubble), findsNothing);
    });

    testWidgets('with the companion she recommends it in her bubble, '
        'pointing at her', (tester) async {
      await pumpPanel(
        tester,
        companion: const ColoredBox(
          key: ValueKey('companion'),
          color: Color(0xFF000000),
        ),
      );

      final companion = find.byKey(const ValueKey('companion'));
      expect(tester.getSize(companion), const Size.square(80));
      final bubble = tester.widget<OnboardingSpeechBubble>(
        find.byType(OnboardingSpeechBubble),
      );
      expect(bubble.text, m.onboardingConnectGuide);
      expect(bubble.tail, OnboardingBubbleTail.left);
      expect(find.text(m.onboardingConnectNotSure), findsNothing);
      // She stands left of her bubble, and both sit above the card.
      expect(
        tester.getCenter(companion).dx,
        lessThan(tester.getCenter(find.text(m.onboardingConnectGuide)).dx),
      );
      expect(
        tester.getBottomLeft(companion).dy,
        lessThan(tester.getTopLeft(find.text('Mistral')).dy),
      );
    });

    testWidgets('the recommended card announces itself as recommended', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(
        find.bySemanticsLabel('Mistral, ${m.onboardingConnectRecommended}'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the back arrow invokes onBack', (tester) async {
      var backed = false;
      await pumpPanel(tester, onBack: () => backed = true);

      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pump();

      expect(backed, isTrue);
    });

    testWidgets('back control is localized and keyboard operable', (
      tester,
    ) async {
      var backed = false;
      await pumpPanel(tester, onBack: () => backed = true);

      final back = findMaterialTooltip('Back');
      expect(back, findsOneWidget);
      final semantics = tester.getSemantics(find.bySemanticsLabel('Back'));
      expect(semantics.label, 'Back');
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      Focus.of(
        tester.element(find.byIcon(LottiIcons.back)),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(backed, isTrue);
    });

    testWidgets('Other providers reveals the rest and hides them again', (
      tester,
    ) async {
      await pumpPanel(tester);

      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump(); // start the AnimatedSize/Switcher
      await tester.pump(const Duration(milliseconds: 600)); // reveal settles

      expect(find.text(m.onboardingConnectHideOtherProviders), findsOneWidget);
      expect(find.text(m.onboardingConnectOtherProviders), findsNothing);
      for (final type in onboardingOtherProviders) {
        expect(
          find.text(onboardingProviderName(m, type)),
          findsOneWidget,
          reason: 'expected revealed tile for $type',
        );
      }
      // The others keep their own taglines; only the recommended card pitches.
      expect(find.text(m.onboardingConnectGeminiTagline), findsOneWidget);
      expect(find.text(m.onboardingConnectRecommended), findsOneWidget);

      await tester.tap(find.text(m.onboardingConnectHideOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(m.onboardingConnectOtherProviders), findsOneWidget);
      for (final type in onboardingOtherProviders) {
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

    testWidgets('a primary provider activates via keyboard', (tester) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      final providerName = find.text(
        onboardingProviderName(m, InferenceProviderType.mistral),
      );
      final focus = Focus.of(tester.element(providerName))..requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, [InferenceProviderType.mistral]);
      final provider = find.bySemanticsLabel(
        '${onboardingProviderName(m, InferenceProviderType.mistral)}, '
        '${m.onboardingConnectRecommended}',
      );
      expect(provider, findsOneWidget);
      final semantics = tester.getSemantics(provider);
      expect(semantics.label, contains('Mistral'));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('tapping a revealed extra tile fires onSelect with its type', (
      tester,
    ) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

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
          onboardingRecommendedProvider,
          ...onboardingOtherProviders,
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
        onboardingProviderBrandColor(InferenceProviderType.melious),
        const Color(0xFF14B8A6),
      );
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
        InferenceProviderType.melious: m.aiProviderMeliousName,
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
        InferenceProviderType.melious: m.aiProviderTaglineMelious,
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
