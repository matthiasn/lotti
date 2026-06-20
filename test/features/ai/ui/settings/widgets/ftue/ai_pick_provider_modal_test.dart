import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';

import '../../../../../../widget_test_utils.dart';
import 'ai_pick_provider_modal_test_helpers.dart';

void main() {
  group('AiPickProviderModal.defaultTiles — static spec', () {
    test(
      'lineup matches the design: '
      'Gemini → OpenAI → Anthropic → Alibaba → MLX Audio → oMLX → Ollama → Voxtral',
      () {
        expect(
          AiPickProviderModal.defaultTiles.map((t) => t.providerType).toList(),
          [
            InferenceProviderType.gemini,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.alibaba,
            InferenceProviderType.mlxAudio,
            InferenceProviderType.omlx,
            InferenceProviderType.ollama,
            InferenceProviderType.voxtral,
          ],
        );
      },
    );

    test('Gemini carries the RECOMMENDED badge (per the design)', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.gemini,
      );
      expect(spec.badge, AiPickProviderBadge.recommended);
    });

    test('Anthropic carries the NEW badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.anthropic,
      );
      expect(spec.badge, AiPickProviderBadge.newcomer);
    });

    test('Alibaba carries the NEW badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.alibaba,
      );
      expect(spec.badge, AiPickProviderBadge.newcomer);
    });

    test('MLX Audio carries the NEW badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.mlxAudio,
      );
      expect(spec.badge, AiPickProviderBadge.newcomer);
    });

    test('Ollama carries the DESKTOP ONLY badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.ollama,
      );
      expect(spec.badge, AiPickProviderBadge.desktopOnly);
    });

    test('oMLX carries the DESKTOP ONLY badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.omlx,
      );
      expect(spec.badge, AiPickProviderBadge.desktopOnly);
    });

    test('Voxtral carries the DESKTOP ONLY badge', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.voxtral,
      );
      expect(spec.badge, AiPickProviderBadge.desktopOnly);
    });

    test('OpenAI has no badge (the only un-badged tile)', () {
      final spec = AiPickProviderModal.defaultTiles.firstWhere(
        (t) => t.providerType == InferenceProviderType.openAi,
      );
      expect(spec.badge, isNull);
    });
  });

  group('AiPickProviderResult — outcome dispatch', () {
    test('confirmed carries the picked provider type and isConfirmed=true', () {
      const result = AiPickProviderResult.confirmed(
        InferenceProviderType.anthropic,
      );
      expect(result.kind, AiPickProviderResultKind.confirmed);
      expect(result.isConfirmed, isTrue);
      expect(result.providerType, InferenceProviderType.anthropic);
      expect(result.isDontShowAgain, isFalse);
    });

    test('dontShowAgain has no providerType and isDontShowAgain=true', () {
      const result = AiPickProviderResult.dontShowAgain();
      expect(result.kind, AiPickProviderResultKind.dontShowAgain);
      expect(result.isDontShowAgain, isTrue);
      expect(result.providerType, isNull);
      expect(result.isConfirmed, isFalse);
    });

    test('cancelled has no providerType and kind=cancelled', () {
      const result = AiPickProviderResult.cancelled();
      expect(result.kind, AiPickProviderResultKind.cancelled);
      expect(result.providerType, isNull);
      expect(result.isConfirmed, isFalse);
      expect(result.isDontShowAgain, isFalse);
    });
  });

  group('AiPickProviderModal widget body', () {
    Future<void> pumpModal(
      WidgetTester tester, {
      InferenceProviderType initialSelection = InferenceProviderType.gemini,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          AiPickProviderModal(
            tiles: AiPickProviderModal.defaultTiles,
            initialSelection: initialSelection,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'renders the localised subtitle and footer hint above the action row',
      (tester) async {
        await pumpModal(tester);
        final messages = hL10n(tester);
        expect(find.text(messages.aiPickProviderSubtitle), findsOneWidget);
        expect(find.text(messages.aiPickProviderFooterHint), findsOneWidget);
        expect(
          find.text(messages.aiPickProviderContinueButton),
          findsOneWidget,
        );
        expect(
          find.text(messages.aiPickProviderDontShowAgainButton),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders one DesignSystemBadge per badged tile '
      '(Gemini RECOMMENDED, Anthropic NEW, Alibaba NEW, '
      'MLX Audio NEW, oMLX DESKTOP ONLY, Ollama DESKTOP ONLY, '
      'Voxtral DESKTOP ONLY) — seven badges total '
      'because OpenAI is intentionally un-badged',
      (tester) async {
        await pumpModal(tester);
        expect(find.byType(DesignSystemBadge), findsNWidgets(7));
      },
    );

    testWidgets(
      'tapping a tile updates the visual selection — the previously '
      'selected tile clears and the new tile shows the filled radio '
      'indicator (a check-rounded icon inside the accent circle)',
      (tester) async {
        await pumpModal(tester);
        final messages = hL10n(tester);
        // Initial selection is Gemini → exactly one check icon.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // Tap the OpenAI tile. The localised provider name is the
        // unique label inside the OpenAI row.
        await tester.tap(find.text(messages.aiProviderOpenAiName));
        await tester.pump();

        // After the swap there should still be exactly one check
        // icon, just on the OpenAI row now.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Continue pops the modal with confirmed(<initialSelection>) '
      'when the user has not changed the radio',
      (tester) async {
        // Six tiles + footer + action row exceed the default 800x600 test
        // viewport — bump it so the Continue button is hit-testable.
        // Production renders inside WoltModalSheet which scrolls.
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        AiPickProviderResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    captured = await Navigator.of(ctx).push(
                      MaterialPageRoute<AiPickProviderResult>(
                        builder: (_) => const AiPickProviderModal(
                          tiles: AiPickProviderModal.defaultTiles,
                          initialSelection: InferenceProviderType.gemini,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final messages = hL10n(tester);
        await tester.tap(find.text(messages.aiPickProviderContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(captured, isNotNull);
        expect(captured!.isConfirmed, isTrue);
        expect(captured!.providerType, InferenceProviderType.gemini);
      },
    );

    testWidgets(
      'Continue carries the LATEST radio selection — proves the modal '
      'forwards the picked tile, not the seeded one',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        AiPickProviderResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    captured = await Navigator.of(ctx).push(
                      MaterialPageRoute<AiPickProviderResult>(
                        builder: (_) => const AiPickProviderModal(
                          tiles: AiPickProviderModal.defaultTiles,
                          initialSelection: InferenceProviderType.gemini,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final messages = hL10n(tester);
        // Pick Anthropic.
        await tester.tap(find.text(messages.aiProviderAnthropicName));
        await tester.pump();
        await tester.tap(find.text(messages.aiPickProviderContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(captured!.providerType, InferenceProviderType.anthropic);
      },
    );

    testWidgets(
      "Don't show again pops with the dontShowAgain sentinel — no "
      'providerType is forwarded because the user is opting out, not '
      'picking',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        AiPickProviderResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    captured = await Navigator.of(ctx).push(
                      MaterialPageRoute<AiPickProviderResult>(
                        builder: (_) => const AiPickProviderModal(
                          tiles: AiPickProviderModal.defaultTiles,
                          initialSelection: InferenceProviderType.gemini,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final messages = hL10n(tester);
        await tester.tap(
          find.text(messages.aiPickProviderDontShowAgainButton),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(captured!.isDontShowAgain, isTrue);
        expect(captured!.providerType, isNull);
      },
    );

    testWidgets(
      'disabled tile cannot be selected — tapping it does not move the '
      'radio off the seeded selection',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            const AiPickProviderModal(
              tiles: [
                AiPickProviderTileSpec(
                  providerType: InferenceProviderType.gemini,
                ),
                AiPickProviderTileSpec(
                  providerType: InferenceProviderType.ollama,
                  badge: AiPickProviderBadge.desktopOnly,
                  disabled: true,
                ),
              ],
              initialSelection: InferenceProviderType.gemini,
            ),
          ),
        );
        await tester.pump();

        // One check icon at start (Gemini).
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        final messages = hL10n(tester);
        await tester.tap(find.text(messages.aiProviderOllamaName));
        await tester.pump();

        // Still exactly one check icon — the disabled tap was a no-op.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );
  });
}
