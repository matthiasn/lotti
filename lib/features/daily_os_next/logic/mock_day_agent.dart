import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:meta/meta.dart';

part 'mock_day_agent_fixtures.dart';
part 'mock_day_agent_capture.dart';
part 'mock_day_agent_planning.dart';

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
abstract class _MockDayAgentBase implements DayAgentInterface {
  _MockDayAgentBase({
    this.parseLatency = const Duration(milliseconds: 220),
    this.pendingLatency = const Duration(milliseconds: 180),
    this.triageLatency = const Duration(milliseconds: 120),
    this.draftLatency = const Duration(milliseconds: 400),
    this.summarizeLatency = const Duration(milliseconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration parseLatency;
  final Duration pendingLatency;
  final Duration triageLatency;
  final Duration draftLatency;
  final Duration summarizeLatency;
  final DateTime Function() _clock;

  int _captureSeq = 0;

  /// Items that have had their link broken in this session — keyed
  /// by parsed-item id. Subsequent `parseCaptureToItems` calls
  /// rebuild the same list with those entries downgraded to NEW.
  final Set<String> _brokenLinks = <String>{};

  int _diffSeq = 0;

  /// Roll the placed blocks up into one [AgendaItem] per task. Blocks
  /// without a taskId (buffers, calendar events) are not surfaced on
  /// the Agenda — that screen is intent-first.
  List<AgendaItem> _agendaFor(List<TimeBlock> blocks) {
    final byTask = <String, List<TimeBlock>>{};
    for (final block in blocks) {
      final id = block.taskId;
      if (id == null) continue;
      byTask.putIfAbsent(id, () => <TimeBlock>[]).add(block);
    }

    AgendaItem buildItem(String taskId, List<TimeBlock> linked) {
      final outcome = _scriptedOutcome(taskId);
      final estimate = linked.fold<int>(
        0,
        (acc, b) => acc + b.duration.inMinutes,
      );
      final state = linked.any((b) => b.state == TimeBlockState.inProgress)
          ? AgendaItemState.inProgress
          : AgendaItemState.open;
      return AgendaItem(
        id: 'agenda_$taskId',
        taskId: taskId,
        title: linked.first.title,
        category: linked.first.category,
        linkedBlockIds: linked.map((b) => b.id).toList(),
        outcome: outcome,
        totalEstimateMinutes: estimate,
        progress: _scriptedProgress(taskId),
        state: state,
      );
    }

    return byTask.entries
        .map((entry) => buildItem(entry.key, entry.value))
        .toList();
  }

  bool _matchesFilter(
    TaskCorpusItem item,
    TaskCorpusState state,
    String? categoryId,
    String? query,
  ) {
    if (state != TaskCorpusState.all && item.state != state) return false;
    if (categoryId != null && item.category.id != categoryId) return false;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      if (!item.title.toLowerCase().contains(q)) return false;
    }
    return true;
  }
}

class MockDayAgent extends _MockDayAgentBase
    with _MockDayAgentCapture, _MockDayAgentPlanning {
  MockDayAgent({
    super.parseLatency,
    super.pendingLatency,
    super.triageLatency,
    super.draftLatency,
    super.summarizeLatency,
    super.clock,
  });
}
