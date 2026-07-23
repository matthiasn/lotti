import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';

void main() {
  group('AiResponseSummary', () {
    final testDateTime = DateTime(2023);

    final testAiResponseEntry = AiResponseEntry(
      meta: Metadata(
        id: 'test-id',
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'gpt-4',
        temperature: 0.7,
        systemMessage: 'System message',
        prompt: 'User prompt',
        thoughts: '',
        response: 'AI response',
        type: AiResponseType.imageAnalysis,
      ),
    );
    testWidgets('renders GptMarkdown for standard responses', (
      tester,
    ) async {
      const responseText = 'The image shows a beautiful landscape.';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseText,
          type: AiResponseType.imageAnalysis,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      expect(find.byType(GptMarkdown), findsOneWidget);

      // The raw response text must be forwarded verbatim to GptMarkdown.data
      // (no pre-processing for non-prompt-generation responses).
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, responseText);
    });

    testWidgets('does not filter H1 for non-task summary responses', (
      tester,
    ) async {
      const responseWithH1 = '''
# Analysis Results

The image shows a beautiful landscape with mountains.''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithH1,
          type: AiResponseType.imageAnalysis,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // GptMarkdown should be rendered
      expect(find.byType(GptMarkdown), findsOneWidget);

      // Check that the widget is displaying the content with H1
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data.contains('# Analysis Results'), true);
    });

    testWidgets(
      'applies fade out effect when fadeOut is true for non-task summaries',
      (tester) async {
        final aiResponse = testAiResponseEntry.copyWith(
          data: testAiResponseEntry.data.copyWith(
            response: 'Test response content',
            type: AiResponseType
                .imageAnalysis, // Changed to non-task summary type
          ),
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: AiResponseSummary(
              aiResponse,
              linkedFromId: 'test-id',
              fadeOut: true,
            ),
          ),
        );

        // Check for ShaderMask when fadeOut is true
        expect(find.byType(ShaderMask), findsOneWidget);
        // ConstrainedBox with maxHeight should be inside ShaderMask
        final constrainedBox = find.descendant(
          of: find.byType(ShaderMask),
          matching: find.byType(ConstrainedBox),
        );
        expect(constrainedBox, findsOneWidget);
      },
    );

    testWidgets('opens modal on double tap for non-task summaries', (
      tester,
    ) async {
      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: 'Test response content',
          type:
              AiResponseType.imageAnalysis, // Changed to non-task summary type
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Double tap to open modal
      await tester.pumpAndSettle();
      final gestureDetector = find.byType(GestureDetector).first;
      await tester.tap(gestureDetector);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gestureDetector);
      await tester.pumpAndSettle();

      // Modal should be opened (we can't directly test the modal content
      // as it's shown in a different route)
    });

    testWidgets('uses GeneratedPromptCard for prompt generation responses', (
      tester,
    ) async {
      const promptResponse = '''
## Summary
A well-crafted prompt for implementing OAuth authentication.

## Prompt
Help me implement OAuth 2.0 authentication in my Flutter app.
''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: promptResponse,
          type: AiResponseType.promptGeneration,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Should use GeneratedPromptCard for prompt generation
      expect(find.byType(GeneratedPromptCard), findsOneWidget);

      // Any GptMarkdown is nested inside GeneratedPromptCard (the card renders
      // its TLDR via AgentMarkdownView/GptMarkdown), not at the top level.
      expect(
        find.descendant(
          of: find.byType(GeneratedPromptCard),
          matching: find.byType(GptMarkdown),
        ),
        findsWidgets,
      );
    });

    testWidgets(
      'uses GeneratedPromptCard for image prompt generation responses',
      (tester) async {
        const imagePromptResponse = '''
## Summary
A vibrant isometric illustration of a fortress being built.

## Prompt
Digital illustration of a medieval fortress under construction, 60% complete.
Style: isometric digital art. --ar 16:9
''';

        final aiResponse = testAiResponseEntry.copyWith(
          data: testAiResponseEntry.data.copyWith(
            response: imagePromptResponse,
            type: AiResponseType.imagePromptGeneration,
          ),
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: AiResponseSummary(
              aiResponse,
              linkedFromId: 'test-id',
              fadeOut: false,
            ),
          ),
        );

        // Should use GeneratedPromptCard for image prompt generation
        expect(find.byType(GeneratedPromptCard), findsOneWidget);

        // Any GptMarkdown is nested inside GeneratedPromptCard (the card
        // renders its TLDR via AgentMarkdownView/GptMarkdown), not at the
        // top level.
        expect(
          find.descendant(
            of: find.byType(GeneratedPromptCard),
            matching: find.byType(GptMarkdown),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('handles link tap in non-task summary responses', (
      tester,
    ) async {
      // Set up mock URL launcher and capture original for cleanup
      final originalPlatform = UrlLauncherPlatform.instance;
      final mockUrlLauncher = MockUrlLauncher();
      registerFallbackValue(FakeLaunchOptions());
      UrlLauncherPlatform.instance = mockUrlLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      when(
        () => mockUrlLauncher.canLaunch(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      const responseWithLink =
          'Check the [docs](https://docs.flutter.dev) for info.';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithLink,
          type: AiResponseType.imageAnalysis,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find GestureDetector widgets with onTap and manually call the callback
      // to verify the URL launcher integration
      var linkCallbackFound = false;
      final gestureDetectors = tester.widgetList<GestureDetector>(
        find.byType(GestureDetector),
      );
      for (final gd in gestureDetectors) {
        if (gd.onTap != null) {
          // Try to invoke the callback and check if it triggers URL launcher
          gd.onTap!();
          await tester.pumpAndSettle();

          // Check if URL launcher was called with the expected URL
          try {
            verify(
              () => mockUrlLauncher.launchUrl(
                'https://docs.flutter.dev',
                any(),
              ),
            ).called(1);
            linkCallbackFound = true;
            break;
          } catch (_) {
            // This callback didn't trigger the right URL, continue searching
            reset(mockUrlLauncher);
            when(
              () => mockUrlLauncher.canLaunch(any()),
            ).thenAnswer((_) async => true);
            when(
              () => mockUrlLauncher.launchUrl(any(), any()),
            ).thenAnswer((_) async => true);
          }
        }
      }
      expect(linkCallbackFound, isTrue);
    });

    group('tinted aiCard surface and binary per-card collapse', () {
      // Comfortably above both thresholds (500 chars / 6 newlines).
      final longOcrText = List.generate(
        40,
        (i) =>
            'Cargo line $i: sardine pod docking 05.10.26 14:30 UTC, Bay 7, '
            'Orbital Habitat Waddle One.',
      ).join('\n');
      const shortSummaryText =
          'The placard confirms the sardine pod docks on 05.10.2026 at '
          '14:30 UTC at the orbital penguin habitat.';

      AiResponseEntry buildResponse(String text) =>
          testAiResponseEntry.copyWith(
            data: testAiResponseEntry.data.copyWith(
              response: text,
              type: AiResponseType.imageAnalysis,
            ),
          );

      Future<void> pumpSummary(
        WidgetTester tester, {
        required String text,
        bool collapsible = false,
        bool fadeOut = false,
      }) {
        return tester.pumpWidget(
          WidgetTestBench(
            child: SingleChildScrollView(
              child: AiResponseSummary(
                buildResponse(text),
                linkedFromId: 'test-id',
                fadeOut: fadeOut,
                collapsible: collapsible,
              ),
            ),
          ),
        );
      }

      BoxDecoration cardDecoration(WidgetTester tester) {
        final container = tester.widget<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    dsTokensLight.colors.aiCard.background.withValues(
                      alpha: 0.5,
                    ),
          ),
        );
        return container.decoration! as BoxDecoration;
      }

      testWidgets(
        'renders the tinted aiCard surface: background fill, soft accent '
        'hairline, no shadow',
        (tester) async {
          await pumpSummary(tester, text: shortSummaryText);

          final decoration = cardDecoration(tester);
          expect(
            decoration.border!.top.color,
            dsTokensLight.colors.aiCard.borderSoft,
          );
          expect(decoration.boxShadow, isNull);
          expect(decoration.gradient, isNull);
        },
      );

      testWidgets(
        'long collapsible response starts fully collapsed (no body) and '
        'toggles open/closed',
        (tester) async {
          await pumpSummary(tester, text: longOcrText, collapsible: true);

          // Collapsed by default: no body at all, just the toggle (and the
          // attribution pill identifying the analysis).
          expect(
            find.byKey(AiResponseSummary.collapseToggleKey),
            findsOneWidget,
          );
          expect(find.text('Show more'), findsOneWidget);
          expect(find.byType(GptMarkdown), findsNothing);

          await tester.tap(find.byKey(AiResponseSummary.collapseToggleKey));
          await tester.pump();
          expect(find.text('Show less'), findsOneWidget);
          expect(find.byType(GptMarkdown), findsOneWidget);

          // Expanded content pushes the toggle below the fold — scroll it
          // back into view before collapsing again.
          await tester.ensureVisible(
            find.byKey(AiResponseSummary.collapseToggleKey),
          );
          await tester.pump();
          await tester.tap(find.byKey(AiResponseSummary.collapseToggleKey));
          await tester.pump();
          expect(find.text('Show more'), findsOneWidget);
          expect(find.byType(GptMarkdown), findsNothing);
        },
      );

      testWidgets('short collapsible response renders fully with no toggle', (
        tester,
      ) async {
        await pumpSummary(tester, text: shortSummaryText, collapsible: true);

        expect(find.byKey(AiResponseSummary.collapseToggleKey), findsNothing);
        expect(find.byType(GptMarkdown), findsOneWidget);
        expect(find.byType(ShaderMask), findsNothing);
      });

      testWidgets(
        'non-collapsible long response renders fully with no toggle',
        (tester) async {
          await pumpSummary(tester, text: longOcrText);

          expect(
            find.byKey(AiResponseSummary.collapseToggleKey),
            findsNothing,
          );
          expect(find.byType(GptMarkdown), findsOneWidget);
          expect(find.byType(ShaderMask), findsNothing);
        },
      );

      testWidgets('legacy fadeOut keeps the faded preview but never a toggle', (
        tester,
      ) async {
        await pumpSummary(tester, text: longOcrText, fadeOut: true);

        expect(find.byType(ShaderMask), findsOneWidget);
        expect(find.byKey(AiResponseSummary.collapseToggleKey), findsNothing);
      });

      testWidgets(
        'collapse thresholds: >500 chars OR >6 newlines, boundaries exact',
        (tester) async {
          final cases = <(String, String, bool)>[
            ('exactly 500 chars stays open', 'a' * 500, false),
            ('501 chars collapses', 'a' * 501, true),
            ('exactly 6 newlines stays open', '${'line\n' * 6}end', false),
            ('7 newlines collapses (short text)', '${'line\n' * 7}end', true),
          ];

          for (final (label, text, collapses) in cases) {
            // Fresh element per case — the widget deliberately keeps its
            // collapse state on same-id rebuilds, so cases must not share
            // element state.
            await tester.pumpWidget(const SizedBox.shrink());
            await pumpSummary(tester, text: text, collapsible: true);
            expect(
              find.byKey(AiResponseSummary.collapseToggleKey),
              collapses ? findsOneWidget : findsNothing,
              reason: label,
            );
            expect(
              find.byType(GptMarkdown),
              collapses ? findsNothing : findsOneWidget,
              reason: label,
            );
          }
        },
      );

      testWidgets('the toggle renders in the AI accent color', (tester) async {
        await pumpSummary(tester, text: longOcrText, collapsible: true);

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(AiResponseSummary.collapseToggleKey),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, dsTokensLight.colors.aiCard.accent);

        final label = tester.widget<Text>(
          find.descendant(
            of: find.byKey(AiResponseSummary.collapseToggleKey),
            matching: find.text('Show more'),
          ),
        );
        expect(label.style?.color, dsTokensLight.colors.aiCard.accent);
      });

      testWidgets(
        'the attribution pill stays visible while the body is collapsed',
        (tester) async {
          await pumpSummary(tester, text: longOcrText, collapsible: true);

          expect(find.byType(GptMarkdown), findsNothing);
          // The pill is the collapsed card's only identity (model/cost), so
          // it must not collapse away with the body.
          expect(find.byType(AiAttributionSummary), findsOneWidget);
        },
      );

      testWidgets(
        'a recycled card re-derives its default for a new response but '
        'keeps user-chosen state on same-id rebuilds',
        (tester) async {
          final responseA = buildResponse(longOcrText);
          final responseB = buildResponse(longOcrText).copyWith(
            meta: responseA.meta.copyWith(id: 'other-response'),
          );

          Future<void> pumpEntry(AiResponseEntry entry) {
            return tester.pumpWidget(
              WidgetTestBench(
                child: SingleChildScrollView(
                  child: AiResponseSummary(
                    entry,
                    linkedFromId: 'test-id',
                    fadeOut: false,
                    collapsible: true,
                  ),
                ),
              ),
            );
          }

          await pumpEntry(responseA);
          await tester.tap(find.byKey(AiResponseSummary.collapseToggleKey));
          await tester.pump();
          expect(find.text('Show less'), findsOneWidget);

          // Same id, new build (e.g. background refresh): the user's
          // expanded choice must survive.
          await pumpEntry(responseA);
          expect(find.text('Show less'), findsOneWidget);

          // Different response id in the same element: default re-derived,
          // long content starts collapsed again.
          await pumpEntry(responseB);
          expect(find.text('Show more'), findsOneWidget);
          expect(find.byType(GptMarkdown), findsNothing);
        },
      );
    });
  });
}
