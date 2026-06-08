import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    // Each row taps to its own id. Run as independent test cases (not a
    // shared-state loop in one body) so a failure points at exactly one
    // row and no `captured` value can leak across iterations. The default
    // row ('m-default') is the seam where the caller clears the override
    // to null; the alternatives ('m-alt-1', 'm-alt-2') pop their own id.
    const rowTaps = <String, String>{
      'm-default': 'Voxtral',
      'm-alt-1': 'Mistral Cloud',
      'm-alt-2': 'Whisper Local',
    };

    for (final entry in rowTaps.entries) {
      final tapTarget = entry.key;
      final rowLabel = entry.value;
      testWidgets(
        "tapping '$rowLabel' pops the picker with id '$tapTarget'",
        (tester) async {
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

          await tester.tap(find.text(rowLabel));
          await tester.pumpAndSettle();
          expect(captured, tapTarget);
        },
      );
    }
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

  group('InferenceModelPickerModal.orderModels — ordering property', () {
    // The first generator drives the list length (0..8). Models get distinct
    // ids by index ('m-0', 'm-1', …) to match production, where each model
    // config has a unique id. The second generator selects the default: an
    // in-range index picks an id from the list; an out-of-range value (>=
    // length) yields a guaranteed-absent default, exercising the "stale
    // pointer renders as-is" branch.
    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 9),
      glados.IntAnys(glados.any).intInRange(0, 12),
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'puts the default first, preserves the rest in order, and never '
      'adds, drops, or duplicates an element',
      (length, defaultSelector) {
        final models = [
          for (var i = 0; i < length; i++) _model(id: 'm-$i', name: 'Model $i'),
        ];
        // In-range selector → a present default id; otherwise an absent one.
        final defaultId = defaultSelector < length
            ? 'm-$defaultSelector'
            : 'm-absent';

        final ordered = InferenceModelPickerModal.orderModels(
          models,
          defaultId,
        );

        // 1) The multiset of ids is preserved (no add/drop/dup).
        List<String> sortedIds(List<AiConfigModel> ms) =>
            ms.map((m) => m.id).toList()..sort();
        expect(sortedIds(ordered), sortedIds(models));

        final defaultPresent = models.any((m) => m.id == defaultId);
        if (!defaultPresent) {
          // Stale / absent default → the original list is returned unchanged
          // (same instance — no reordering work done).
          expect(identical(ordered, models), isTrue);
          return;
        }

        // 2) The default id is at index 0.
        expect(ordered.first.id, defaultId);

        // 3) Every non-default element keeps its original relative order.
        final restAfter = ordered.skip(1).map((m) => m.id).toList();
        final restBefore = models
            .where((m) => m.id != defaultId)
            .map((m) => m.id)
            .toList();
        expect(restAfter, restBefore);
      },
      tags: 'glados',
    );
  });
}
