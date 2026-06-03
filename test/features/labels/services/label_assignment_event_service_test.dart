
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';

/// Generators for [LabelAssignmentEventService] property tests.
extension _AnyEvent on glados.Any {
  glados.Generator<String> get labelId => glados.any.letterOrDigits;

  glados.Generator<List<String>> get labelIds =>
      glados.ListAnys(this).listWithLengthInRange(0, 6, labelId);

  glados.Generator<LabelAssignmentEvent> get labelEvent =>
      glados.CombinableAny(this).combine2(
        labelId,
        labelIds,
        (taskId, assignedIds) => LabelAssignmentEvent(
          taskId: taskId,
          assignedIds: assignedIds,
        ),
      );
}

void main() {
  group('LabelAssignmentEventService — lifecycle', () {
    test('stream emits an event published before a listener attaches', () async {
      final service = LabelAssignmentEventService();
      addTearDown(service.dispose);

      final received = <LabelAssignmentEvent>[];
      final sub = service.stream.listen(received.add);
      addTearDown(sub.cancel);

      const event = LabelAssignmentEvent(
        taskId: 'task-1',
        assignedIds: <String>['label-a', 'label-b'],
      );
      service.publish(event);

      // Allow the broadcast stream to deliver the event.
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.taskId, 'task-1');
      expect(received.first.assignedIds, <String>['label-a', 'label-b']);
    });

    test('stream delivers events to multiple concurrent listeners', () async {
      final service = LabelAssignmentEventService();
      addTearDown(service.dispose);

      final received1 = <LabelAssignmentEvent>[];
      final received2 = <LabelAssignmentEvent>[];
      final sub1 = service.stream.listen(received1.add);
      final sub2 = service.stream.listen(received2.add);
      addTearDown(sub1.cancel);
      addTearDown(sub2.cancel);

      const eventA = LabelAssignmentEvent(
        taskId: 'task-a',
        assignedIds: <String>['x'],
      );
      const eventB = LabelAssignmentEvent(
        taskId: 'task-b',
        assignedIds: <String>['y'],
      );

      service
        ..publish(eventA)
        ..publish(eventB);

      await Future<void>.delayed(Duration.zero);

      expect(received1, hasLength(2));
      expect(received2, hasLength(2));
      expect(received1[0].taskId, 'task-a');
      expect(received1[1].taskId, 'task-b');
    });

    test('publish after dispose is silently ignored — no exception thrown',
        () async {
      final service = LabelAssignmentEventService();
      await service.dispose();

      // Must not throw.
      expect(
        () => service.publish(
          const LabelAssignmentEvent(
            taskId: 'after-close',
            assignedIds: <String>[],
          ),
        ),
        returnsNormally,
      );
    });

    test('stream emits no further events after dispose', () async {
      final service = LabelAssignmentEventService();

      final received = <LabelAssignmentEvent>[];
      final sub = service.stream.listen(received.add);
      addTearDown(sub.cancel);

      const before = LabelAssignmentEvent(
        taskId: 'before',
        assignedIds: <String>['label-1'],
      );
      service.publish(before);
      await Future<void>.delayed(Duration.zero);

      await service.dispose();

      // Publish after the controller is closed — isClosed guard must swallow it.
      service.publish(
        const LabelAssignmentEvent(
          taskId: 'after',
          assignedIds: <String>[],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.taskId, 'before');
    });

    test('source field defaults to "ai"', () {
      const event = LabelAssignmentEvent(
        taskId: 'task-x',
        assignedIds: <String>[],
      );
      expect(event.source, 'ai');
    });

    test('source field is preserved when explicitly set', () {
      const event = LabelAssignmentEvent(
        taskId: 'task-y',
        assignedIds: <String>[],
        source: 'user',
      );
      expect(event.source, 'user');
    });
  });

  group('LabelAssignmentEventService — properties', () {
    glados.Glados<LabelAssignmentEvent>(
      glados.any.labelEvent,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every published event is delivered to the listener with identical fields',
      (event) async {
        final service = LabelAssignmentEventService();
        final received = <LabelAssignmentEvent>[];
        final sub = service.stream.listen(received.add);

        service.publish(event);
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        await service.dispose();

        expect(received, hasLength(1));
        expect(received.first.taskId, event.taskId);
        expect(received.first.assignedIds, event.assignedIds);
        expect(received.first.source, event.source);
      },
      tags: 'glados',
    );
  });
}
