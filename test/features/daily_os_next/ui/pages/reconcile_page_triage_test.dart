import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import 'reconcile_page_test_helpers.dart';

void main() {
  group('reconcileDraftingSelections', () {
    test('matched item with a task id contributes its task id', () {
      final result = reconcileDraftingSelections(
        hReconcileData(
          parsed: [
            hParsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          ],
        ),
      );

      expect(result.taskIds, equals(['t1']));
      expect(result.captureItemIds, isEmpty);
    });

    test('update item with a task id contributes its task id', () {
      final result = reconcileDraftingSelections(
        hReconcileData(
          parsed: [
            hParsed('p1', kind: ParsedItemKind.update, matchedTaskId: 't1'),
          ],
        ),
      );

      expect(result.taskIds, equals(['t1']));
      expect(result.captureItemIds, isEmpty);
    });

    test(
      'matched item with a null task id falls back to its capture item id',
      () {
        final result = reconcileDraftingSelections(
          hReconcileData(
            parsed: [hParsed('p1', kind: ParsedItemKind.matched)],
          ),
        );

        expect(result.taskIds, isEmpty);
        expect(result.captureItemIds, equals(['p1']));
      },
    );

    test(
      'update item with a null task id falls back to its capture item id',
      () {
        final result = reconcileDraftingSelections(
          hReconcileData(
            parsed: [hParsed('p1', kind: ParsedItemKind.update)],
          ),
        );

        expect(result.taskIds, isEmpty);
        expect(result.captureItemIds, equals(['p1']));
      },
    );

    test('newTask item always contributes its capture item id', () {
      final result = reconcileDraftingSelections(
        hReconcileData(
          parsed: [
            // A matchedTaskId is present but irrelevant for a newTask kind,
            // which is never task-bound.
            hParsed('p1', kind: ParsedItemKind.newTask, matchedTaskId: 't1'),
          ],
        ),
      );

      expect(result.taskIds, isEmpty);
      expect(result.captureItemIds, equals(['p1']));
    });

    test(
      'triage decision with action today contributes its key as a task id',
      () {
        final result = reconcileDraftingSelections(
          hReconcileData(
            triageDecisions: {'t1': hTriage('t1', TriageAction.today)},
          ),
        );

        expect(result.taskIds, equals(['t1']));
        expect(result.captureItemIds, isEmpty);
      },
    );

    test(
      'triage decision with action doNow contributes its key as a task id',
      () {
        final result = reconcileDraftingSelections(
          hReconcileData(
            triageDecisions: {'t1': hTriage('t1', TriageAction.doNow)},
          ),
        );

        expect(result.taskIds, equals(['t1']));
        expect(result.captureItemIds, isEmpty);
      },
    );

    test('triage decisions with non-selecting actions are excluded', () {
      final result = reconcileDraftingSelections(
        hReconcileData(
          triageDecisions: {
            't_defer': hTriage('t_defer', TriageAction.defer),
            't_done': hTriage('t_done', TriageAction.done),
            't_drop': hTriage('t_drop', TriageAction.drop),
          },
        ),
      );

      expect(result.taskIds, isEmpty);
      expect(result.captureItemIds, isEmpty);
    });

    test(
      'a task id from both a matched item and a today triage appears once',
      () {
        final result = reconcileDraftingSelections(
          hReconcileData(
            parsed: [
              hParsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
            ],
            triageDecisions: {'t1': hTriage('t1', TriageAction.today)},
          ),
        );

        expect(result.taskIds, equals(['t1']));
        expect(result.captureItemIds, isEmpty);
      },
    );

    test('combines parsed and triage contributions across branches', () {
      final result = reconcileDraftingSelections(
        hReconcileData(
          parsed: [
            hParsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
            hParsed('p2', kind: ParsedItemKind.update, matchedTaskId: 't2'),
            hParsed('p3', kind: ParsedItemKind.matched), // null → capture
            hParsed('p4', kind: ParsedItemKind.newTask), // new → capture
          ],
          triageDecisions: {
            't_today': hTriage('t_today', TriageAction.today),
            't_now': hTriage('t_now', TriageAction.doNow),
            't_defer': hTriage('t_defer', TriageAction.defer),
          },
        ),
      );

      expect(
        result.taskIds,
        unorderedEquals(['t1', 't2', 't_today', 't_now']),
      );
      expect(result.captureItemIds, unorderedEquals(['p3', 'p4']));
    });
  });

  group('reconcileDraftingSelections (Glados)', () {
    // The strongest single invariant is the partition property: it pins down
    // exactly where each parsed item lands AND that the two output lists never
    // overlap on parsed-derived ids, which subsumes the weaker
    // "every id is unique" and "each parsed item contributes once" properties.
    // Triage today/doNow keys are then checked to be a subset of taskIds.
    glados.Glados<List<SelectionSpec>>(
      glados.any.selectionSpecs,
    ).test('partitions parsed items and folds in triage selections', (specs) {
      // Real parsed-item ids are unique per capture, so assign each generated
      // item a position-unique id. Matched-task ids and triage keys still draw
      // from a tiny seed space so they collide across the list and exercise the
      // Set-based de-duplication.
      final parsed = [
        for (var i = 0; i < specs.length; i++) specs[i].parsedItemAt(i),
      ];
      final triageDecisions = {
        for (final s in specs)
          if (s.triageTaskId != null) s.triageTaskId!: s.triageResult!,
      };
      final data = hReconcileData(
        parsed: parsed,
        triageDecisions: triageDecisions,
      );

      final result = reconcileDraftingSelections(data);
      final taskIds = result.taskIds;
      final captureItemIds = result.captureItemIds;

      // (a) No duplicates within either list.
      expect(taskIds.toSet().length, taskIds.length);
      expect(captureItemIds.toSet().length, captureItemIds.length);

      // (b) Every parsed item lands in exactly one bucket, on the expected
      //     side, with the expected id.
      for (final item in parsed) {
        final boundTaskId =
            (item.kind == ParsedItemKind.matched ||
                item.kind == ParsedItemKind.update)
            ? item.matchedTaskId
            : null;
        if (boundTaskId != null) {
          expect(taskIds, contains(boundTaskId));
          expect(captureItemIds, isNot(contains(item.id)));
        } else {
          expect(captureItemIds, contains(item.id));
        }
      }

      // (c) Every today/doNow triage key ends up in taskIds; other actions
      //     never add their key on their own.
      for (final entry in triageDecisions.entries) {
        final action = entry.value.action;
        if (action == TriageAction.today || action == TriageAction.doNow) {
          expect(taskIds, contains(entry.key));
        }
      }
    }, tags: 'glados');
  });

  group('ReconcileModalContent', () {
    testWidgets('narrow surface stacks the decide column below heard', (
      tester,
    ) async {
      await hPumpModal(tester, width: 500, height: 1200);

      final context = tester.element(find.byType(ReconcileModalContent));
      final messages = context.messages;

      // Column content rendered.
      expect(find.text(hKHeardTitle), findsOneWidget);
      expect(find.text(hKPendingTitle), findsOneWidget);

      final heard = tester.getTopLeft(
        find.text(messages.dailyOsNextReconcileHeardOverline),
      );
      final decide = tester.getTopLeft(
        find.text(messages.dailyOsNextReconcileDecideOverline),
      );

      // Stacked: decide overline sits below the heard overline, roughly
      // sharing the same left edge.
      expect(decide.dy, greaterThan(heard.dy));
      expect((decide.dx - heard.dx).abs(), lessThan(1));
    });

    testWidgets('wide surface lays heard and decide columns side by side', (
      tester,
    ) async {
      await hPumpModal(tester, width: 1200, height: 900);

      final context = tester.element(find.byType(ReconcileModalContent));
      final messages = context.messages;

      expect(find.text(hKHeardTitle), findsOneWidget);
      expect(find.text(hKPendingTitle), findsOneWidget);

      final heard = tester.getTopLeft(
        find.text(messages.dailyOsNextReconcileHeardOverline),
      );
      final decide = tester.getTopLeft(
        find.text(messages.dailyOsNextReconcileDecideOverline),
      );

      // Side by side: the decide column starts to the right of the heard
      // column and the two overlines share roughly the same vertical line.
      expect(decide.dx, greaterThan(heard.dx));
      expect((decide.dy - heard.dy).abs(), lessThan(1));
    });

    testWidgets(
      'Heard column shows the thinking shader while the parse wake runs, '
      'with the pending column already populated',
      (tester) async {
        hSetWideSurface(tester);
        final params = ReconcileParams(
          captureId: const CaptureId('cap_parsing'),
          dayDate: DateTime(2026, 5, 25),
        );
        final data = hReconcileData(
          pending: const [
            PendingItem(
              taskId: 't_pending',
              title: hKPendingTitle,
              category: hCategory,
              reason: PendingItemReason.overdue,
              overdueByDays: 2,
            ),
          ],
        );

        await tester.pumpWidget(
          hWrap(
            ReconcileModalContent(params: params, data: data),
            overrides: [dayAgentProvider.overrideWithValue(hFastAgent())],
            agentRunning: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Pending decisions render immediately while parsing continues.
        expect(find.text(hKPendingTitle), findsOneWidget);
        // The Heard column surfaces the AI thinking shader (parse in flight).
        expect(
          find.byKey(DayPlanningThinkingShader.indicatorKey),
          findsOneWidget,
        );
      },
    );

    testWidgets('Heard column hides the shader once the agent is idle', (
      tester,
    ) async {
      hSetWideSurface(tester);
      final params = ReconcileParams(
        captureId: const CaptureId('cap_idle'),
        dayDate: DateTime(2026, 5, 25),
      );
      final data = hReconcileData(
        pending: const [
          PendingItem(
            taskId: 't_pending',
            title: hKPendingTitle,
            category: hCategory,
            reason: PendingItemReason.overdue,
            overdueByDays: 2,
          ),
        ],
      );

      // hWrap defaults agentIsRunningProvider to false.
      await tester.pumpWidget(
        hWrap(
          ReconcileModalContent(params: params, data: data),
          overrides: [dayAgentProvider.overrideWithValue(hFastAgent())],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(hKPendingTitle), findsOneWidget);
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsNothing,
      );
    });
  });
}
