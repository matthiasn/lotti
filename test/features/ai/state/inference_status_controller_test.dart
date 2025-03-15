import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('InferenceStatusController', () {
    const testId = 'test-id';
    const testAiResponseType = 'TestSummary';

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
      const testAiResponseType2 = 'TestSummary2';

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

      container.listen(
        inferenceStatusControllerProvider(
          id: testId,
          aiResponseType: testAiResponseType,
        ),
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

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
}
