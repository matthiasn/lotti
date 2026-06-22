import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';

import '../../../../../../widget_test_utils.dart';
import 'ai_pick_provider_modal_test_helpers.dart';

void main() {
  group('AiPickProviderModal.allTypesTiles — every InferenceProviderType', () {
    test(
      'lineup begins with the curated FTUE tiles and appends the '
      'advanced types alphabetically — every InferenceProviderType '
      'value is reachable so the unified modal can fully replace the '
      'removed legacy type picker',
      () {
        final types = AiPickProviderModal.allTypesTiles
            .map((t) => t.providerType)
            .toList();

        // First nine tiles match the FTUE lineup verbatim.
        expect(
          types.take(9),
          AiPickProviderModal.defaultTiles.map((t) => t.providerType),
        );
        // Remaining five are the advanced types appended alphabetically.
        expect(types.skip(9).toList(), [
          InferenceProviderType.genericOpenAi,
          InferenceProviderType.mistral,
          InferenceProviderType.nebiusAiStudio,
          InferenceProviderType.openRouter,
          InferenceProviderType.whisper,
        ]);
        // Every enum value is present exactly once — guard against
        // future enum additions silently dropping out of the picker.
        expect(types.toSet(), InferenceProviderType.values.toSet());
        expect(types.length, InferenceProviderType.values.length);
      },
    );

    test(
      'advanced (non-FTUE) types carry no badge — keeps the curated '
      'badge set scoped to the recommended/new/desktop-only surfacing',
      () {
        final advancedTypes = <InferenceProviderType>{
          InferenceProviderType.genericOpenAi,
          InferenceProviderType.mistral,
          InferenceProviderType.nebiusAiStudio,
          InferenceProviderType.openRouter,
          InferenceProviderType.whisper,
        };
        for (final spec in AiPickProviderModal.allTypesTiles.where(
          (t) => advancedTypes.contains(t.providerType),
        )) {
          expect(
            spec.badge,
            isNull,
            reason: '${spec.providerType} should carry no badge',
          );
        }
      },
    );
  });

  group('AiPickProviderModal — non-FTUE chrome gating', () {
    testWidgets(
      'showFtueChrome:false hides the subtitle, footer hint, and '
      "Don't-show-again button — proves the same widget can render in "
      'pure type-picker mode without leaking FTUE copy',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            const AiPickProviderModal(
              tiles: AiPickProviderModal.allTypesTiles,
              initialSelection: InferenceProviderType.gemini,
              showFtueChrome: false,
            ),
          ),
        );
        await tester.pump();

        final messages = hL10n(tester);
        // Continue button must still be present — without it the
        // modal would have no terminal action in this mode.
        expect(
          find.text(messages.aiPickProviderContinueButton),
          findsOneWidget,
        );
        // The three FTUE-only elements are absent.
        expect(find.text(messages.aiPickProviderSubtitle), findsNothing);
        expect(find.text(messages.aiPickProviderFooterHint), findsNothing);
        expect(
          find.text(messages.aiPickProviderDontShowAgainButton),
          findsNothing,
        );
      },
    );

    testWidgets(
      'showFtueChrome:false renders every InferenceProviderType tile when '
      'fed allTypesTiles — guards the dismissed-FTUE add flow and the '
      'in-form type switcher, both of which must surface genericOpenAi, '
      'OpenRouter, Nebius, Mistral, and Whisper alongside the FTUE seven',
      (tester) async {
        // Tall surface so all fourteen tiles + actions fit without
        // off-stage hit-testing complications.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          makeTestableWidget(
            const AiPickProviderModal(
              tiles: AiPickProviderModal.allTypesTiles,
              initialSelection: InferenceProviderType.gemini,
              showFtueChrome: false,
            ),
          ),
        );
        await tester.pump();

        final messages = hL10n(tester);
        // Spot-check one tile per "tier": curated branded (Gemini),
        // curated desktop-only (Ollama), and one of the advanced
        // types that the FTUE lineup intentionally omits
        // (genericOpenAi). All three must render in this mode.
        expect(find.text(messages.aiProviderGeminiName), findsOneWidget);
        expect(find.text(messages.aiProviderOllamaName), findsOneWidget);
        expect(find.text(messages.aiProviderGenericOpenAiName), findsOneWidget);
      },
    );
  });

  group(
    'AiPickProviderModal.showAllTypes — Future<InferenceProviderType?>',
    () {
      testWidgets(
        'Continue resolves the future with the picked type — the modal '
        'translates its three-state result into the simpler shape that '
        'replaced the legacy showForResult API',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          InferenceProviderType? captured;
          var resolved = false;
          await tester.pumpWidget(
            makeTestableWidget(
              Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () async {
                      captured = await AiPickProviderModal.showAllTypes(
                        context: ctx,
                      );
                      resolved = true;
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
          // Pick OpenAI-compatible (genericOpenAi) — proves the
          // advanced tile is selectable end-to-end, not just rendered.
          await tester.tap(find.text(messages.aiProviderGenericOpenAiName));
          await tester.pump();
          await tester.tap(find.text(messages.aiPickProviderContinueButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(resolved, isTrue);
          expect(captured, InferenceProviderType.genericOpenAi);
        },
      );

      testWidgets(
        'dismissing the sheet resolves the future with null — the '
        'cancelled branch of the underlying three-state result must '
        'collapse to null in this entry-point shape',
        (tester) async {
          InferenceProviderType? captured = InferenceProviderType.gemini;
          var resolved = false;
          await tester.pumpWidget(
            makeTestableWidget(
              Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () async {
                      captured = await AiPickProviderModal.showAllTypes(
                        context: ctx,
                      );
                      resolved = true;
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
          // Swipe-dismiss equivalent: pop with no result.
          Navigator.of(tester.element(find.byType(AiPickProviderModal))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(resolved, isTrue);
          expect(captured, isNull);
        },
      );

      testWidgets(
        'initialSelection seeds the radio — opening the picker with '
        'Anthropic preselected and tapping Continue immediately resolves '
        'the future to Anthropic without any tile tap, which is how the '
        'in-form type switcher restores the current form value',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          InferenceProviderType? captured;
          await tester.pumpWidget(
            makeTestableWidget(
              Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () async {
                      captured = await AiPickProviderModal.showAllTypes(
                        context: ctx,
                        initialSelection: InferenceProviderType.anthropic,
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

          expect(captured, InferenceProviderType.anthropic);
        },
      );
    },
  );

  group('AiPickProviderModal.show — default-result dispatch', () {
    testWidgets(
      'dismissing the sheet without choosing returns '
      'AiPickProviderResult.cancelled (the default for null modal pops)',
      (tester) async {
        AiPickProviderResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    captured = await AiPickProviderModal.show(context: ctx);
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
        // Pop the sheet with no result — mirrors a swipe-dismiss or
        // the modal's close X.
        Navigator.of(tester.element(find.byType(AiPickProviderModal))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(captured, isNotNull);
        expect(captured!.kind, AiPickProviderResultKind.cancelled);
        expect(captured!.providerType, isNull);
      },
    );

    testWidgets(
      'show seeds the radio to the first non-disabled tile when no '
      'initialSelection is supplied — guarantees the modal opens with a '
      'valid Continue target instead of an inert state',
      (tester) async {
        // Custom tile list whose first row is disabled.
        const tiles = [
          AiPickProviderTileSpec(
            providerType: InferenceProviderType.ollama,
            badge: AiPickProviderBadge.desktopOnly,
            disabled: true,
          ),
          AiPickProviderTileSpec(
            providerType: InferenceProviderType.gemini,
            badge: AiPickProviderBadge.recommended,
          ),
        ];
        AiPickProviderResult? captured;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    captured = await AiPickProviderModal.show(
                      context: ctx,
                      tiles: tiles,
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

        // Seed should have skipped the disabled Ollama tile and
        // landed on the first enabled tile (Gemini).
        expect(captured!.providerType, InferenceProviderType.gemini);
      },
    );
  });
}
