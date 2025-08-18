//ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/task_summary_refresh_status_listener.dart';

// Test provider to get access to Ref
final testTaskSummaryRefreshStatusListenerProvider =
    Provider<TaskSummaryRefreshStatusListener>((ref) {
  return TaskSummaryRefreshStatusListener(ref);
});

class MockInferenceStatusController extends InferenceStatusController {
  MockInferenceStatusController(this._status);

  InferenceStatus _status;

  void updateStatus(InferenceStatus newStatus) {
    _status = newStatus;
    // Notify listeners by updating state
    state = newStatus;
  }

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    return _status;
  }
}

void main() {
  late ProviderContainer container;
  late TaskSummaryRefreshStatusListener listener;

  setUp(() {
    container = ProviderContainer();
    listener = container.read(testTaskSummaryRefreshStatusListenerProvider);
  });

  tearDown(() {
    listener.dispose();
    container.dispose();
  });

  group('TaskSummaryRefreshStatusListener', () {
    test('should set up listener successfully', () {
      final callbackCalls = <String>[];

      final result = listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: callbackCalls.add,
      );

      expect(result, isTrue);
      expect(listener.hasListener('task-1'), isTrue);
      expect(listener.activeListenerCount, equals(1));
      expect(listener.activeTaskIds, contains('task-1'));
    });

    test('should not create duplicate listeners', () {
      final callbackCalls = <String>[];

      // First setup
      final result1 = listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: callbackCalls.add,
      );

      // Second setup for same task
      final result2 = listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: callbackCalls.add,
      );

      expect(result1, isTrue);
      expect(result2, isFalse);
      expect(listener.activeListenerCount, equals(1));
    });

    test('should manage multiple listeners independently', () {
      final task1Calls = <String>[];
      final task2Calls = <String>[];
      final task3Calls = <String>[];

      listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: task1Calls.add,
      );
      listener.setupListener(
        taskId: 'task-2',
        onInferenceComplete: task2Calls.add,
      );
      listener.setupListener(
        taskId: 'task-3',
        onInferenceComplete: task3Calls.add,
      );

      expect(listener.activeListenerCount, equals(3));
      expect(
          listener.activeTaskIds, containsAll(['task-1', 'task-2', 'task-3']));
    });

    test('should remove listener successfully', () {
      final callbackCalls = <String>[];

      listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: callbackCalls.add,
      );

      expect(listener.hasListener('task-1'), isTrue);

      final removed = listener.removeListener('task-1');

      expect(removed, isTrue);
      expect(listener.hasListener('task-1'), isFalse);
      expect(listener.activeListenerCount, equals(0));
    });

    test('should return false when removing non-existent listener', () {
      final removed = listener.removeListener('non-existent-task');

      expect(removed, isFalse);
    });

    test('should dispose all listeners', () {
      final callbackCalls = <String>[];

      // Set up multiple listeners
      listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: callbackCalls.add,
      );
      listener.setupListener(
        taskId: 'task-2',
        onInferenceComplete: callbackCalls.add,
      );
      listener.setupListener(
        taskId: 'task-3',
        onInferenceComplete: callbackCalls.add,
      );

      expect(listener.activeListenerCount, equals(3));

      listener.dispose();

      expect(listener.activeListenerCount, equals(0));
      expect(listener.activeTaskIds, isEmpty);
    });

    test('should trigger callback on status change from running to idle',
        () async {
      final callbackCalls = <String>[];

      // Create a controller that we can manipulate
      final mockController =
          MockInferenceStatusController(InferenceStatus.running);

      // Override the provider for our test task
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => mockController),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listener
      listener.setupListener(
        taskId: 'test-task',
        onInferenceComplete: callbackCalls.add,
      );

      // Change status from running to idle
      mockController.updateStatus(InferenceStatus.idle);

      // Give time for the listener to react
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify callback was called
      expect(callbackCalls, contains('test-task'));

      // Verify listener was automatically removed
      expect(listener.hasListener('test-task'), isFalse);
    });

    test('should trigger callback on status change from running to error',
        () async {
      final callbackCalls = <String>[];

      // Create a controller that we can manipulate
      final mockController =
          MockInferenceStatusController(InferenceStatus.running);

      // Override the provider for our test task
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => mockController),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listener
      listener.setupListener(
        taskId: 'test-task',
        onInferenceComplete: callbackCalls.add,
      );

      // Change status from running to error
      mockController.updateStatus(InferenceStatus.error);

      // Give time for the listener to react
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify callback was called
      expect(callbackCalls, contains('test-task'));

      // Verify listener was automatically removed
      expect(listener.hasListener('test-task'), isFalse);
    });

    test('should not trigger callback on other status changes', () async {
      final callbackCalls = <String>[];

      // Create a controller that starts idle
      final mockController =
          MockInferenceStatusController(InferenceStatus.idle);

      // Override the provider for our test task
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => mockController),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listener
      listener.setupListener(
        taskId: 'test-task',
        onInferenceComplete: callbackCalls.add,
      );

      // Change status from idle to running (not what we're listening for)
      mockController.updateStatus(InferenceStatus.running);

      // Give time for the listener to react
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify callback was NOT called
      expect(callbackCalls, isEmpty);

      // Verify listener is still active
      expect(listener.hasListener('test-task'), isTrue);

      // Now change from running to running (no change)
      mockController.updateStatus(InferenceStatus.running);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Still no callback
      expect(callbackCalls, isEmpty);
      expect(listener.hasListener('test-task'), isTrue);

      // Change from running to idle (should trigger)
      mockController.updateStatus(InferenceStatus.idle);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Now callback should be called
      expect(callbackCalls, contains('test-task'));
      expect(listener.hasListener('test-task'), isFalse);
    });

    test('should handle multiple status transitions correctly', () async {
      final callbackCalls = <String>[];

      // Create controllers for multiple tasks
      final controller1 =
          MockInferenceStatusController(InferenceStatus.running);
      final controller2 = MockInferenceStatusController(InferenceStatus.idle);
      final controller3 =
          MockInferenceStatusController(InferenceStatus.running);

      // Override the providers
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'task-1',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => controller1),
          inferenceStatusControllerProvider(
            id: 'task-2',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => controller2),
          inferenceStatusControllerProvider(
            id: 'task-3',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => controller3),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listeners
      listener.setupListener(
        taskId: 'task-1',
        onInferenceComplete: (taskId) => callbackCalls.add('task-1'),
      );
      listener.setupListener(
        taskId: 'task-2',
        onInferenceComplete: (taskId) => callbackCalls.add('task-2'),
      );
      listener.setupListener(
        taskId: 'task-3',
        onInferenceComplete: (taskId) => callbackCalls.add('task-3'),
      );

      // Task 1: running -> idle (should trigger)
      controller1.updateStatus(InferenceStatus.idle);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Task 2: idle -> running (should not trigger)
      controller2.updateStatus(InferenceStatus.running);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Task 3: running -> error (should trigger)
      controller3.updateStatus(InferenceStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify callbacks
      expect(callbackCalls, containsAll(['task-1', 'task-3']));
      expect(callbackCalls, isNot(contains('task-2')));

      // Verify listeners were cleaned up for task-1 and task-3
      expect(listener.hasListener('task-1'), isFalse);
      expect(listener.hasListener('task-2'), isTrue);
      expect(listener.hasListener('task-3'), isFalse);
    });

    test('should handle rapid status changes correctly', () async {
      final callbackCalls = <String>[];

      // Create a controller that we can manipulate
      final mockController =
          MockInferenceStatusController(InferenceStatus.idle);

      // Override the provider for our test task
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => mockController),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listener
      listener.setupListener(
        taskId: 'test-task',
        onInferenceComplete: callbackCalls.add,
      );

      // Rapid status changes
      mockController.updateStatus(InferenceStatus.running);
      mockController.updateStatus(InferenceStatus.idle);
      mockController.updateStatus(InferenceStatus.running);
      mockController.updateStatus(InferenceStatus.error);

      // Give time for the listener to react
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should have triggered once (first running->idle transition)
      expect(callbackCalls.length, equals(1));
      expect(callbackCalls.first, equals('test-task'));

      // Listener should be removed after first trigger
      expect(listener.hasListener('test-task'), isFalse);
    });

    test('should properly clean up on dispose with active listeners', () async {
      final callbackCalls = <String>[];

      // Create a controller
      final mockController =
          MockInferenceStatusController(InferenceStatus.running);

      // Override the provider
      container = ProviderContainer(
        overrides: [
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => mockController),
        ],
      );

      // Create listener with the container
      listener = container.read(testTaskSummaryRefreshStatusListenerProvider);

      // Set up listener
      listener.setupListener(
        taskId: 'test-task',
        onInferenceComplete: callbackCalls.add,
      );

      expect(listener.activeListenerCount, equals(1));

      // Dispose without triggering callback
      listener.dispose();

      expect(listener.activeListenerCount, equals(0));

      // Change status after dispose (should not trigger callback)
      mockController.updateStatus(InferenceStatus.idle);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify no callback was triggered
      expect(callbackCalls, isEmpty);
    });
  });
}
