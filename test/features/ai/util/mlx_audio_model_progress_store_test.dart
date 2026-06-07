// Mirror for lib/features/ai/util/mlx_audio_model_progress_store.dart —
// the Riverpod progress store split out of the platform channel.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai/util/mlx_audio_model_progress_store.dart';

void main() {
  group('MlxAudioModelProgressStore', () {
    test(
      '_setProgressIfNewer never regresses downloading or installed states',
      () async {
        final channel = _FakeMlxAudioChannel();
        final container = ProviderContainer(
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        );
        addTearDown(container.dispose);
        addTearDown(channel.close);

        final store = container.read(
          mlxAudioModelProgressStoreProvider.notifier,
        );
        MlxAudioModelStatus? statusOf(String id) =>
            container.read(mlxAudioModelProgressStoreProvider)[id]?.status;

        // Subscribe so the native stream is wired up.
        final sub = container.listen(
          mlxAudioModelProgressProvider('model-x'),
          (_, _) {},
        );
        addTearDown(sub.close);

        // Stream reports downloading.
        channel.emit(
          const MlxAudioModelDownloadProgress(
            modelId: 'model-x',
            status: MlxAudioModelStatus.downloading,
          ),
        );
        await container.pump();
        expect(statusOf('model-x'), MlxAudioModelStatus.downloading);

        // A stale notInstalled status poll must NOT regress downloading.
        channel.statusFor = (_) => const MlxAudioModelDownloadProgress(
          modelId: 'model-x',
          status: MlxAudioModelStatus.notInstalled,
        );
        await store.refreshModelStatus('model-x');
        expect(statusOf('model-x'), MlxAudioModelStatus.downloading);

        // Progressing to installed IS applied.
        channel.statusFor = (_) => const MlxAudioModelDownloadProgress(
          modelId: 'model-x',
          status: MlxAudioModelStatus.installed,
        );
        await store.refreshModelStatus('model-x');
        expect(statusOf('model-x'), MlxAudioModelStatus.installed);

        // Neither notInstalled nor downloading may regress installed.
        for (final stale in [
          MlxAudioModelStatus.notInstalled,
          MlxAudioModelStatus.downloading,
        ]) {
          channel.statusFor = (_) => MlxAudioModelDownloadProgress(
            modelId: 'model-x',
            status: stale,
          );
          await store.refreshModelStatus('model-x');
          expect(
            statusOf('model-x'),
            MlxAudioModelStatus.installed,
            reason: 'stale=$stale',
          );
        }
      },
    );

    test(
      'shares one native progress stream across model progress reads',
      () async {
        final channel = _FakeMlxAudioChannel();
        final container = ProviderContainer(
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        );
        addTearDown(container.dispose);
        addTearDown(channel.close);

        final modelAValues = <MlxAudioModelDownloadProgress?>[];
        final modelBValues = <MlxAudioModelDownloadProgress?>[];
        final subscriptionA = container.listen(
          mlxAudioModelProgressProvider('model-a'),
          (_, next) => modelAValues.add(next),
          fireImmediately: true,
        );
        final subscriptionB = container.listen(
          mlxAudioModelProgressProvider('model-b'),
          (_, next) => modelBValues.add(next),
          fireImmediately: true,
        );
        addTearDown(subscriptionA.close);
        addTearDown(subscriptionB.close);

        await container
            .read(mlxAudioModelProgressStoreProvider.notifier)
            .refreshModelStatus('model-a');
        await container
            .read(mlxAudioModelProgressStoreProvider.notifier)
            .refreshModelStatus('model-b');
        await container.pump();

        expect(channel.downloadProgressListenCount, 1);
        expect(modelAValues.last?.status, MlxAudioModelStatus.notInstalled);
        expect(modelBValues.last?.status, MlxAudioModelStatus.notInstalled);

        channel.emit(
          const MlxAudioModelDownloadProgress(
            modelId: 'model-a',
            status: MlxAudioModelStatus.downloading,
            completedUnitCount: 42,
            totalUnitCount: 100,
          ),
        );
        await Future<void>.value();
        await container.pump();

        expect(modelAValues.last?.percentComplete, 42);
        expect(modelBValues.last?.status, MlxAudioModelStatus.notInstalled);
      },
    );

    test(
      'records failed progress when a native status refresh throws',
      () async {
        final channel = _FakeMlxAudioChannel()
          ..statusError = Exception('status refresh failed');
        final container = ProviderContainer(
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        );
        addTearDown(container.dispose);
        addTearDown(channel.close);

        final values = <MlxAudioModelDownloadProgress?>[];
        final subscription = container.listen(
          mlxAudioModelProgressProvider('model-a'),
          (_, next) => values.add(next),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await container
            .read(mlxAudioModelProgressStoreProvider.notifier)
            .refreshModelStatus('model-a');
        await container.pump();

        expect(values.last?.status, MlxAudioModelStatus.failed);
        expect(values.last?.message, contains('status refresh failed'));
      },
    );

    test('records failed progress when native model install throws', () async {
      final channel = _FakeMlxAudioChannel()
        ..installError = Exception('download failed')
        ..statusFor = (modelId) => MlxAudioModelDownloadProgress(
          modelId: modelId,
          status: MlxAudioModelStatus.failed,
          message: 'download failed',
        );
      final container = ProviderContainer(
        overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
      );
      addTearDown(container.dispose);
      addTearDown(channel.close);

      final values = <MlxAudioModelDownloadProgress?>[];
      final subscription = container.listen(
        mlxAudioModelProgressProvider('model-a'),
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(mlxAudioModelProgressStoreProvider.notifier)
          .installModel('model-a');
      await container.pump();

      expect(channel.installCalls, 1);
      expect(values.last?.status, MlxAudioModelStatus.failed);
      expect(values.last?.message, 'download failed');
    });

    test('coalesces concurrent install requests for the same model', () async {
      final installCompleter = Completer<void>();
      final channel = _FakeMlxAudioChannel()
        ..installCompleter = installCompleter;
      final container = ProviderContainer(
        overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
      );
      addTearDown(container.dispose);
      addTearDown(channel.close);

      final store = container.read(mlxAudioModelProgressStoreProvider.notifier);
      final firstInstall = store.installModel('model-a');
      final secondInstall = store.installModel('model-a');
      await container.pump();

      expect(channel.installCalls, 1);

      installCompleter.complete();
      await firstInstall;
      await secondInstall;
      await container.pump();

      expect(channel.installCalls, 1);
    });

    test('download stream errors do not mutate model progress state', () async {
      final channel = _FakeMlxAudioChannel();
      final container = ProviderContainer(
        overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
      );
      addTearDown(container.dispose);
      addTearDown(channel.close);

      final states = <Map<String, MlxAudioModelDownloadProgress>>[];
      final subscription = container.listen(
        mlxAudioModelProgressStoreProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(
        container.read(mlxAudioModelProgressStoreProvider),
        isEmpty,
      );

      channel.emitError(Exception('event stream failed'));
      await Future<void>.value();
      await container.pump();

      expect(
        container.read(mlxAudioModelProgressStoreProvider),
        isEmpty,
      );
      expect(
        states,
        [const <String, MlxAudioModelDownloadProgress>{}],
      );
    });

    test('download stream events update the matching model only', () async {
      final channel = _FakeMlxAudioChannel();
      final container = ProviderContainer(
        overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
      );
      addTearDown(container.dispose);
      addTearDown(channel.close);

      final modelAValues = <MlxAudioModelDownloadProgress?>[];
      final subscription = container.listen(
        mlxAudioModelProgressProvider('model-a'),
        (_, next) => modelAValues.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      channel.emit(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-b',
          status: MlxAudioModelStatus.downloading,
        ),
      );
      await Future<void>.value();
      await container.pump();

      expect(modelAValues.last?.status, MlxAudioModelStatus.notInstalled);
      expect(
        container.read(mlxAudioModelProgressProvider('model-b'))?.status,
        MlxAudioModelStatus.downloading,
      );
    });

    test(
      'does not let a stale status refresh regress an installed model',
      () async {
        final channel = _FakeMlxAudioChannel();
        final container = ProviderContainer(
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        );
        addTearDown(container.dispose);
        addTearDown(channel.close);

        final values = <MlxAudioModelDownloadProgress?>[];
        final subscription = container.listen(
          mlxAudioModelProgressProvider('model-a'),
          (_, next) => values.add(next),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        channel.emit(
          const MlxAudioModelDownloadProgress(
            modelId: 'model-a',
            status: MlxAudioModelStatus.installed,
          ),
        );
        await Future<void>.value();
        await container.pump();

        await container
            .read(mlxAudioModelProgressStoreProvider.notifier)
            .refreshModelStatus('model-a');
        await container.pump();

        expect(values.last?.status, MlxAudioModelStatus.installed);
      },
    );
  });
}

class _FakeMlxAudioChannel extends MlxAudioChannel {
  final _progressController =
      StreamController<MlxAudioModelDownloadProgress>.broadcast(
        onListen: () {},
      );
  int downloadProgressListenCount = 0;
  int installCalls = 0;
  Exception? statusError;
  Exception? installError;
  Completer<void>? installCompleter;
  MlxAudioModelDownloadProgress Function(String modelId)? statusFor;

  @override
  Stream<MlxAudioModelDownloadProgress> get downloadProgressStream {
    downloadProgressListenCount++;
    return _progressController.stream;
  }

  @override
  Future<MlxAudioModelDownloadProgress> getModelStatus(String modelId) async {
    final error = statusError;
    if (error != null) throw error;
    final customStatus = statusFor;
    if (customStatus != null) return customStatus(modelId);
    return MlxAudioModelDownloadProgress(
      modelId: modelId,
      status: MlxAudioModelStatus.notInstalled,
    );
  }

  @override
  Future<void> installModel(String modelId) async {
    installCalls++;
    final error = installError;
    if (error != null) throw error;
    final completer = installCompleter;
    if (completer != null) await completer.future;
  }

  void emit(MlxAudioModelDownloadProgress progress) {
    _progressController.add(progress);
  }

  void emitError(Object error) {
    _progressController.addError(error, StackTrace.current);
  }

  Future<void> close() => _progressController.close();
}
