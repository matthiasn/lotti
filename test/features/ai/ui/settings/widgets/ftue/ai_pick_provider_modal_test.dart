import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../../../widget_test_utils.dart';

/// Resolves the localised messages bundle from the running widget
/// tree so test assertions can stay in sync with the live ARB files
/// (rather than copying English strings inline and silently drifting
/// when copy is updated).
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AiPickProviderModal)))!;

void main() {
  group('AiPickProviderModal.defaultTiles — static spec', () {
    test(
      'lineup matches the design: '
      'Gemini → OpenAI → Anthropic → Alibaba → MLX Audio → Ollama → Voxtral',
      () {
        expect(
          AiPickProviderModal.defaultTiles.map((t) => t.providerType).toList(),
          [
            InferenceProviderType.gemini,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.alibaba,
            InferenceProviderType.mlxAudio,
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
        final messages = _l10n(tester);
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
      'MLX Audio NEW, Ollama DESKTOP ONLY, Voxtral DESKTOP ONLY) — '
      'six badges total '
      'because OpenAI is intentionally un-badged',
      (tester) async {
        await pumpModal(tester);
        expect(find.byType(DesignSystemBadge), findsNWidgets(6));
      },
    );

    testWidgets(
      'tapping a tile updates the visual selection — the previously '
      'selected tile clears and the new tile shows the filled radio '
      'indicator (a check-rounded icon inside the accent circle)',
      (tester) async {
        await pumpModal(tester);
        final messages = _l10n(tester);
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
        final messages = _l10n(tester);
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
        final messages = _l10n(tester);
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
        final messages = _l10n(tester);
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

        final messages = _l10n(tester);
        await tester.tap(find.text(messages.aiProviderOllamaName));
        await tester.pump();

        // Still exactly one check icon — the disabled tap was a no-op.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );
  });

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

        // First seven tiles match the FTUE lineup verbatim.
        expect(
          types.take(7),
          AiPickProviderModal.defaultTiles.map((t) => t.providerType),
        );
        // Remaining five are the advanced types appended alphabetically.
        expect(types.skip(7).toList(), [
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

        final messages = _l10n(tester);
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
        // Tall surface so all twelve tiles + actions fit without
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

        final messages = _l10n(tester);
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
          final messages = _l10n(tester);
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
          final messages = _l10n(tester);
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
        final messages = _l10n(tester);
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
