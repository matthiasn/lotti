import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';

/// Builds a [ProviderContainer] that keeps the auto-dispose
/// [captureControllerProvider] alive for the duration of the test by
/// holding a no-op listener. Without this listener the provider
/// disposes immediately after each `.read(notifier)` call and
/// `Timer.periodic` never fires.
ProviderContainer _aliveContainer({CaptureController Function()? override}) {
  final container = ProviderContainer(
    overrides: [
      if (override != null) captureControllerProvider.overrideWith(override),
    ],
  )..listen(captureControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('CaptureController', () {
    test('starts in the idle phase with an empty transcript', () {
      final container = _aliveContainer();
      addTearDown(container.dispose);

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.idle);
      expect(state.transcript, '');
    });

    test('toggle from idle arms the listening phase synchronously', () {
      final container = _aliveContainer();
      addTearDown(container.dispose);

      container.read(captureControllerProvider.notifier).toggle();
      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.listening);
      expect(state.transcript, '');
    });

    test('listening streams the scripted transcript and auto-completes', () {
      fakeAsync((async) {
        final container = _aliveContainer(
          override: () => CaptureController(
            transcriptChunks: const ['Hello', ',', 'world', '.'],
            chunkInterval: const Duration(milliseconds: 10),
          ),
        );
        addTearDown(container.dispose);

        container.read(captureControllerProvider.notifier).toggle();
        async.elapse(const Duration(milliseconds: 5));
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.listening,
        );

        // 4 chunks at 10ms each + a trailing tick → ~60ms drains the
        // script and rolls over to captured.
        async.elapse(const Duration(milliseconds: 60));
        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'Hello, world.');
      });
    });

    test('toggle during listening finalises the partial transcript', () {
      fakeAsync((async) {
        final container = _aliveContainer(
          override: () => CaptureController(
            transcriptChunks: const ['one', 'two', 'three'],
            chunkInterval: const Duration(milliseconds: 50),
          ),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier)
          ..toggle();
        async.elapse(const Duration(milliseconds: 60));
        expect(container.read(captureControllerProvider).transcript, 'one');

        notifier.toggle();
        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'one');

        // Further ticks must not extend a stopped transcript.
        async.elapse(const Duration(milliseconds: 200));
        expect(container.read(captureControllerProvider).transcript, 'one');
      });
    });

    test('reset returns the controller to idle', () {
      fakeAsync((async) {
        final container = _aliveContainer(
          override: () => CaptureController(
            transcriptChunks: const ['hi'],
            chunkInterval: const Duration(milliseconds: 5),
          ),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier)
          ..toggle();
        async.elapse(const Duration(milliseconds: 30));
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.captured,
        );
        notifier.reset();
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.idle,
        );
        expect(container.read(captureControllerProvider).transcript, '');
      });
    });
  });
}
