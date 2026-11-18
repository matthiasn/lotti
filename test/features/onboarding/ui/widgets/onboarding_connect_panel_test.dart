import 'dart:ui' show SemanticsAction, Tristate;

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
  // Reduced motion so the panel settles deterministically under a bare
  // `pump()`.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  Future<void> pumpPanel(
    WidgetTester tester, {
    void Function(InferenceProviderType)? onSelect,
    VoidCallback? onBack,
    VoidCallback? onClose,
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
              onClose: onClose,
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
    testWidgets('leads with one card under the "Recommended" caption: the '
        'recommended provider, with what its one key covers', (tester) async {
      await pumpPanel(tester);

      expect(find.text(m.onboardingConnectOneKeyTitle), findsOneWidget);
      expect(onboardingRecommendedProvider, InferenceProviderType.mistral);
      expect(find.text('Mistral'), findsOneWidget);
      // The pitch takes the tagline's place on the recommended card.
      expect(find.text(m.onboardingConnectMistralPitch), findsOneWidget);
      expect(find.text(m.onboardingConnectMistralTagline), findsNothing);
      // The caption names the card from above it; the card carries no badge
      // of its own.
      expect(find.text(m.onboardingConnectRecommended), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text(m.onboardingConnectRecommended)).dy,
        lessThan(tester.getTopLeft(find.text('Mistral')).dy),
      );
    });

    testWidgets('the main button goes on with the recommended provider, and '
        'a line under the card says what a key is', (tester) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      expect(find.text(m.onboardingConnectKeyNote), findsOneWidget);
      final button = find.text(m.onboardingConnectContinueWith('Mistral'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(selected, [InferenceProviderType.mistral]);
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

    testWidgets('with the companion she stands on the stage and recommends '
        'it in the bubble under her', (tester) async {
      await pumpPanel(
        tester,
        companion: const ColoredBox(
          key: ValueKey('companion'),
          color: Color(0xFF000000),
        ),
      );

      final companion = find.byKey(const ValueKey('companion'));
      final bubble = tester.widget<OnboardingSpeechBubble>(
        find.byType(OnboardingSpeechBubble),
      );
      expect(bubble.title, m.onboardingConnectOneKeyTitle);
      expect(bubble.text, m.onboardingConnectGuide);
      expect(find.text(m.onboardingConnectNotSure), findsNothing);
      // She stands over her bubble, and both sit above the card.
      expect(
        tester.getBottomLeft(companion).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(OnboardingSpeechBubble)).dy,
        ),
      );
      expect(
        tester.getBottomLeft(find.byType(OnboardingSpeechBubble)).dy,
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

    testWidgets('the recommended provider starts out chosen; a tile '
        'chooses its provider and only the main button goes on, with the one '
        'chosen', (tester) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);

      expect(find.text(m.onboardingConnectContinueWith('Mistral')), findsOne);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);

      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(
        find.text(onboardingProviderName(m, InferenceProviderType.ollama)),
      );
      await tester.pump();

      // Choosing is not going on.
      expect(selected, isEmpty);
      expect(find.text(m.onboardingConnectContinueWith('Ollama')), findsOne);
      // One chosen at a time, marked by more than colour.
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.bySemanticsLabel(
                onboardingProviderName(m, InferenceProviderType.ollama),
              ),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      final button = find.text(m.onboardingConnectContinueWith('Ollama'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(selected, [InferenceProviderType.ollama]);
    });

    testWidgets('a provider tile can be chosen from the keyboard', (
      tester,
    ) async {
      final selected = <InferenceProviderType>[];
      await pumpPanel(tester, onSelect: selected.add);
      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final gemini = find.text(
        onboardingProviderName(m, InferenceProviderType.gemini),
      );
      final focus = Focus.of(tester.element(gemini))..requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, isEmpty);
      expect(find.text(m.onboardingConnectContinueWith('Gemini')), findsOne);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(
          '${onboardingProviderName(m, InferenceProviderType.mistral)}, '
          '${m.onboardingConnectRecommended}',
        ),
      );
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('opening the other providers leaves her where she is: only '
        'the tray scrolls', (tester) async {
      await pumpPanel(
        tester,
        companion: const ColoredBox(
          key: ValueKey('companion'),
          color: Color(0xFF000000),
        ),
      );
      final before = tester.getSize(find.byKey(const ValueKey('companion')));

      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        tester.getSize(find.byKey(const ValueKey('companion'))),
        before,
      );
    });

    testWidgets('the cards wear no brand colour: the icon sits in a quiet '
        'well, so nothing but the chosen card reads as chosen', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text(m.onboardingConnectOtherProviders));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final tokens = tester
          .element(find.byType(OnboardingConnectPanel))
          .designTokens;

      for (final icon in tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(OnboardingProviderCard),
          matching: find.byType(Icon),
        ),
      )) {
        if (icon.icon == LottiIcons.confirm) continue;
        expect(icon.color, tokens.colors.text.mediumEmphasis);
      }
    });

    testWidgets('the close button leaves where the host offers it', (
      tester,
    ) async {
      var closed = 0;
      await pumpPanel(tester, onClose: () => closed++);
      await tester.tap(find.byIcon(LottiIcons.close));
      expect(closed, 1);

      await pumpPanel(tester);
      expect(find.byIcon(LottiIcons.close), findsNothing);
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
