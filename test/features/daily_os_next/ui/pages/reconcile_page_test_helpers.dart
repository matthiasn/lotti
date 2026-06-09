import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';

import '../../../../widget_test_utils.dart';

Widget hWrap(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(1400, 900)),
  bool agentRunning = false,
}) {
  return ProviderScope(
    overrides: [
      // Single agent-running override (Riverpod forbids overriding a family
      // twice). Defaults to idle so the Heard column's parsing shader stays
      // off; pass agentRunning: true for the parse-in-flight case.
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(agentRunning),
      ),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: mediaQueryData,
    ),
  );
}

void hSetWideSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void hSetPhoneSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = phoneMediaQueryData.size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

MockDayAgent hFastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
);

class EmptyParsedAgent extends MockDayAgent {
  EmptyParsedAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];
}

class ThrowingReconcileAgent extends MockDayAgent {
  ThrowingReconcileAgent()
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

class RefreshBlockingAgent extends MockDayAgent {
  RefreshBlockingAgent()
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

/// Parse returns nothing until [ready] flips true (simulating the
/// capture-submitted parse wake completing), then surfaces one item.
class LateParseAgent extends MockDayAgent {
  LateParseAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  bool ready = false;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    if (!ready) return const [];
    return [hParsed('p_late', kind: ParsedItemKind.newTask, title: 'Drafted')];
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];
}

/// Shared category for hand-built fixtures — the colour is irrelevant to
/// the selection logic and layout under test.
const hCategory = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '5ED4B7',
);

/// Builds a [ParsedItem] with just the fields the selection logic reads.
ParsedItem hParsed(
  String id, {
  required ParsedItemKind kind,
  String? matchedTaskId,
  String title = 'Parsed item',
}) {
  return ParsedItem(
    id: id,
    kind: kind,
    title: title,
    category: hCategory,
    confidence: ParsedItemConfidence.high,
    matchedTaskId: matchedTaskId,
  );
}

/// Builds a [TriageResult] for the given action.
TriageResult hTriage(String taskId, TriageAction action) =>
    TriageResult(taskId: taskId, action: action);

ReconcileData hReconcileData({
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

const hKHeardTitle = 'Review the deck';
const hKPendingTitle = 'Pay invoices';

/// Pumps a [ReconcileModalContent] at the given surface size with one parsed
/// and one pending item so both columns carry visible content. The decide
/// column is a [ConsumerWidget] that reads the reconcile controller for triage
/// decisions, so a [ProviderScope] with a fast in-memory agent is supplied.
Future<void> hPumpModal(
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
  final data = hReconcileData(
    parsed: [
      hParsed(
        'p_heard',
        kind: ParsedItemKind.newTask,
        title: hKHeardTitle,
      ),
    ],
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
      mediaQueryData: MediaQueryData(size: Size(width, height)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Agent whose parse step surfaces a matched item that has no resolved
/// task id, exercising the capture-item fallback in `_draftingSelections`.
class MatchedWithoutTaskIdAgent extends MockDayAgent {
  MatchedWithoutTaskIdAgent()
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
class BreakLinkRecordingAgent extends MockDayAgent {
  BreakLinkRecordingAgent()
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
class SelectionSpec {
  const SelectionSpec({
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
    category: hCategory,
    confidence: ParsedItemConfidence.high,
    matchedTaskId: matchedTaskId,
  );

  String? get triageTaskId => hasTriage ? 't_$triageSeed' : null;

  TriageResult? get triageResult => hasTriage
      ? TriageResult(taskId: triageTaskId!, action: triageAction)
      : null;

  @override
  String toString() =>
      'SelectionSpec(kind: $kind, '
      'matched: $matchedTaskId, triage: $triageTaskId/$triageAction)';
}

extension AnySelectionSpecs on glados.Any {
  glados.Generator<ParsedItemKind> get parsedItemKind =>
      choose(ParsedItemKind.values);

  glados.Generator<TriageAction> get triageAction =>
      choose(TriageAction.values);

  glados.Generator<SelectionSpec> get selectionSpec => combine6(
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
    ) => SelectionSpec(
      kind: kind,
      hasMatchedTaskId: hasMatchedTaskId,
      matchedTaskSeed: matchedTaskSeed,
      hasTriage: hasTriage,
      triageSeed: triageSeed,
      triageAction: triageAction,
    ),
  );

  glados.Generator<List<SelectionSpec>> get selectionSpecs =>
      list(selectionSpec);
}
