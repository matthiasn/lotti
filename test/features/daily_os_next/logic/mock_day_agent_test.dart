import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';

void main() {
  group('MockDayAgent', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    test('submitCapture returns a fresh, monotonic capture id', () async {
      final first = await agent.submitCapture(
        transcript: 'hello world',
        capturedAt: DateTime(2026, 5, 25, 9),
      );
      final second = await agent.submitCapture(
        transcript: 'another one',
        capturedAt: DateTime(2026, 5, 25, 9, 1),
      );
      expect(first, isNot(equals(second)));
      expect(first.value, contains('mock_capture_'));
    });

    test('parseCaptureToItems exposes all four scripted variants', () async {
      final items = await agent.parseCaptureToItems(const CaptureId('x'));
      expect(items, hasLength(4));
      final kinds = items.map((i) => i.kind).toList();
      expect(kinds, contains(ParsedItemKind.matched));
      expect(kinds, contains(ParsedItemKind.newTask));
      expect(kinds, contains(ParsedItemKind.update));
      // The low-confidence variant should be present so the UI can
      // exercise the warning tag.
      expect(
        items.any((i) => i.confidence == ParsedItemConfidence.low),
        isTrue,
      );
      // A time-anchor variant should be present so the UI can render
      // the warning-tinted constraint chip.
      expect(items.any((i) => i.timeAnchor != null), isTrue);
    });

    test('breakCaptureLink downgrades a matched item to a NEW card', () async {
      final initial = await agent.parseCaptureToItems(const CaptureId('x'));
      final matched = initial.firstWhere(
        (i) => i.kind == ParsedItemKind.matched,
      );
      expect(matched.matchedTaskId, isNotNull);

      final updated = await agent.breakCaptureLink(matched.id);
      expect(updated.kind, ParsedItemKind.newTask);
      expect(updated.matchedTaskId, isNull);
      expect(updated.title, isNotEmpty);

      final after = await agent.parseCaptureToItems(const CaptureId('x'));
      final sameId = after.firstWhere((i) => i.id == matched.id);
      expect(sameId.kind, ParsedItemKind.newTask);
    });

    test('surfacePendingDecisions exposes the three core reasons', () async {
      final items = await agent.surfacePendingDecisions();
      expect(items, hasLength(3));
      final reasons = items.map((i) => i.reason).toSet();
      expect(reasons, contains(PendingItemReason.overdue));
      expect(reasons, contains(PendingItemReason.inProgress));
      expect(reasons, contains(PendingItemReason.recurringMissed));

      final overdue = items.firstWhere(
        (i) => i.reason == PendingItemReason.overdue,
      );
      expect(overdue.overdueByDays, isNotNull);

      final inProgress = items.firstWhere(
        (i) => i.reason == PendingItemReason.inProgress,
      );
      expect(inProgress.sessionCount, isNotNull);
    });

    test(
      'applyTriage carries the action through and populates deferredTo only '
      'for defer',
      () async {
        final today = await agent.applyTriage(
          taskId: 't_1',
          action: TriageAction.today,
        );
        expect(today.action, TriageAction.today);
        expect(today.deferredTo, isNull);

        final deferred = await agent.applyTriage(
          taskId: 't_2',
          action: TriageAction.defer,
        );
        expect(deferred.action, TriageAction.defer);
        expect(deferred.deferredTo, isNotNull);
        // Defaults to the next day at the injected clock.
        expect(deferred.deferredTo, DateTime(2026, 5, 26, 9));

        final explicit = await agent.applyTriage(
          taskId: 't_3',
          action: TriageAction.defer,
          deferTo: DateTime(2026, 6),
        );
        expect(explicit.deferredTo, DateTime(2026, 6));
      },
    );

    test(
      'DayAgentInterface is implementable; equality on value objects works',
      () {
        // Compile-time check — Mock is an implementation.
        const DayAgentInterface i = _NullAgent();
        expect(i, isA<DayAgentInterface>());
        expect(const CaptureId('x'), const CaptureId('x'));
        expect(
          const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
          const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
        );
      },
    );
  });
}

class _NullAgent implements DayAgentInterface {
  const _NullAgent();

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
  }) async => const CaptureId('null');

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);
}
