import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // MlxAudioChannel short-circuits to "unsupported" on non-macOS hosts so the
  // native bridge is never invoked from iOS / Android / Linux / Windows
  // builds. The bulk of the suite exercises the macOS path; flip the flag for
  // those tests and restore it for each so the cross-platform CI runners
  // (Linux + Windows) keep exercising the real channel behaviour.
  late bool originalIsMacOS;

  setUp(() {
    originalIsMacOS = platform.isMacOS;
    platform.isMacOS = true;
  });

  tearDown(() {
    platform.isMacOS = originalIsMacOS;
  });

  group('MlxAudioChannel platform gate', () {
    test(
      'getModelStatus returns unsupported on non-macOS without hitting channel',
      () async {
        platform.isMacOS = false;
        const methodChannel = MethodChannel('test_mlx_audio_gate_status');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var invocations = 0;
        addTearDown(
          () => messenger.setMockMethodCallHandler(methodChannel, null),
        );
        messenger.setMockMethodCallHandler(methodChannel, (_) async {
          invocations += 1;
          return null;
        });

        final progress = await MlxAudioChannel(
          methodChannel: methodChannel,
        ).getModelStatus('model-a');

        expect(progress.status, MlxAudioModelStatus.unsupported);
        expect(progress.modelId, 'model-a');
        expect(invocations, 0);
      },
    );

    test(
      'throwing methods raise UNSUPPORTED PlatformException on non-macOS',
      () async {
        platform.isMacOS = false;
        const methodChannel = MethodChannel('test_mlx_audio_gate_methods');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var invocations = 0;
        addTearDown(
          () => messenger.setMockMethodCallHandler(methodChannel, null),
        );
        messenger.setMockMethodCallHandler(methodChannel, (_) async {
          invocations += 1;
          return null;
        });

        final channel = MlxAudioChannel(methodChannel: methodChannel);

        Matcher unsupported() => isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'UNSUPPORTED',
        );

        await expectLater(
          () => channel.installModel('model-a'),
          throwsA(unsupported()),
        );
        await expectLater(
          () => channel.transcribeFile(filePath: '/tmp/x.wav', modelId: 'm'),
          throwsA(unsupported()),
        );
        await expectLater(
          () => channel.transcribeBase64Audio(audioBase64: 'ab', modelId: 'm'),
          throwsA(unsupported()),
        );
        await expectLater(
          () => channel.speakText(text: 'hi', modelId: 'tts'),
          throwsA(unsupported()),
        );
        await expectLater(
          () => channel.startRealtimeTranscription(modelId: 'm'),
          throwsA(unsupported()),
        );
        expect(invocations, 0);
      },
    );

    test('no-op methods complete silently on non-macOS', () async {
      platform.isMacOS = false;
      const methodChannel = MethodChannel('test_mlx_audio_gate_noop');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var invocations = 0;
      addTearDown(
        () => messenger.setMockMethodCallHandler(methodChannel, null),
      );
      messenger.setMockMethodCallHandler(methodChannel, (_) async {
        invocations += 1;
        return null;
      });

      final channel = MlxAudioChannel(methodChannel: methodChannel);

      await channel.stopSpeaking();
      await channel.appendRealtimePcm(Uint8List.fromList([1, 2]));
      await channel.stopRealtimeTranscription();
      await channel.cancelRealtimeTranscription();

      expect(invocations, 0);
    });

    test('event streams emit no events on non-macOS', () async {
      platform.isMacOS = false;
      const downloadEventChannel = EventChannel(
        'test_mlx_audio_gate_download_events',
      );
      const realtimeEventChannel = EventChannel(
        'test_mlx_audio_gate_realtime_events',
      );

      final channel = MlxAudioChannel(
        eventChannel: downloadEventChannel,
        realtimeEventChannel: realtimeEventChannel,
      );

      expect(await channel.downloadProgressStream.toList(), isEmpty);
      expect(await channel.realtimeTranscriptionEvents.toList(), isEmpty);
    });
  });

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

    test(
      'downloadProgressStream maps native event payloads to progress',
      () async {
        const eventChannel = EventChannel('test_mlx_audio_download_events');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(
          () => messenger.setMockStreamHandler(eventChannel, null),
        );
        messenger.setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (args, events) {
              events
                ..success(<String, Object?>{
                  'modelId': 'model-stream',
                  'status': 'downloading',
                  'completedUnitCount': 5,
                  'totalUnitCount': 10,
                })
                ..success(<String, Object?>{
                  'modelId': 'model-stream',
                  'status': 'installed',
                  'progress': 1.0,
                })
                ..endOfStream();
            },
            onCancel: (_) {},
          ),
        );

        final channel = MlxAudioChannel(eventChannel: eventChannel);
        final events = await channel.downloadProgressStream.toList();

        expect(events, hasLength(2));
        expect(events[0].modelId, 'model-stream');
        expect(events[0].status, MlxAudioModelStatus.downloading);
        expect(events[0].percentComplete, 50);
        expect(events[1].status, MlxAudioModelStatus.installed);
      },
    );

    test(
      'realtimeTranscriptionEvents maps native event payloads to events',
      () async {
        const eventChannel = EventChannel('test_mlx_audio_realtime_events');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(
          () => messenger.setMockStreamHandler(eventChannel, null),
        );
        messenger.setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (args, events) {
              events
                ..success(<String, Object?>{
                  'type': 'transcription.confirmed',
                  'text': 'hello world',
                })
                ..success(<String, Object?>{
                  'type': 'transcription.done',
                  'text': 'hello world.',
                })
                ..endOfStream();
            },
            onCancel: (_) {},
          ),
        );

        final channel = MlxAudioChannel(realtimeEventChannel: eventChannel);
        final events = await channel.realtimeTranscriptionEvents.toList();

        expect(events, hasLength(2));
        expect(events[0].type, MlxAudioRealtimeEventType.confirmed);
        expect(events[0].text, 'hello world');
        expect(events[1].type, MlxAudioRealtimeEventType.done);
      },
    );

    test(
      'getModelStatus failure logs to the registered LoggingService',
      () async {
        final mockDomainLogger = MockDomainLogger();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..unregister<DomainLogger>()
              ..registerSingleton<DomainLogger>(mockDomainLogger);
          },
        );
        addTearDown(tearDownTestGetIt);

        const methodChannel = MethodChannel(
          'test_mlx_audio_logger_status_failure',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(
          () => messenger.setMockMethodCallHandler(methodChannel, null),
        );
        messenger.setMockMethodCallHandler(methodChannel, (_) async {
          throw PlatformException(
            code: 'NATIVE_ERROR',
            message: 'boom',
          );
        });

        final progress = await MlxAudioChannel(
          methodChannel: methodChannel,
        ).getModelStatus('model-x');

        expect(progress.status, MlxAudioModelStatus.failed);
        verify(
          () => mockDomainLogger.log(
            LogDomain.speech,
            any<String>(that: contains('MLX Audio channel getModelStatus')),
            subDomain: 'getModelStatus',
          ),
        ).called(1);
      },
    );
  });
}
