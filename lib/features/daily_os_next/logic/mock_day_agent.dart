import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Scripted [DayAgentInterface] for the Capture + Reconcile preview.
///
/// Replaces the real `DayAgentWorkflow` until the agentic backend
/// described in `docs/implementation_plans/2026-05-25_day_agent_layer.md`
/// ships. Returns a stable, demoable shape so the UI work can land
/// independently. Every call carries an artificial latency so the
/// loading states render in real conditions.
///
/// The mock keeps its own in-memory "broken link" tracker so the
/// `breakCaptureLink` action visibly mutates the returned parsed
/// items across calls.
class MockDayAgent implements DayAgentInterface {
  MockDayAgent({
    this.parseLatency = const Duration(milliseconds: 220),
    this.pendingLatency = const Duration(milliseconds: 180),
    this.triageLatency = const Duration(milliseconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration parseLatency;
  final Duration pendingLatency;
  final Duration triageLatency;
  final DateTime Function() _clock;

  static const _work = DayAgentCategory(
    id: 'cat_work',
    name: 'Work',
    colorHex: '5ED4B7',
  );
  static const _health = DayAgentCategory(
    id: 'cat_health',
    name: 'Health',
    colorHex: '7AB889',
  );
  static const _meals = DayAgentCategory(
    id: 'cat_meals',
    name: 'Meals',
    colorHex: '4AB6E8',
  );
  static const _study = DayAgentCategory(
    id: 'cat_study',
    name: 'Study',
    colorHex: 'FBA336',
  );

  int _captureSeq = 0;

  /// Items that have had their link broken in this session — keyed
  /// by parsed-item id. Subsequent `parseCaptureToItems` calls
  /// rebuild the same list with those entries downgraded to NEW.
  final Set<String> _brokenLinks = <String>{};

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
  }) async {
    await Future<void>.delayed(parseLatency);
    _captureSeq++;
    return CaptureId('mock_capture_$_captureSeq');
  }

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    await Future<void>.delayed(parseLatency);
    const items = <ParsedItem>[
      ParsedItem(
        id: 'p_deck_review',
        kind: ParsedItemKind.matched,
        title: 'Send the leadership deck to Sarah',
        category: _work,
        confidence: ParsedItemConfidence.high,
        spokenPhrase: 'send the deck to Sarah',
        matchedTaskId: 't_deck_review',
        matchedTaskTitle: 'Deck review — Q2 leadership update',
        matchedTaskState: 'In progress · 2 sessions',
        estimateMinutes: 60,
      ),
      ParsedItem(
        id: 'p_invoices',
        kind: ParsedItemKind.newTask,
        title: 'Review outstanding invoices',
        category: _work,
        confidence: ParsedItemConfidence.high,
        estimateMinutes: 45,
        timeAnchor: 'before 11am',
      ),
      ParsedItem(
        id: 'p_call_mom',
        kind: ParsedItemKind.newTask,
        title: 'Call mom re: Sunday',
        category: _meals,
        confidence: ParsedItemConfidence.low,
        estimateMinutes: 15,
      ),
      ParsedItem(
        id: 'p_run_done',
        kind: ParsedItemKind.update,
        title: 'Morning run',
        category: _health,
        confidence: ParsedItemConfidence.high,
        spokenPhrase: 'did my run already',
        matchedTaskId: 't_morning_run',
        matchedTaskTitle: 'Morning run · 5km',
        matchedTaskState: 'Recurring · daily',
        proposedUpdate: 'Mark done for today',
      ),
    ];

    if (_brokenLinks.isEmpty) return items;
    return [
      for (final item in items)
        if (_brokenLinks.contains(item.id))
          ParsedItem(
            id: item.id,
            kind: ParsedItemKind.newTask,
            title: item.matchedTaskTitle ?? item.title,
            category: item.category,
            confidence: item.confidence,
            estimateMinutes: item.estimateMinutes,
            timeAnchor: item.timeAnchor,
          )
        else
          item,
    ];
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async {
    await Future<void>.delayed(pendingLatency);
    return const [
      PendingItem(
        taskId: 't_onboarding_doc',
        title: 'Finish the Onboarding doc',
        category: _work,
        reason: PendingItemReason.inProgress,
        note: 'Started Wednesday, 40m in',
        sessionCount: 1,
      ),
      PendingItem(
        taskId: 't_dentist',
        title: 'Reschedule dentist',
        category: _health,
        reason: PendingItemReason.overdue,
        note: 'Was due Monday',
        overdueByDays: 3,
      ),
      PendingItem(
        taskId: 't_dnd_book',
        title: 'Read 30 pages',
        category: _study,
        reason: PendingItemReason.recurringMissed,
        note: 'Last skipped Thursday',
      ),
    ];
  }

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async {
    await Future<void>.delayed(triageLatency);
    _brokenLinks.add(parsedItemId);
    final list = await parseCaptureToItems(const CaptureId('mock_capture'));
    return list.firstWhere(
      (item) => item.id == parsedItemId,
      orElse: () => throw StateError(
        'Mock day agent: parsed item $parsedItemId is no longer in the '
        'scripted list. This should not happen in tests.',
      ),
    );
  }

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async {
    await Future<void>.delayed(triageLatency);
    return TriageResult(
      taskId: taskId,
      action: action,
      deferredTo: action == TriageAction.defer
          ? (deferTo ?? _clock().add(const Duration(days: 1)))
          : null,
    );
  }
}
