import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/breakpoints.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_result_modal.dart';

import '../../../../../../widget_test_utils.dart';

AiProviderSetupResultData _data({
  String providerName = 'Google Gemini',
  InferenceProviderType providerType = InferenceProviderType.gemini,
  int modelsCreated = 3,
  int modelsVerified = 0,
  String profileName = 'Gemini Flash',
  String? categoryName = 'Test Category Gemini Enabled',
  bool categoryCreated = true,
  List<String> errors = const [],
}) {
  return AiProviderSetupResultData(
    providerName: providerName,
    providerType: providerType,
    modelsCreated: modelsCreated,
    modelsVerified: modelsVerified,
    profileName: profileName,
    categoryName: categoryName,
    categoryCreated: categoryCreated,
    errors: errors,
  );
}

void main() {
  group('AiProviderSetupResultData', () {
    test('totalModels sums created + verified', () {
      const result = GeminiFtueResult(
        modelsCreated: 2,
        modelsVerified: 1,
        categoryCreated: true,
      );
      final data = AiProviderSetupResultData.fromGemini(result: result);
      expect(data.totalModels, equals(3));
      expect(data.providerName, equals('Gemini'));
      expect(data.providerType, equals(InferenceProviderType.gemini));
    });

    test('from() dispatches by runtime type for every wired provider', () {
      final cases = <(AiFtueResult, InferenceProviderType, String)>[
        (
          const GeminiFtueResult(
            modelsCreated: 1,
            modelsVerified: 0,
            categoryCreated: true,
          ),
          InferenceProviderType.gemini,
          'Gemini',
        ),
        (
          const OpenAiFtueResult(
            modelsCreated: 1,
            modelsVerified: 0,
            categoryCreated: true,
          ),
          InferenceProviderType.openAi,
          'OpenAI',
        ),
        (
          const MistralFtueResult(
            modelsCreated: 1,
            modelsVerified: 0,
            categoryCreated: true,
          ),
          InferenceProviderType.mistral,
          'Mistral',
        ),
        (
          const AlibabaFtueResult(
            modelsCreated: 1,
            modelsVerified: 0,
            categoryCreated: true,
          ),
          InferenceProviderType.alibaba,
          'Alibaba Cloud (Qwen)',
        ),
        (
          const AnthropicFtueResult(
            modelsCreated: 1,
            modelsVerified: 0,
            categoryCreated: true,
          ),
          InferenceProviderType.anthropic,
          'Anthropic',
        ),
        (
          const OllamaFtueResult(categoryCreated: true),
          InferenceProviderType.ollama,
          'Ollama',
        ),
      ];

      for (final (result, type, name) in cases) {
        final data = AiProviderSetupResultData.from(result);
        expect(data.providerType, equals(type));
        expect(data.providerName, equals(name));
      }
    });
  });

  group('AiProviderSetupResultModal widget body', () {
    testWidgets(
      'renders header, lead, model bullet, profile bullet, and category bullet '
      '(created variant) when all data is present',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(data: _data()),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('Google Gemini is connected'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'We set things up for you',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Configured 3 models'), findsOneWidget);
        expect(
          find.textContaining('Gemini Flash'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining('Test Category Gemini Enabled'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'reused-category variant uses the "Reusing existing" bullet copy',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(
              data: _data(categoryCreated: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Reusing existing'), findsOneWidget);
      },
    );

    testWidgets(
      'omits the models bullet entirely when totalModels is zero (Ollama path)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(
              data: _data(
                providerName: 'Ollama',
                providerType: InferenceProviderType.ollama,
                modelsCreated: 0,
                // ignore: avoid_redundant_argument_values
                modelsVerified: 0,
                profileName: 'Local (Ollama)',
                categoryName: 'Test Category Ollama Enabled',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Configured '), findsNothing);
        expect(find.textContaining('Local (Ollama)'), findsAtLeastNWidgets(1));
        expect(
          find.textContaining('Test Category Ollama Enabled'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'errors block renders a header with the count plus one row per error',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(
              data: _data(
                errors: const ['boom one', 'boom two'],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('2 issues'), findsOneWidget);
        expect(find.textContaining('boom one'), findsOneWidget);
        expect(find.textContaining('boom two'), findsOneWidget);
      },
    );

    testWidgets(
      'Start using AI button pops the modal with startUsingAi — and is '
      'the only action rendered (the legacy Review setup button is gone)',
      (tester) async {
        AiProviderSetupResultAction? captured;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context)
                        .push<AiProviderSetupResultAction>(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: Center(
                                child: AiProviderSetupResultModal(
                                  data: _data(),
                                ),
                              ),
                            ),
                          ),
                        );
                    captured = result;
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Guard: no review-setup affordance survives the redesign.
        expect(find.text('Review setup'), findsNothing);

        await tester.tap(find.text('Start using AI'));
        await tester.pumpAndSettle();
        expect(captured, equals(AiProviderSetupResultAction.startUsingAi));
      },
    );

    testWidgets(
      'narrow surface stretches the CTA to fill the row — mobile '
      'primary-button pattern',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(data: _data()),
          ),
        );
        await tester.pump();

        final cta = tester.getRect(find.text('Start using AI'));
        // The button's text label is centred inside a button that itself
        // fills the row; checking that the row size matches the modal
        // content width is enough — if the layout regressed back to a
        // hug-content size, the CTA would be a fraction of this width.
        expect(cta.width, greaterThan(120));
      },
    );

    testWidgets(
      'wide surface caps the CTA width and right-aligns it — desktop '
      'dialog pattern',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          makeTestableWidget(
            AiProviderSetupResultModal(data: _data()),
          ),
        );
        await tester.pump();

        // Locate the rendered button rect via the Align ancestor — the
        // CTA must not stretch full-width at desktop sizes.
        final align = tester.widget<Align>(
          find.ancestor(
            of: find.text('Start using AI'),
            matching: find.byType(Align),
          ),
        );
        expect(align.alignment, equals(Alignment.centerRight));

        // The cap itself: the CTA's ConstrainedBox must carry the
        // documented desktop max width so the button stops stretching.
        final cap = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.text('Start using AI'),
                matching: find.byWidgetPredicate(
                  (w) => w is ConstrainedBox && w.constraints.maxWidth.isFinite,
                ),
              )
              .first,
        );
        expect(
          cap.constraints.maxWidth,
          aiSetupResultDesktopCtaMaxWidth,
        );
        expect(
          tester.getRect(find.text('Start using AI')).width,
          lessThanOrEqualTo(aiSetupResultDesktopCtaMaxWidth),
        );
      },
    );
  });
}
