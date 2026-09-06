import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';
import 'package:lotti/features/ai/speech/sherpa_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

Future<void> _fakeWorker((SendPort, SherpaWorkerRequest) input) async {
  final (output, request) = input;
  final commands = ReceivePort();
  var count = 0;
  output.send(commands.sendPort);
  await for (final next in commands) {
    if (next != true || count == 2) break;
    output.send('segment ${++count}');
  }
  commands.close();
  await File(request.wavPath).writeAsString('$count');
  output.send(null);
}

Future<void> _failedWorker((SendPort, SherpaWorkerRequest) input) async {
  throw StateError('decoder failed');
}

void main() {
  setUpAll(registerAllFallbackValues);
  for (final model in sherpaModels) {
    test(
      '${model.name} wires its verified artifacts to the native recognizer',
      () {
        final config = sherpaRecognizerConfig(model, '/models/${model.id}');
        final json = config.model.toJson();
        final options =
            json[model.architecture.configurationKey] as Map<String, dynamic>;
        for (final role in model.recognizerFiles.entries) {
          expect(options[role.key], '/models/${model.id}/${role.value}');
        }
        if (model.recognizerFiles.containsKey('tokenizer')) {
          expect(config.model.tokens, isEmpty);
        } else {
          expect(
            config.model.tokens,
            '/models/${model.id}/${model.tokensFile}',
          );
        }
        if (model.architecture == SherpaModelArchitecture.nemoTransducer) {
          expect(config.model.modelType, 'nemo_transducer');
        }
        if (model.architecture == SherpaModelArchitecture.whisper) {
          expect(config.model.whisper.task, 'transcribe');
        }
        expect(config.model.numThreads, 2);
      },
    );
  }

  test(
    'segmentation covers all samples exactly once within the model limit',
    () {
      const rate = 100;
      for (final length in [0, 1, 2800, 2801, 6000, 12345]) {
        final samples = Float32List(length);
        final segments = sherpaSpeechSegments(samples, rate).toList();
        var cursor = 0;
        for (final (start, end) in segments) {
          expect(start, cursor);
          expect(end - start, inInclusiveRange(1, 28 * rate));
          cursor = end;
        }
        expect(cursor, length);
      }
    },
  );

  test('long windows prefer a quiet boundary without discarding silence', () {
    final samples = Float32List.fromList(List.filled(6000, 1))
      ..fillRange(2500, 2510, 0);
    final segments = sherpaSpeechSegments(samples, 100).toList();
    expect(segments.first, (0, 2510));
    expect(segments[1].$1, 2510);
    expect(segments.last.$2, samples.length);
  });

  test('invalid sample rate fails before decoding', () {
    expect(
      () => sherpaSpeechSegments(Float32List(1), 0).toList(),
      throwsArgumentError,
    );
  });

  group('native resource lifecycle', () {
    for (final scenario in [
      'complete',
      'cancel',
      'decode error',
      'empty wave',
      'init error',
    ]) {
      test('$scenario releases all acquired resources', () async {
        final recognizer = MockSherpaRecognizer();
        final stream = MockSherpaStream();
        when(recognizer.createStream).thenReturn(stream);
        when(() => recognizer.getResult(stream)).thenReturn(
          sherpa.OfflineRecognizerResult.fromJson({
            'text': ' recognized speech ',
          }),
        );
        if (scenario == 'decode error') {
          when(
            () => recognizer.decode(stream),
          ).thenThrow(StateError('decode failed'));
        }
        final messages = ReceivePort();
        final received = <Object?>[];
        final completed = Completer<void>();
        var initialized = false;
        final subscription = messages.listen((message) {
          if (message is SendPort) {
            message.send(scenario != 'cancel');
            // Queue the next request to detect end of this one-segment wave.
            if (scenario != 'cancel') message.send(true);
          } else {
            received.add(message);
            if (message == null) completed.complete();
          }
        });
        try {
          await decodeSherpaSegments(
            (
              messages.sendPort,
              const SherpaWorkerRequest(
                wavPath: '/recording.wav',
                modelDirectory: '/models',
                modelId: 'tiny',
              ),
            ),
            initialize: () {
              if (scenario == 'init error') throw StateError('load failed');
              initialized = true;
            },
            createRecognizer: (config) {
              expect(initialized, isTrue);
              expect(
                config.model.whisper.encoder,
                '/models/tiny-encoder.int8.onnx',
              );
              expect(
                config.model.whisper.decoder,
                '/models/tiny-decoder.int8.onnx',
              );
              expect(config.model.whisper.task, 'transcribe');
              expect(config.model.tokens, '/models/tiny-tokens.txt');
              expect(config.model.debug, isFalse);
              return recognizer;
            },
            readWave: (path) {
              expect(path, '/recording.wav');
              return sherpa.WaveData(
                samples: Float32List(scenario == 'empty wave' ? 0 : 160),
                sampleRate: 16000,
              );
            },
          );
          await completed.future;
          if (scenario == 'init error') {
            verifyNever(recognizer.free);
          } else {
            verify(recognizer.free).called(1);
          }
          if (scenario == 'complete' || scenario == 'decode error') {
            verify(stream.free).called(1);
            verify(() => recognizer.decode(stream)).called(1);
            final samples =
                verify(
                      () => stream.acceptWaveform(
                        samples: captureAny(named: 'samples'),
                        sampleRate: 16000,
                      ),
                    ).captured.single
                    as Float32List;
            expect(samples, hasLength(160));
          } else {
            verifyNever(recognizer.createStream);
          }
          if (scenario == 'complete') {
            expect(received, ['recognized speech', null]);
          } else if (scenario == 'cancel') {
            expect(received, [null]);
          } else {
            expect(received.first, isA<List<Object?>>());
            expect(received.last, isNull);
          }
        } finally {
          await subscription.cancel();
          messages.close();
        }
      });
    }
  });

  group('isolate lifecycle', () {
    late Directory directory;
    late SherpaWorkerRequest request;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sherpa-worker-test-');
      request = SherpaWorkerRequest(
        wavPath: '${directory.path}/decoded-count',
        modelDirectory: directory.path,
        modelId: 'tiny',
      );
    });
    tearDown(() async => directory.delete(recursive: true));

    test('streams segments in order and waits for worker cleanup', () async {
      expect(await runSherpaWorker(request, entry: _fakeWorker).toList(), [
        'segment 1',
        'segment 2',
      ]);
      expect(await File(request.wavPath).readAsString(), '2');
    });

    test(
      'cancellation stops further segments and waits for worker cleanup',
      () async {
        expect(
          await runSherpaWorker(request, entry: _fakeWorker).take(1).toList(),
          ['segment 1'],
        );
        expect(await File(request.wavPath).readAsString(), '1');
      },
    );

    test(
      'uncaught worker failures reach the caller and exit cleanly',
      () async {
        await expectLater(
          runSherpaWorker(request, entry: _failedWorker).toList(),
          throwsA(isA<StateError>()),
        );
        expect(File(request.wavPath).existsSync(), isFalse);
      },
    );

    test(
      'default worker reports unavailable native or model resources',
      () async {
        await expectLater(
          runSherpaWorker(request).toList(),
          throwsA(isA<StateError>()),
        );
        expect(await directory.list().toList(), isEmpty);
      },
    );
  });
}
