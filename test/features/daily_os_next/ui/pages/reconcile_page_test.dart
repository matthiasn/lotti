import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/parsed_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(1400, 900)),
}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: mediaQueryData,
    ),
  );
}

void _setWideSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void _setPhoneSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = phoneMediaQueryData.size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
);

class _EmptyParsedAgent extends MockDayAgent {
  _EmptyParsedAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];
}

class _ThrowingReconcileAgent extends MockDayAgent {
  _ThrowingReconcileAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    throw StateError('reconcile unavailable');
  }
}

class _RefreshBlockingAgent extends MockDayAgent {
  _RefreshBlockingAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  final pendingParsedRefresh = Completer<List<ParsedItem>>();
  int parseCalls = 0;
  int pendingCalls = 0;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) {
    parseCalls += 1;
    if (parseCalls == 1) return super.parseCaptureToItems(id);
    return pendingParsedRefresh.future;
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({DateTime? forDate}) {
    pendingCalls += 1;
    if (pendingCalls == 1) {
      return super.surfacePendingDecisions(forDate: forDate);
    }
    return Future.value(const <PendingItem>[]);
  }
}

/// Shared category for hand-built fixtures — the colour is irrelevant to
/// the selection logic and layout under test.
const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '5ED4B7',
);

/// Builds a [ParsedItem] with just the fields the selection logic reads.
ParsedItem _parsed(
  String id, {
  required ParsedItemKind kind,
  String? matchedTaskId,
  String title = 'Parsed item',
}) {
  return ParsedItem(
    id: id,
    kind: kind,
    title: title,
    category: _category,
    confidence: ParsedItemConfidence.high,
    matchedTaskId: matchedTaskId,
  );
}

/// Builds a [TriageResult] for the given action.
TriageResult _triage(String taskId, TriageAction action) =>
    TriageResult(taskId: taskId, action: action);

ReconcileData _reconcileData({
  List<ParsedItem> parsed = const [],
  List<PendingItem> pending = const [],
  Map<String, TriageResult> triageDecisions = const {},
}) {
  return ReconcileData(
    parsed: parsed,
    pending: pending,
    triageDecisions: triageDecisions,
  );
}

void main() {
  group('ReconcilePage', () {
    testWidgets('renders parsed and pending cards from the day agent', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Scripted mock returns 4 parsed + 3 pending items.
      expect(find.byType(ParsedCard), findsNWidgets(4));
      expect(find.byType(PendingCard), findsNWidgets(3));
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
    });

    testWidgets('keeps parsed and pending cards during provider refreshes', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _RefreshBlockingAgent();
      addTearDown(() {
        if (!agent.pendingParsedRefresh.isCompleted) {
          agent.pendingParsedRefresh.complete(const []);
        }
      });
      final params = ReconcileParams(
        captureId: const CaptureId('cap_x'),
        dayDate: DateTime(2026, 5, 25),
      );

      await tester.pumpWidget(
        _wrap(
          ReconcilePage(captureId: params.captureId, dayDate: params.dayDate),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ParsedCard), findsNWidgets(4));
      expect(find.byType(PendingCard), findsNWidgets(3));

      ProviderScope.containerOf(
        tester.element(find.byType(ReconcilePage)),
      ).invalidate(reconcileControllerProvider(params));
      await tester.pump();

      expect(find.byType(ParsedCard), findsNWidgets(4));
      expect(find.byType(PendingCard), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows both column headers with their item counts', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final context = tester.element(find.byType(ReconcilePage));
      final messages = context.messages;
      expect(
        find.text(messages.dailyOsNextReconcileHeardOverline),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextReconcileDecideOverline),
        findsOneWidget,
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('explains the empty heard column while parsing catches up', (
      tester,
    ) async {
      _setWideSurface(tester);
      final agent = _EmptyParsedAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final context = tester.element(find.byType(ReconcilePage));
      expect(
        find.text(context.messages.dailyOsNextReconcileHeardEmpty),
        findsOneWidget,
      );
      expect(find.byType(ParsedCard), findsNothing);
      expect(find.byType(PendingCard), findsNWidgets(3));
    });

    testWidgets('renders localized error copy when reconcile loading fails', (
      tester,
    ) async {
      _setWideSurface(tester);
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [
            dayAgentProvider.overrideWithValue(_ThrowingReconcileAgent()),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final messages = tester.element(find.byType(ReconcilePage)).messages;
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
      expect(find.textContaining('reconcile unavailable'), findsNothing);
    });

    testWidgets(
      'triaging a pending card replaces the action row with a confirmation '
      'pill and dims the card',
      (tester) async {
        _setWideSurface(tester);
        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final context = tester.element(find.byType(ReconcilePage));
        final messages = context.messages;
        final todayButton = find
            .descendant(
              of: find.byType(PendingCard).first,
              matching: find.text(messages.dailyOsNextTriageToday),
            )
            .first;
        await tester.tap(todayButton);
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text(messages.dailyOsNextTriageConfirmToday),
          findsOneWidget,
        );
        // The triage row for the first card collapsed — there are
        // fewer Today buttons across the surface now.
        expect(
          find.text(messages.dailyOsNextTriageToday),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('mobile footer clears the bottom navigation hit area', (
      tester,
    ) async {
      _setPhoneSurface(tester);
      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          const ReconcilePage(captureId: CaptureId('cap_x')),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final context = tester.element(find.byType(ReconcilePage));
      final messages = context.messages;
      final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
        context,
      );
      final ctaBottom = tester
          .getBottomLeft(find.text(messages.dailyOsNextReconcileBuildDayCta))
          .dy;

      expect(
        ctaBottom,
        lessThan(phoneMediaQueryData.size.height - bottomNavHeight),
      );
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets(
      'AppBar back button pops the navigator (re-record from header)',
      (tester) async {
        _setWideSurface(tester);
        final agent = _fastAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReconcilePage(
                          captureId: CaptureId('cap_x'),
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(ReconcilePage), findsNothing);
      },
    );

    testWidgets(
      'tapping "Draft my day" keeps task ids and new capture items separate',
      (tester) async {
        _setWideSurface(tester);
        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ReconcilePage)).messages;
        final cta = find.text(messages.dailyOsNextReconcileBuildDayCta);
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DraftingPage), findsOneWidget);
        final pushed = tester.widget<DraftingPage>(find.byType(DraftingPage));
        expect(pushed.captureId, const CaptureId('cap_x'));
        expect(pushed.returnToRootOnReady, isTrue);
        expect(
          pushed.decidedTaskIds,
          containsAll(['t_deck_review', 't_morning_run']),
        );
        expect(pushed.decidedTaskIds, isNot(contains('p_invoices')));
        expect(pushed.decidedTaskIds, isNot(contains('p_call_mom')));
        expect(
          pushed.decidedCaptureItemIds,
          containsAll(['p_invoices', 'p_call_mom']),
        );
      },
    );

    testWidgets(
      'a matched item without a task id is carried as a capture item',
      (tester) async {
        _setWideSurface(tester);
        final agent = _MatchedWithoutTaskIdAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ReconcilePage)).messages;
        final cta = find.text(messages.dailyOsNextReconcileBuildDayCta);
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        final pushed = tester.widget<DraftingPage>(find.byType(DraftingPage));
        expect(pushed.decidedCaptureItemIds, contains('p_unlinked_match'));
        expect(pushed.decidedTaskIds, isNot(contains('p_unlinked_match')));
      },
    );

    testWidgets(
      'triaging a pending item to "today" includes it in decidedTaskIds',
      (tester) async {
        _setWideSurface(tester);
        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ReconcilePage)).messages;
        final todayButton = find
            .descendant(
              of: find.byType(PendingCard).first,
              matching: find.text(messages.dailyOsNextTriageToday),
            )
            .first;
        await tester.tap(todayButton);
        await tester.pump(const Duration(milliseconds: 200));

        // Now trigger draft → push DraftingPage with the triaged id
        // included.
        final cta = find.text(messages.dailyOsNextReconcileBuildDayCta);
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DraftingPage), findsOneWidget);
        final pushed = tester.widget<DraftingPage>(find.byType(DraftingPage));
        expect(pushed.decidedTaskIds, contains('t_onboarding_doc'));
        expect(
          pushed.decidedCaptureItemIds,
          containsAll(['p_invoices', 'p_call_mom']),
        );
      },
    );

    testWidgets(
      'tapping a ParsedCard break-link icon forwards the parsed item id',
      (tester) async {
        _setWideSurface(tester);
        final agent = _BreakLinkRecordingAgent();
        await tester.pumpWidget(
          _wrap(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // The break-link control is an Inkwell wrapping a close icon
        // inside a Tooltip — match the tooltip and tap.
        final messages = tester.element(find.byType(ReconcilePage)).messages;
        final tooltip = find
            .byTooltip(messages.dailyOsNextParsedCardBreakLinkTooltip)
            .first;
        await tester.ensureVisible(tooltip);
        await tester.tap(tooltip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(agent.brokenItemIds, isNotEmpty);
      },
    );

    testWidgets('narrow layout (< 720) stacks heard + decide vertically', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(600, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final agent = _fastAgent();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dayAgentProvider.overrideWithValue(agent)],
          child: makeTestableWidget2(
            const ReconcilePage(captureId: CaptureId('cap_x')),
            mediaQueryData: const MediaQueryData(size: Size(600, 1400)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Both sections rendered, just stacked.
      expect(find.byType(ParsedCard), findsNWidgets(4));
      expect(find.byType(PendingCard), findsNWidgets(3));
    });
  });

  group('reconcileDraftingSelections', () {
    test('matched item with a task id contributes its task id', () {
      final result = reconcileDraftingSelections(
        _reconcileData(
          parsed: [
            _parsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
          ],
        ),
      );

      expect(result.taskIds, equals(['t1']));
      expect(result.captureItemIds, isEmpty);
    });

    test('update item with a task id contributes its task id', () {
      final result = reconcileDraftingSelections(
        _reconcileData(
          parsed: [
            _parsed('p1', kind: ParsedItemKind.update, matchedTaskId: 't1'),
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
          _reconcileData(
            parsed: [_parsed('p1', kind: ParsedItemKind.matched)],
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
          _reconcileData(
            parsed: [_parsed('p1', kind: ParsedItemKind.update)],
          ),
        );

        expect(result.taskIds, isEmpty);
        expect(result.captureItemIds, equals(['p1']));
      },
    );

    test('newTask item always contributes its capture item id', () {
      final result = reconcileDraftingSelections(
        _reconcileData(
          parsed: [
            // A matchedTaskId is present but irrelevant for a newTask kind,
            // which is never task-bound.
            _parsed('p1', kind: ParsedItemKind.newTask, matchedTaskId: 't1'),
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
          _reconcileData(
            triageDecisions: {'t1': _triage('t1', TriageAction.today)},
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
          _reconcileData(
            triageDecisions: {'t1': _triage('t1', TriageAction.doNow)},
          ),
        );

        expect(result.taskIds, equals(['t1']));
        expect(result.captureItemIds, isEmpty);
      },
    );

    test('triage decisions with non-selecting actions are excluded', () {
      final result = reconcileDraftingSelections(
        _reconcileData(
          triageDecisions: {
            't_defer': _triage('t_defer', TriageAction.defer),
            't_done': _triage('t_done', TriageAction.done),
            't_drop': _triage('t_drop', TriageAction.drop),
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
          _reconcileData(
            parsed: [
              _parsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
            ],
            triageDecisions: {'t1': _triage('t1', TriageAction.today)},
          ),
        );

        expect(result.taskIds, equals(['t1']));
        expect(result.captureItemIds, isEmpty);
      },
    );

    test('combines parsed and triage contributions across branches', () {
      final result = reconcileDraftingSelections(
        _reconcileData(
          parsed: [
            _parsed('p1', kind: ParsedItemKind.matched, matchedTaskId: 't1'),
            _parsed('p2', kind: ParsedItemKind.update, matchedTaskId: 't2'),
            _parsed('p3', kind: ParsedItemKind.matched), // null → capture
            _parsed('p4', kind: ParsedItemKind.newTask), // new → capture
          ],
          triageDecisions: {
            't_today': _triage('t_today', TriageAction.today),
            't_now': _triage('t_now', TriageAction.doNow),
            't_defer': _triage('t_defer', TriageAction.defer),
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
    glados.Glados<List<_SelectionSpec>>(
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
      final data = _reconcileData(
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
      await _pumpModal(tester, width: 500, height: 1200);

      final context = tester.element(find.byType(ReconcileModalContent));
      final messages = context.messages;

      // Column content rendered.
      expect(find.text(_kHeardTitle), findsOneWidget);
      expect(find.text(_kPendingTitle), findsOneWidget);

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
      await _pumpModal(tester, width: 1200, height: 900);

      final context = tester.element(find.byType(ReconcileModalContent));
      final messages = context.messages;

      expect(find.text(_kHeardTitle), findsOneWidget);
      expect(find.text(_kPendingTitle), findsOneWidget);

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
  });
}

const _kHeardTitle = 'Review the deck';
const _kPendingTitle = 'Pay invoices';

/// Pumps a [ReconcileModalContent] at the given surface size with one parsed
/// and one pending item so both columns carry visible content. The decide
/// column is a [ConsumerWidget] that reads the reconcile controller for triage
/// decisions, so a [ProviderScope] with a fast in-memory agent is supplied.
Future<void> _pumpModal(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final params = ReconcileParams(
    captureId: const CaptureId('cap_modal'),
    dayDate: DateTime(2026, 5, 25),
  );
  final data = _reconcileData(
    parsed: [
      _parsed(
        'p_heard',
        kind: ParsedItemKind.newTask,
        title: _kHeardTitle,
      ),
    ],
    pending: const [
      PendingItem(
        taskId: 't_pending',
        title: _kPendingTitle,
        category: _category,
        reason: PendingItemReason.overdue,
        overdueByDays: 2,
      ),
    ],
  );

  await tester.pumpWidget(
    _wrap(
      ReconcileModalContent(params: params, data: data),
      overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
      mediaQueryData: MediaQueryData(size: Size(width, height)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Agent whose parse step surfaces a matched item that has no resolved
/// task id, exercising the capture-item fallback in `_draftingSelections`.
class _MatchedWithoutTaskIdAgent extends MockDayAgent {
  _MatchedWithoutTaskIdAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [
    ParsedItem(
      id: 'p_unlinked_match',
      kind: ParsedItemKind.matched,
      title: 'Follow up with Sarah',
      category: DayAgentCategory(id: 'work', name: 'Work', colorHex: '5ED4B7'),
      confidence: ParsedItemConfidence.high,
    ),
  ];
}

/// Agent that records breakCaptureLink calls instead of throwing.
class _BreakLinkRecordingAgent extends MockDayAgent {
  _BreakLinkRecordingAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  final List<String> brokenItemIds = [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async {
    brokenItemIds.add(parsedItemId);
    // Return an updated parsed item — the controller treats it as the
    // new state for the row, with the matched-task link removed.
    return ParsedItem(
      id: parsedItemId,
      kind: ParsedItemKind.newTask,
      title: 'Broken link',
      category: const DayAgentCategory(
        id: 'cat',
        name: 'Work',
        colorHex: '5ED4B7',
      ),
      confidence: ParsedItemConfidence.high,
    );
  }
}

/// A single generated reconcile entry: one parsed item plus an optional triage
/// decision keyed on a generated task id. The parsed item's own id is assigned
/// from its list position ([parsedItemAt]) so parsed ids stay unique (as they
/// are in real captures), while matched-task ids and triage keys draw from a
/// tiny seed space so they collide across the list and exercise the de-dup path.
class _SelectionSpec {
  const _SelectionSpec({
    required this.kind,
    required this.hasMatchedTaskId,
    required this.matchedTaskSeed,
    required this.hasTriage,
    required this.triageSeed,
    required this.triageAction,
  });

  final ParsedItemKind kind;
  final bool hasMatchedTaskId;
  final int matchedTaskSeed;
  final bool hasTriage;
  final int triageSeed;
  final TriageAction triageAction;

  String? get matchedTaskId => hasMatchedTaskId ? 't_$matchedTaskSeed' : null;

  ParsedItem parsedItemAt(int index) => ParsedItem(
    id: 'p_$index',
    kind: kind,
    title: 'Parsed $index',
    category: _category,
    confidence: ParsedItemConfidence.high,
    matchedTaskId: matchedTaskId,
  );

  String? get triageTaskId => hasTriage ? 't_$triageSeed' : null;

  TriageResult? get triageResult => hasTriage
      ? TriageResult(taskId: triageTaskId!, action: triageAction)
      : null;

  @override
  String toString() =>
      '_SelectionSpec(kind: $kind, '
      'matched: $matchedTaskId, triage: $triageTaskId/$triageAction)';
}

extension _AnySelectionSpecs on glados.Any {
  glados.Generator<ParsedItemKind> get parsedItemKind =>
      choose(ParsedItemKind.values);

  glados.Generator<TriageAction> get triageAction =>
      choose(TriageAction.values);

  glados.Generator<_SelectionSpec> get selectionSpec => combine6(
    parsedItemKind,
    this.bool,
    // Small seed ranges so matched-task ids and triage task ids collide across
    // the list, exercising the Set-based de-duplication.
    intInRange(0, 4),
    this.bool,
    intInRange(0, 4),
    triageAction,
    (
      ParsedItemKind kind,
      bool hasMatchedTaskId,
      int matchedTaskSeed,
      bool hasTriage,
      int triageSeed,
      TriageAction triageAction,
    ) => _SelectionSpec(
      kind: kind,
      hasMatchedTaskId: hasMatchedTaskId,
      matchedTaskSeed: matchedTaskSeed,
      hasTriage: hasTriage,
      triageSeed: triageSeed,
      triageAction: triageAction,
    ),
  );

  glados.Generator<List<_SelectionSpec>> get selectionSpecs =>
      list(selectionSpec);
}
