import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';

enum _GeneratedProgressStatusShape {
  installed,
  downloading,
  notInstalled,
  failed,
  unsupported,
  unknown,
}

class _GeneratedDownloadProgressScenario {
  const _GeneratedDownloadProgressScenario({
    required this.statusShape,
    required this.completedUnitCount,
    required this.totalUnitCount,
    required this.progressPermille,
    required this.includeByteCounts,
    required this.includeProgress,
  });

  final _GeneratedProgressStatusShape statusShape;
  final int completedUnitCount;
  final int totalUnitCount;
  final int progressPermille;
  final bool includeByteCounts;
  final bool includeProgress;

  String get statusValue => switch (statusShape) {
    _GeneratedProgressStatusShape.installed => 'installed',
    _GeneratedProgressStatusShape.downloading => 'downloading',
    _GeneratedProgressStatusShape.notInstalled => 'notInstalled',
    _GeneratedProgressStatusShape.failed => 'failed',
    _GeneratedProgressStatusShape.unsupported => 'unsupported',
    _GeneratedProgressStatusShape.unknown => 'generated-unknown-status',
  };

  double get progressValue => progressPermille / 1000;

  Map<String, Object?> get map => {
    'modelId': 'mlx-community/generated',
    'status': statusValue,
    if (includeByteCounts) 'completedUnitCount': completedUnitCount,
    if (includeByteCounts) 'totalUnitCount': totalUnitCount,
    if (includeProgress) 'progress': progressValue,
  };

  double? get expectedNormalizedProgress {
    if (statusShape == _GeneratedProgressStatusShape.installed) {
      return 1;
    }
    if (includeByteCounts && totalUnitCount > 0) {
      return (completedUnitCount / totalUnitCount).clamp(0, 1).toDouble();
    }
    if (includeProgress && progressValue > 0) {
      return progressValue.clamp(0, 1).toDouble();
    }
    return null;
  }

  int? get expectedPercentComplete {
    final normalized = expectedNormalizedProgress;
    if (normalized == null) return null;
    return (normalized * 100).clamp(0, 100).floor();
  }

  bool get expectedHasMeasuredProgress => expectedNormalizedProgress != null;

  @override
  String toString() {
    return '_GeneratedDownloadProgressScenario('
        'statusShape: $statusShape, '
        'completedUnitCount: $completedUnitCount, '
        'totalUnitCount: $totalUnitCount, '
        'progressPermille: $progressPermille, '
        'includeByteCounts: $includeByteCounts, '
        'includeProgress: $includeProgress)';
  }
}

extension _AnyDownloadProgressScenario on glados.Any {
  glados.Generator<_GeneratedProgressStatusShape> get progressStatusShape =>
      glados.AnyUtils(this).choose(_GeneratedProgressStatusShape.values);

  glados.Generator<_GeneratedDownloadProgressScenario>
  get downloadProgressScenario => glados.CombinableAny(this).combine6(
    progressStatusShape,
    glados.IntAnys(this).intInRange(-1000, 2000),
    glados.IntAnys(this).intInRange(-100, 1000),
    glados.IntAnys(this).intInRange(-250, 1250),
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    (
      _GeneratedProgressStatusShape statusShape,
      int completedUnitCount,
      int totalUnitCount,
      int progressPermille,
      bool includeByteCounts,
      bool includeProgress,
    ) => _GeneratedDownloadProgressScenario(
      statusShape: statusShape,
      completedUnitCount: completedUnitCount,
      totalUnitCount: totalUnitCount,
      progressPermille: progressPermille,
      includeByteCounts: includeByteCounts,
      includeProgress: includeProgress,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MlxAudioChannel', () {
    test('getModelStatus maps native status payloads', () async {
      const methodChannel = MethodChannel('test_mlx_audio_status');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(methodChannel, null),
      );
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'getModelStatus');
        expect(call.arguments, {'modelId': 'model-a'});
        return <String, Object?>{
          'status': 'downloading',
          'completedUnitCount': 4,
          'totalUnitCount': 8,
        };
      });

      final progress = await MlxAudioChannel(
        methodChannel: methodChannel,
      ).getModelStatus('model-a');

      expect(progress.modelId, 'model-a');
      expect(progress.status, MlxAudioModelStatus.downloading);
      expect(progress.percentComplete, 50);
    });

    test(
      'getModelStatus reports unsupported when native plugin is absent',
      () async {
        const methodChannel = MethodChannel('test_mlx_audio_missing_plugin');
        final progress = await MlxAudioChannel(
          methodChannel: methodChannel,
        ).getModelStatus('model-a');

        expect(progress.modelId, 'model-a');
        expect(progress.status, MlxAudioModelStatus.unsupported);
      },
    );

    test(
      'getModelStatus converts platform failures into failed progress',
      () async {
        const methodChannel = MethodChannel('test_mlx_audio_status_failure');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(
          () => messenger.setMockMethodCallHandler(methodChannel, null),
        );
        messenger.setMockMethodCallHandler(methodChannel, (_) async {
          throw PlatformException(
            code: 'NATIVE_ERROR',
            message: 'Native status failed',
          );
        });

        final progress = await MlxAudioChannel(
          methodChannel: methodChannel,
        ).getModelStatus('model-a');

        expect(progress.status, MlxAudioModelStatus.failed);
        expect(progress.message, 'Native status failed');
      },
    );

    test(
      'forwards native method calls and parses transcription results',
      () async {
        const methodChannel = MethodChannel('test_mlx_audio_methods');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <MethodCall>[];
        addTearDown(
          () => messenger.setMockMethodCallHandler(methodChannel, null),
        );
        messenger.setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'transcribeFile' || 'transcribeBase64Audio' => <String, Object?>{
              'text': 'local transcript',
              'detectedLanguage': 'en',
              'processingTimeMs': 42,
              'diarizationStatus': 'disabled',
            },
            _ => null,
          };
        });

        final channel = MlxAudioChannel(methodChannel: methodChannel);

        await channel.installModel('model-a');
        final fileResult = await channel.transcribeFile(
          filePath: '/tmp/audio.wav',
          modelId: 'model-a',
          language: 'English',
          speechDictionaryTerms: const ['Lotti'],
          enableSpeakerDiarization: true,
        );
        final base64Result = await channel.transcribeBase64Audio(
          audioBase64: 'abc123',
          modelId: 'model-a',
        );
        await channel.speakText(
          text: 'summary',
          modelId: 'tts-model',
          language: 'English',
        );
        await channel.stopSpeaking();
        await channel.startRealtimeTranscription(
          modelId: 'model-a',
          language: 'English',
          delayPreset: 'word',
        );
        await channel.appendRealtimePcm(Uint8List.fromList([1, 2, 3, 4]));
        await channel.stopRealtimeTranscription();
        await channel.cancelRealtimeTranscription();

        expect(fileResult.text, 'local transcript');
        expect(fileResult.detectedLanguage, 'en');
        expect(fileResult.processingTimeMs, 42);
        expect(fileResult.diarizationStatus, 'disabled');
        expect(base64Result.text, 'local transcript');
        expect(
          calls.map((call) => call.method),
          [
            'installModel',
            'transcribeFile',
            'transcribeBase64Audio',
            'speakText',
            'stopSpeaking',
            'startRealtimeTranscription',
            'appendRealtimePcm',
            'stopRealtimeTranscription',
            'cancelRealtimeTranscription',
          ],
        );
        final fileArgs = calls[1].arguments! as Map<Object?, Object?>;
        expect(fileArgs, containsPair('filePath', '/tmp/audio.wav'));
        expect(fileArgs, containsPair('modelId', 'model-a'));
        expect(fileArgs['speechDictionaryTerms'], ['Lotti']);
        expect(fileArgs, containsPair('language', 'English'));
        expect(fileArgs, containsPair('enableSpeakerDiarization', true));

        final base64Args = calls[2].arguments! as Map<Object?, Object?>;
        expect(base64Args, containsPair('audioBase64', 'abc123'));
        expect(base64Args, containsPair('modelId', 'model-a'));
        expect(base64Args['speechDictionaryTerms'], isEmpty);
        expect(base64Args, containsPair('language', null));
        expect(base64Args, containsPair('enableSpeakerDiarization', false));

        final realtimeArgs = calls[5].arguments! as Map<Object?, Object?>;
        expect(realtimeArgs, containsPair('modelId', 'model-a'));
        expect(realtimeArgs, containsPair('language', 'English'));
        expect(realtimeArgs, containsPair('delayPreset', 'word'));

        final pcmArgs = calls[6].arguments! as Map<Object?, Object?>;
        expect(pcmArgs['pcm16'], isA<Uint8List>());
        expect(pcmArgs['pcm16']! as Uint8List, [1, 2, 3, 4]);
      },
    );
  });

  group('MlxAudioRealtimeEvent', () {
    test('maps native event type strings and optional stats fields', () {
      final cases = <String?, MlxAudioRealtimeEventType>{
        'transcription.provisional': MlxAudioRealtimeEventType.provisional,
        'transcription.confirmed': MlxAudioRealtimeEventType.confirmed,
        'transcription.display': MlxAudioRealtimeEventType.display,
        'transcription.stats': MlxAudioRealtimeEventType.stats,
        'transcription.done': MlxAudioRealtimeEventType.done,
        'transcription.error': MlxAudioRealtimeEventType.error,
        'unexpected': MlxAudioRealtimeEventType.error,
        null: MlxAudioRealtimeEventType.error,
      };

      for (final entry in cases.entries) {
        final event = MlxAudioRealtimeEvent.fromMap({
          if (entry.key != null) 'type': entry.key,
          'text': 'text',
          'confirmedText': 'confirmed',
          'provisionalText': 'provisional',
          'message': 'message',
          'encodedWindowCount': 3,
          'totalAudioSeconds': 1.5,
          'tokensPerSecond': 2.5,
          'realTimeFactor': 0.75,
          'peakMemoryGB': 4.25,
        });

        expect(event.type, entry.value);
        expect(event.text, 'text');
        expect(event.confirmedText, 'confirmed');
        expect(event.provisionalText, 'provisional');
        expect(event.message, 'message');
        expect(event.encodedWindowCount, 3);
        expect(event.totalAudioSeconds, 1.5);
        expect(event.tokensPerSecond, 2.5);
        expect(event.realTimeFactor, 0.75);
        expect(event.peakMemoryGB, 4.25);
      }
    });
  });

  group('MlxAudioModelDownloadProgress', () {
    test('marks only retryable terminal statuses as installable', () {
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.notInstalled,
        ).canInstall,
        isTrue,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.failed,
        ).canInstall,
        isTrue,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.installed,
        ).canInstall,
        isFalse,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.downloading,
        ).canInstall,
        isFalse,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.unsupported,
        ).canInstall,
        isFalse,
      );
    });

    test('treats zero-byte downloading events as indeterminate', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 0,
        'totalUnitCount': 0,
      });

      expect(progress.normalizedProgress, isNull);
      expect(progress.percentComplete, isNull);
      expect(progress.hasMeasuredProgress, isFalse);
    });

    test('reports zero percent when total bytes are known', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 0,
        'totalUnitCount': 8 * 1024 * 1024 * 1024,
      });

      expect(progress.normalizedProgress, 0);
      expect(progress.percentComplete, 0);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('falls back to byte counts when native fraction is stale', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 1300,
        'totalUnitCount': 8870,
      });

      expect(progress.normalizedProgress, closeTo(0.146, 0.001));
      expect(progress.percentComplete, 14);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports tiny measured byte progress without hiding it', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.004,
        'completedUnitCount': 4,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.004);
      expect(progress.percentComplete, 0);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports measured progress above one percent', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.024,
        'completedUnitCount': 24,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.024);
      expect(progress.percentComplete, 2);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('uses native fraction when available', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.424,
        'completedUnitCount': 424,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.424);
      expect(progress.percentComplete, 42);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('derives progress from byte counts when fraction is missing', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'completedUnitCount': 25,
        'totalUnitCount': 100,
      });

      expect(progress.normalizedProgress, 0.25);
      expect(progress.percentComplete, 25);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports installed models as complete', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'installed',
      });

      expect(progress.normalizedProgress, 1);
      expect(progress.percentComplete, 100);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('ignores non-finite native progress fractions', () {
      for (final progressValue in [double.nan, double.infinity]) {
        final progress = MlxAudioModelDownloadProgress.fromMap({
          'modelId': 'mlx-community/example',
          'status': 'downloading',
          'progress': progressValue,
        });

        expect(progress.normalizedProgress, isNull);
        expect(progress.percentComplete, isNull);
        expect(progress.hasMeasuredProgress, isFalse);
      }
    });

    glados.Glados(
      glados.any.downloadProgressScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'normalizes generated byte and fraction progress consistently',
      (
        scenario,
      ) {
        final progress = MlxAudioModelDownloadProgress.fromMap(scenario.map);

        final expectedNormalized = scenario.expectedNormalizedProgress;
        if (expectedNormalized == null) {
          expect(progress.normalizedProgress, isNull, reason: '$scenario');
        } else {
          expect(
            progress.normalizedProgress,
            closeTo(expectedNormalized, 0.0000001),
            reason: '$scenario',
          );
        }
        expect(
          progress.percentComplete,
          scenario.expectedPercentComplete,
          reason: '$scenario',
        );
        expect(
          progress.hasMeasuredProgress,
          scenario.expectedHasMeasuredProgress,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('MlxAudioModelProgressStore', () {
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
