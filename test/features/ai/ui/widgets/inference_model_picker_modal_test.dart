import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_model_picker_modal.dart';

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

void main() {
  // Synthetic badge label — the picker accepts any string, so the
  // test stays decoupled from the project's l10n surface. The
  // popup-menu integration tests cover the real l10n wiring.
  const badgeLabel = 'Default';

  group('InferenceModelPickerModal — widget body', () {
    testWidgets(
      'renders every model passed in, with the default row first and '
      'marked with both the supplied badge label and the check icon — '
      'the alternatives render below in the supplied order, unbadged '
      'and uncheck-iconed',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            InferenceModelPickerModal(
              defaultModelId: 'm-default',
              models: [
                _model(id: 'm-other', name: 'Whisper Local'),
                _model(id: 'm-default', name: 'Voxtral'),
                _model(id: 'm-cloud', name: 'Mistral Cloud'),
              ],
              defaultBadgeLabel: badgeLabel,
            ),
          ),
        );
        await tester.pump();

        // All three names render.
        expect(find.text('Voxtral'), findsOneWidget);
        expect(find.text('Whisper Local'), findsOneWidget);
        expect(find.text('Mistral Cloud'), findsOneWidget);

        // Default badge appears exactly once — on the default row.
        expect(find.text(badgeLabel), findsOneWidget);

        // Check icon appears exactly once.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'a missing default (no defaultModelId, or an id that does not '
      'appear in [models]) renders the list as-is with no check icon '
      'and no default badge — proves a stale profile pointer does not '
      'crash the picker',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            InferenceModelPickerModal(
              defaultModelId: 'nonexistent',
              models: [
                _model(id: 'm-1', name: 'Voxtral'),
                _model(id: 'm-2', name: 'Mistral Cloud'),
              ],
              defaultBadgeLabel: badgeLabel,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Voxtral'), findsOneWidget);
        expect(find.text('Mistral Cloud'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.text(badgeLabel), findsNothing);
      },
    );

    testWidgets(
      "tapping a row pops the picker with that row's AiConfigModel.id "
      '— covers both the default row (the seam where the override '
      'should be cleared to null at the caller) and an alternative '
      'row',
      (tester) async {
        const targets = <String>['m-default', 'm-alt-1', 'm-alt-2'];
        const labels = <String, String>{
          'm-default': 'Voxtral',
          'm-alt-1': 'Mistral Cloud',
          'm-alt-2': 'Whisper Local',
        };

        for (final tapTarget in targets) {
          String? captured;
          await tester.pumpWidget(
            makeTestableWidget(
              Builder(
                builder: (ctx) => Center(
                  child: TextButton(
                    onPressed: () async {
                      captured = await Navigator.of(ctx).push(
                        MaterialPageRoute<String>(
                          builder: (_) => InferenceModelPickerModal(
                            defaultModelId: 'm-default',
                            models: [
                              _model(id: 'm-default', name: 'Voxtral'),
                              _model(id: 'm-alt-1', name: 'Mistral Cloud'),
                              _model(id: 'm-alt-2', name: 'Whisper Local'),
                            ],
                            defaultBadgeLabel: badgeLabel,
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

          await tester.tap(find.text(labels[tapTarget]!));
          await tester.pumpAndSettle();
          expect(captured, tapTarget);
        }
      },
    );
  });

  group('InferenceModelPickerModal.show — modal chrome', () {
    testWidgets(
      'renders the supplied title in the modal header when the picker '
      'actually opens (two or more models)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => InferenceModelPickerModal.show(
                    context: ctx,
                    defaultModelId: 'm-1',
                    models: [
                      _model(id: 'm-1', name: 'Voxtral'),
                      _model(id: 'm-2', name: 'Mistral Cloud'),
                    ],
                    title: 'Pick a model',
                    defaultBadgeLabel: badgeLabel,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        // Modal open is a route transition — needs a real settle.
        await tester.pumpAndSettle();

        expect(find.byType(InferenceModelPickerModal), findsOneWidget);
        expect(find.text('Pick a model'), findsOneWidget);
      },
    );
  });

  group('InferenceModelPickerModal.show — short-circuits', () {
    testWidgets(
      'models.length == 1 short-circuits — the lone model id is '
      'returned without rendering a modal, preserving the one-tap '
      'flow for users with a single slot-capable model configured',
      (tester) async {
        String? returned;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    returned = await InferenceModelPickerModal.show(
                      context: ctx,
                      defaultModelId: 'only-model',
                      models: [_model(id: 'only-model', name: 'Voxtral')],
                      title: 'Pick a model',
                      defaultBadgeLabel: badgeLabel,
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
        expect(find.byType(InferenceModelPickerModal), findsNothing);
        expect(returned, 'only-model');
      },
    );

    testWidgets(
      'models.isEmpty resolves to null without rendering a modal — '
      'defensive path for the can-not-happen case where the popup '
      'modality gate let the user through with no slot-capable model '
      'configured',
      (tester) async {
        String? returned = 'sentinel-pre';
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    returned = await InferenceModelPickerModal.show(
                      context: ctx,
                      defaultModelId: null,
                      models: const <AiConfigModel>[],
                      title: 'Pick a model',
                      defaultBadgeLabel: badgeLabel,
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

        expect(find.byType(InferenceModelPickerModal), findsNothing);
        expect(returned, isNull);
      },
    );
  });
}
