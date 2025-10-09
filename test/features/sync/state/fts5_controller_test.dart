import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/state/fts5_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMaintenance extends Mock implements Maintenance {}

void main() {
  late MockMaintenance mockMaintenance;
  late ProviderContainer container;
  late Fts5Controller controller;

  setUp(() {
    mockMaintenance = MockMaintenance();
    container = ProviderContainer(
      overrides: [
        maintenanceProvider.overrideWithValue(mockMaintenance),
      ],
    );
    controller = container.read(fts5ControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('Fts5Controller', () {
    test('initial state should be correct', () {
      final state = container.read(fts5ControllerProvider);
      expect(state.progress, 0);
      expect(state.isRecreating, false);
      expect(state.error, null);
    });

    test('recreateFts5 should update state correctly', () async {
      final states = <Fts5State>[];
      final sub = container.listen<Fts5State>(
        fts5ControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      try {
        when(
          () => mockMaintenance.recreateFts5(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[const Symbol('onProgress')] as void
                  Function(double)?;
          onProgress?.call(0.25);
          onProgress?.call(0.5);
          onProgress?.call(0.75);
          onProgress?.call(1);
        });

        await controller.recreateFts5();

        expect(states.length, 7);
        expect(states[0].progress, 0);
        expect(states[0].isRecreating, false);
        expect(states[1].progress, 0);
        expect(states[1].isRecreating, true);
        expect(states[2].progress, 0.25);
        expect(states[3].progress, 0.5);
        expect(states[4].progress, 0.75);
        expect(states[5].progress, 1.0);
        expect(states[6].isRecreating, false);
      } finally {
        sub.close();
      }
    });

    test('recreateFts5 should handle errors gracefully', () async {
      const testError = 'Test error';

      final states = <Fts5State>[];
      final sub = container.listen<Fts5State>(
        fts5ControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      try {
        when(
          () => mockMaintenance.recreateFts5(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception(testError));

        await controller.recreateFts5();

        expect(states.length, 3);
        expect(states[0].progress, 0);
        expect(states[0].isRecreating, false);
        expect(states[1].isRecreating, true);
        expect(states[2].isRecreating, false);
        expect(states[2].progress, 0);
        expect(states[2].error, contains(testError));
      } finally {
        sub.close();
      }
    });

    test('recreateFts5 should update progress incrementally', () async {
      final states = <Fts5State>[];
      final sub = container.listen<Fts5State>(
        fts5ControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      try {
        when(
          () => mockMaintenance.recreateFts5(
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[const Symbol('onProgress')] as void
                  Function(double)?;
          onProgress?.call(0.25);
          onProgress?.call(0.5);
          onProgress?.call(0.75);
          onProgress?.call(1);
        });

        await controller.recreateFts5();

        expect(states.length, 7);
        expect(states[0].progress, 0);
        expect(states[0].isRecreating, false);
        expect(states[1].progress, 0);
        expect(states[1].isRecreating, true);
        expect(states[2].progress, 0.25);
        expect(states[3].progress, 0.5);
        expect(states[4].progress, 0.75);
        expect(states[5].progress, 1.0);
        expect(states[6].isRecreating, false);
      } finally {
        sub.close();
      }
    });
  });
}
