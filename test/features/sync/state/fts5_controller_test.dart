import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockMaintenance extends Mock implements Maintenance {}

void main() {
  late MockMaintenance mockMaintenance;
  late Fts5Controller controller;

  setUp(() {
    mockMaintenance = MockMaintenance();
    controller = Fts5Controller(mockMaintenance);
  });

  group('Fts5Controller', () {
    test('initial state should be correct', () {
      expect(controller.state.progress, 0);
      expect(controller.state.isRecreating, false);
      expect(controller.state.error, null);
    });

    test('recreateFts5 should update state correctly', () async {
      // Track state changes
      final states = <Fts5State>[];
      controller.addListener(states.add);

      // Setup mock to call onProgress with different values
      when(
        () => mockMaintenance.recreateFts5(
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[const Symbol('onProgress')]
            as void Function(double)?;
        onProgress?.call(0.25);
        onProgress?.call(0.5);
        onProgress?.call(0.75);
        onProgress?.call(1);
      });

      // Start recreation operation
      await controller.recreateFts5();

      // Verify state progression
      expect(
        states.length,
        7,
      ); // Initial + 4 progress updates + final + completion
      expect(states[0].progress, 0);
      expect(states[0].isRecreating, false);
      expect(states[1].progress, 0);
      expect(states[1].isRecreating, true);
      expect(states[2].progress, 0.25);
      expect(states[3].progress, 0.5);
      expect(states[4].progress, 0.75);
      expect(states[5].progress, 1.0);
      expect(states[6].isRecreating, false);
    });

    test('recreateFts5 should handle errors gracefully', () async {
      const testError = 'Test error';

      // Track state changes
      final states = <Fts5State>[];
      controller.addListener(states.add);

      // Setup mock to throw error
      when(
        () => mockMaintenance.recreateFts5(
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception(testError));

      // Start recreation operation
      await controller.recreateFts5();

      // Verify state progression
      expect(states.length, 3); // Initial + error + final
      expect(states[0].progress, 0);
      expect(states[0].isRecreating, false);
      expect(states[1].isRecreating, true);
      expect(states[2].isRecreating, false);
      expect(states[2].progress, 0);
      expect(states[2].error, contains(testError));
    });

    test('recreateFts5 should update progress incrementally', () async {
      // Track state changes
      final states = <Fts5State>[];
      controller.addListener(states.add);

      // Setup mock to call onProgress with specific values
      when(
        () => mockMaintenance.recreateFts5(
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[const Symbol('onProgress')]
            as void Function(double)?;
        onProgress?.call(0.25);
        onProgress?.call(0.5);
        onProgress?.call(0.75);
        onProgress?.call(1);
      });

      // Start recreation operation
      await controller.recreateFts5();

      // Verify state progression
      expect(
        states.length,
        7,
      ); // Initial + 4 progress updates + final + completion
      expect(states[0].progress, 0);
      expect(states[0].isRecreating, false);
      expect(states[1].progress, 0);
      expect(states[1].isRecreating, true);
      expect(states[2].progress, 0.25);
      expect(states[3].progress, 0.5);
      expect(states[4].progress, 0.75);
      expect(states[5].progress, 1.0);
      expect(states[6].isRecreating, false);
    });
  });
}
