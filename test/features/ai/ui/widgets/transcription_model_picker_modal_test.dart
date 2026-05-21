import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/transcription_model_picker_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

AiConfigModel _model({
  required String id,
  required String name,
  String providerModelId = 'model/wire-id',
  String inferenceProviderId = 'provider-1',
  List<Modality> inputModalities = const [Modality.audio, Modality.text],
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: inputModalities,
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  );
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(TranscriptionModelPickerModal)),
)!;

void main() {
  group('TranscriptionModelPickerModal — widget body', () {
    testWidgets(
      'renders every model passed in, with the default row first and '
      'marked with both the localised (default) badge and the check '
      'icon — the alternatives render below in the supplied order, '
      'unbadged and uncheck-iconed',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            TranscriptionModelPickerModal(
              defaultModelId: 'm-default',
              speechCapableModels: [
                _model(id: 'm-other', name: 'Whisper Local'),
                _model(id: 'm-default', name: 'Voxtral'),
                _model(id: 'm-cloud', name: 'Mistral Cloud'),
              ],
            ),
          ),
        );
        await tester.pump();

        final messages = _l10n(tester);
        // All three names render.
        expect(find.text('Voxtral'), findsOneWidget);
        expect(find.text('Whisper Local'), findsOneWidget);
        expect(find.text('Mistral Cloud'), findsOneWidget);

        // Default badge appears exactly once — on the default row.
        expect(
          find.text(messages.aiTranscriptionPickerDefaultBadge),
          findsOneWidget,
        );

        // Check icon appears exactly once.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'a missing default (no defaultModelId, or an id that does not '
      'appear in speechCapableModels) renders the list as-is with no '
      'check icon and no (default) badge — proves a stale profile '
      'pointer does not crash the picker',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            TranscriptionModelPickerModal(
              defaultModelId: 'nonexistent',
              speechCapableModels: [
                _model(id: 'm-1', name: 'Voxtral'),
                _model(id: 'm-2', name: 'Mistral Cloud'),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Voxtral'), findsOneWidget);
        expect(find.text('Mistral Cloud'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        final messages = _l10n(tester);
        expect(
          find.text(messages.aiTranscriptionPickerDefaultBadge),
          findsNothing,
        );
      },
    );

    testWidgets(
      "tapping a row pops the picker with that row's AiConfigModel.id "
      '— covers both the default row (the seam where the override '
      'should be cleared to null at the caller) and an alternative row',
      (tester) async {
        const models = <String>['m-default', 'm-alt-1', 'm-alt-2'];
        for (final tapTarget in models) {
          String? captured;
          await tester.pumpWidget(
            makeTestableWidget(
              Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () async {
                      captured = await Navigator.of(ctx).push(
                        MaterialPageRoute<String>(
                          builder: (_) => TranscriptionModelPickerModal(
                            defaultModelId: 'm-default',
                            speechCapableModels: [
                              _model(id: 'm-default', name: 'Voxtral'),
                              _model(id: 'm-alt-1', name: 'Mistral Cloud'),
                              _model(id: 'm-alt-2', name: 'Whisper Local'),
                            ],
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
          await tester.pumpAndSettle();

          final label = switch (tapTarget) {
            'm-default' => 'Voxtral',
            'm-alt-1' => 'Mistral Cloud',
            'm-alt-2' => 'Whisper Local',
            _ => throw StateError('unmapped target'),
          };
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(captured, tapTarget);
        }
      },
    );
  });

  group('TranscriptionModelPickerModal.show — short-circuits', () {
    testWidgets(
      'speechCapableModels.length == 1 short-circuits — the lone model '
      'id is returned without rendering a modal, preserving the '
      'one-tap transcribe flow for users with a single speech-capable '
      'model configured',
      (tester) async {
        String? returned;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    returned = await TranscriptionModelPickerModal.show(
                      context: ctx,
                      defaultModelId: 'only-model',
                      speechCapableModels: [
                        _model(id: 'only-model', name: 'Voxtral'),
                      ],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // No modal was shown — the widget tree contains no instance.
        expect(find.byType(TranscriptionModelPickerModal), findsNothing);
        expect(returned, 'only-model');
      },
    );

    testWidgets(
      'speechCapableModels.isEmpty resolves to null without rendering '
      'a modal — defensive path for the can-not-happen case where the '
      'popup audio gate let the user through with no audio-capable '
      'model configured',
      (tester) async {
        String? returned = 'sentinel-pre';
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    returned = await TranscriptionModelPickerModal.show(
                      context: ctx,
                      defaultModelId: null,
                      speechCapableModels: const <AiConfigModel>[],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(TranscriptionModelPickerModal), findsNothing);
        expect(returned, isNull);
      },
    );
  });
}
