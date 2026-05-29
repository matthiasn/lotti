import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
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
