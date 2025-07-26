import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';

void main() {
  late ProviderContainer container;
  final subscriptions = <void Function()>[];

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    // Cancel all subscriptions first
    for (final unsubscribe in subscriptions) {
      unsubscribe();
    }
    subscriptions.clear();
    container.dispose();
  });

  group('InferenceStatusController', () {
    const testId = 'test-id';
    const testAiResponseType = AiResponseType.taskSummary;

    test('initial state is idle', () {
      final state = container.read(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ),
      );
      expect(state, equals(InferenceStatus.idle));
    });

    test('setStatus updates the state correctly', () {
      final controller = container.read(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ).notifier,
      )

        // Test setting to running
        ..setStatus(InferenceStatus.running);
      expect(
        container.read(
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: testAiResponseType,
          ),
        ),
        equals(InferenceStatus.running),
      );

      // Test setting to error
      controller.setStatus(InferenceStatus.error);
      expect(
        container.read(
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: testAiResponseType,
          ),
        ),
        equals(InferenceStatus.error),
      );

      // Test setting back to idle
      controller.setStatus(InferenceStatus.idle);
      expect(
        container.read(
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: testAiResponseType,
          ),
        ),
        equals(InferenceStatus.idle),
      );
    });

    test('different instances maintain separate states', () {
      const testId2 = 'test-id-2';
      const testAiResponseType2 = AiResponseType.taskSummary;

      final controller1 = container.read(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ).notifier,
      );

      final controller2 = container.read(
        inferenceStatusControllerProvider(
          id: testId2,
          aiResponseType: testAiResponseType2,
        ).notifier,
      );

      // Set different states for each controller
      controller1.setStatus(InferenceStatus.running);
      controller2.setStatus(InferenceStatus.error);

      // Verify states are independent
      expect(
        container.read(
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: testAiResponseType,
          ),
        ),
        equals(InferenceStatus.running),
      );

      expect(
        container.read(
          inferenceStatusControllerProvider(
            id: testId2,
            aiResponseType: testAiResponseType2,
          ),
        ),
        equals(InferenceStatus.error),
      );
    });

    test('state changes are properly notified', () {
      final states = <InferenceStatus>[];

      final unsubscribe = container.listen(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ),
        (previous, next) => states.add(next),
        fireImmediately: true,
      );
      subscriptions.add(unsubscribe.close);

      container.read(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ).notifier,
      )
        ..setStatus(InferenceStatus.running)
        ..setStatus(InferenceStatus.error)
        ..setStatus(InferenceStatus.idle);

      expect(
        states,
        equals([
          InferenceStatus.idle,
          InferenceStatus.running,
          InferenceStatus.error,
          InferenceStatus.idle,
        ]),
      );
    });
  });

  group('InferenceRunningController', () {
    const testId = 'test-id';
    const responseType1 = AiResponseType.taskSummary;
    // ignore: deprecated_member_use_from_same_package
    const responseType2 = AiResponseType.actionItemSuggestions;
    final responseTypes = {responseType1, responseType2};

    test('initial state is false when no inference is running', () {
      final state = container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
      );
      expect(state, equals(false));
    });

    test('returns true when any inference is running', () {
      // Set the first inference type to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType1,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      // Check that the running controller returns true
      expect(
        container.read(
          inferenceRunningControllerProvider(
            id: testId,
            responseTypes: responseTypes,
          ),
        ),
        equals(true),
      );

      // Set both to idle
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType1,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType2,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Check that the running controller returns false
      expect(
        container.read(
          inferenceRunningControllerProvider(
            id: testId,
            responseTypes: responseTypes,
          ),
        ),
        equals(false),
      );

      // Set the second inference type to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType2,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      // Check that the running controller returns true
      expect(
        container.read(
          inferenceRunningControllerProvider(
            id: testId,
            responseTypes: responseTypes,
          ),
        ),
        equals(true),
      );
    });

    test('responds to changes in inference status', () {
      final states = <bool>[];

      final unsubscribe = container.listen(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
        (previous, next) => states.add(next),
        fireImmediately: true,
      );
      subscriptions.add(unsubscribe.close);

      // Initially all inferences are idle
      expect(states, equals([false]));

      // Set first inference to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType1,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      // Allow the provider to update
      // Need to explicitly read the value to trigger the update
      container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
      );

      expect(states, equals([false, true]));

      // Set second inference to running as well
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType2,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      // Need to explicitly read the value to trigger the update
      container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
      );

      // Should still be true, but no new notification since the value didn't change
      expect(states, equals([false, true]));

      // Set first inference back to idle
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType1,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Need to explicitly read the value to trigger the update
      container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
      );

      // Should still be true because the second inference is still running
      expect(states, equals([false, true]));

      // Set second inference back to idle
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: responseType2,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Need to explicitly read the value to trigger the update
      container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: responseTypes,
        ),
      );

      // Now should be false
      expect(states, equals([false, true, false]));
    });

    test('works with empty response types set', () {
      final emptyResponseTypes = <AiResponseType>{};

      final state = container.read(
        inferenceRunningControllerProvider(
          id: testId,
          responseTypes: emptyResponseTypes,
        ),
      );

      expect(state, equals(false));
    });
  });
}
