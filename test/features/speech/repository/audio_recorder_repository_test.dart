import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDomainLogger mockDomainLogger;
  late MockAudioRecorder mockAudioRecorder;
  late AudioRecorderRepository repository;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
    mockDomainLogger = MockDomainLogger();
    mockAudioRecorder = MockAudioRecorder();
    await getIt.unregister<DomainLogger>();
    getIt.registerSingleton<DomainLogger>(mockDomainLogger);
    repository = AudioRecorderRepository(mockAudioRecorder);

    // Setup default mock behaviors
    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(tearDownTestGetIt);

  Future<Directory> prepareRecordingDirectory() async {
    final directory = await Directory.systemTemp.createTemp(
      'audio_recorder_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    getIt.registerSingleton<Directory>(directory);
    addTearDown(getIt.unregister<Directory>);
    when(
      () => mockDomainLogger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    return directory;
  }

  group('AudioRecorderRepository', () {
    test('hasPermission returns true when permission granted', () async {
      when(
        () => mockAudioRecorder.hasPermission(),
      ).thenAnswer((_) async => true);

      final result = await repository.hasPermission();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      // Match ANY error invocation (including ones carrying a stackTrace) so the
      // success branch is proven to log no error at all, not merely no
      // stackTrace-less error.
      verifyNever(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('hasPermission returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.hasPermission(),
      ).thenAnswer((_) async => throw Exception('Permission error'));

      final result = await repository.hasPermission();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'hasPermission',
        ),
      ).called(1);
    });

    test('isPaused returns true when recording is paused', () async {
      when(() => mockAudioRecorder.isPaused()).thenAnswer((_) async => true);

      final result = await repository.isPaused();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isPaused returns false when not paused', () async {
      when(() => mockAudioRecorder.isPaused()).thenAnswer((_) async => false);

      final result = await repository.isPaused();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isPaused returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.isPaused(),
      ).thenAnswer((_) async => throw Exception('Pause check error'));

      final result = await repository.isPaused();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isPaused()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'isPaused',
        ),
      ).called(1);
    });

    test('isRecording returns true when recording is active', () async {
      when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => true);

      final result = await repository.isRecording();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false when not recording', () async {
      when(
        () => mockAudioRecorder.isRecording(),
      ).thenAnswer((_) async => false);

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.isRecording(),
      ).thenAnswer((_) async => throw Exception('Recording check error'));

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'isRecording',
        ),
      ).called(1);
    });

    test(
      'startRecording does not call the recorder without a documents directory',
      () async {
        // Stub the mock start method to complete successfully
        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        // In test environment, directory creation will fail, so we expect null
        final result = await repository.startRecording();

        expect(result, isNull);
        verifyNever(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        );
        // Verify that exception was logged due to directory creation failure
        verify(
          () => mockDomainLogger.error(
            LogDomain.speech,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'startRecording',
          ),
        ).called(1);
      },
    );

    test('startRecording returns null and logs exception on error', () async {
      final directory = await prepareRecordingDirectory();
      final failure = StateError('Recording error');
      final stack = StackTrace.fromString('recorder start stack');
      when(
        () => mockAudioRecorder.start(
          any<RecordConfig>(),
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) => Future<void>.error(failure, stack));

      final result = await withClock(
        Clock.fixed(DateTime(2024, 3, 15, 10, 30)),
        repository.startRecording,
      );

      expect(result, isNull);
      verify(
        () => mockAudioRecorder.start(
          const RecordConfig(sampleRate: 48000, autoGain: true),
          path:
              '${directory.path}/audio/2024-03-15/2024-03-15_10-30-00-000.m4a',
        ),
      ).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(that: same(failure)),
          stackTrace: stack,
          subDomain: 'startRecording',
        ),
      ).called(1);
    });

    for (final operation in ['stop', 'pause', 'resume', 'dispose']) {
      for (final fails in [false, true]) {
        test('$operation awaits platform ${fails ? 'failure' : 'success'}', () {
          fakeAsync((async) {
            final pending = Completer<void>();
            final failure = StateError('$operation failed asynchronously');
            final stack = StackTrace.fromString('$operation platform stack');
            late Future<void> Function() invoke;
            switch (operation) {
              case 'stop':
                when(mockAudioRecorder.stop).thenAnswer((_) async {
                  await pending.future;
                  return '/test/path.m4a';
                });
                invoke = repository.stopRecording;
              case 'pause':
                when(mockAudioRecorder.pause).thenAnswer((_) => pending.future);
                invoke = repository.pauseRecording;
              case 'resume':
                when(
                  mockAudioRecorder.resume,
                ).thenAnswer((_) => pending.future);
                invoke = repository.resumeRecording;
              case 'dispose':
                when(
                  mockAudioRecorder.dispose,
                ).thenAnswer((_) => pending.future);
                invoke = repository.dispose;
            }
            var completed = false;
            unawaited(invoke().then((_) => completed = true));
            try {
              async.flushMicrotasks();
              expect(completed, isFalse);
              verifyNever(
                () => mockDomainLogger.error(
                  any<LogDomain>(),
                  any<Object>(),
                  stackTrace: any(named: 'stackTrace'),
                  subDomain: any(named: 'subDomain'),
                ),
              );

              if (fails) {
                pending.completeError(failure, stack);
              } else {
                pending.complete();
              }
              async.flushMicrotasks();
              expect(completed, isTrue);
              if (fails) {
                verify(
                  () => mockDomainLogger.error(
                    LogDomain.speech,
                    any<Object>(that: same(failure)),
                    stackTrace: stack,
                    subDomain: operation == 'dispose'
                        ? operation
                        : '${operation}Recording',
                  ),
                ).called(1);
              }
              verifyNoMoreInteractions(mockDomainLogger);
              switch (operation) {
                case 'stop':
                  verify(mockAudioRecorder.stop).called(1);
                case 'pause':
                  verify(mockAudioRecorder.pause).called(1);
                case 'resume':
                  verify(mockAudioRecorder.resume).called(1);
                case 'dispose':
                  verify(mockAudioRecorder.dispose).called(1);
              }
              verifyNoMoreInteractions(mockAudioRecorder);
            } finally {
              if (!pending.isCompleted) pending.complete();
              async.flushMicrotasks();
            }
          });
        });
      }
    }

    group('deleteRecording', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'audio_recorder_delete_test_',
        );
        getIt.registerSingleton<Directory>(tempDir);
        when(
          () => mockDomainLogger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).thenReturn(null);
      });

      tearDown(() {
        if (getIt.isRegistered<Directory>()) {
          getIt.unregister<Directory>();
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      AudioNote noteFor(File file, {String directory = '/audio/day/'}) {
        return AudioNote(
          createdAt: DateTime(2024, 3, 15, 10, 30),
          audioFile: file.uri.pathSegments.last,
          audioDirectory: directory,
          duration: const Duration(seconds: 5),
        );
      }

      test('deletes the file on disk when it exists', () async {
        final dir = Directory('${tempDir.path}/audio/day')
          ..createSync(recursive: true);
        final file = File('${dir.path}/clip.m4a')..writeAsBytesSync([1, 2, 3]);
        expect(file.existsSync(), isTrue);

        await repository.deleteRecording(noteFor(file));

        expect(file.existsSync(), isFalse);
        verify(
          () => mockDomainLogger.log(
            LogDomain.speech,
            any<String>(
              that: allOf(
                contains('Deleted cancelled recording'),
                isNot(contains(tempDir.path)),
              ),
            ),
            subDomain: AudioRecorderConstants.deleteRecordingSubdomain,
          ),
        ).called(1);
      });

      test('is a no-op when the file does not exist', () async {
        final note = AudioNote(
          createdAt: DateTime(2024, 3, 15, 10, 30),
          audioFile: 'missing.m4a',
          audioDirectory: '/audio/none/',
          duration: const Duration(seconds: 5),
        );

        await expectLater(repository.deleteRecording(note), completes);

        verifyNever(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );
        verifyNever(
          () => mockDomainLogger.log(
            LogDomain.speech,
            any<String>(that: contains('Deleted cancelled recording')),
            subDomain: AudioRecorderConstants.deleteRecordingSubdomain,
          ),
        );
      });

      test('swallows and logs errors when path resolution fails', () async {
        // No Directory registered → getDocumentsDirectory() throws inside the
        // method, which must be caught and logged rather than rethrown.
        getIt.unregister<Directory>();

        final note = AudioNote(
          createdAt: DateTime(2024, 3, 15, 10, 30),
          audioFile: 'clip.m4a',
          audioDirectory: '/audio/day/',
          duration: const Duration(seconds: 5),
        );

        await expectLater(repository.deleteRecording(note), completes);

        verify(
          () => mockDomainLogger.error(
            LogDomain.speech,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: AudioRecorderConstants.deleteRecordingSubdomain,
          ),
        ).called(1);
      });
    });

    test('amplitudeStream returns a stream', () {
      const mockStream = Stream<Amplitude>.empty();
      when(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).thenAnswer((_) => mockStream);

      final stream = repository.amplitudeStream;
      expect(stream, isA<Stream<Amplitude>>());
      verify(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).called(1);
    });

    test('amplitudeStream passes 20ms interval to onAmplitudeChanged', () {
      const mockStream = Stream<Amplitude>.empty();
      when(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).thenAnswer((_) => mockStream);

      repository.amplitudeStream;

      final captured = verify(
        () => mockAudioRecorder.onAmplitudeChanged(captureAny<Duration>()),
      ).captured;
      expect(captured.single, const Duration(milliseconds: 20));
    });

    test(
      'startRecording returns AudioNote with correct fields when successful',
      () async {
        final tempDir = await prepareRecordingDirectory();

        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        final fixedNow = DateTime(2024, 3, 15, 10, 30);
        final result = await withClock(
          Clock.fixed(fixedNow),
          repository.startRecording,
        );

        expect(result, isNotNull);
        expect(result!.audioFile, endsWith('.m4a'));
        expect(result.audioDirectory, startsWith('/audio/'));
        expect(result.duration, Duration.zero);
        expect(result.createdAt, fixedNow);
        verify(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).called(1);
        final messages = verify(
          () => mockDomainLogger.log(
            LogDomain.speech,
            captureAny<String>(),
            subDomain: AudioRecorderConstants.startRecordingSubdomain,
          ),
        ).captured.cast<String>();
        expect(messages, hasLength(2));
        expect(messages.first, contains('sampleRate='));
        expect(messages.join(), isNot(contains(tempDir.path)));
      },
    );

    test(
      'startRecording records with correct config (sampleRate=48000, autoGain=true)',
      () async {
        await prepareRecordingDirectory();

        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        await repository.startRecording();

        final captured = verify(
          () => mockAudioRecorder.start(
            captureAny<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).captured;
        final config = captured.single as RecordConfig;
        expect(config.sampleRate, 48000);
        expect(config.autoGain, isTrue);
      },
    );

    test(
      'audioRecorderRepositoryProvider returns an AudioRecorderRepository',
      () {
        // Verify the provider can be read and returns the expected type.
        final mockRepo = MockAudioRecorderRepository();
        final container = ProviderContainer(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(audioRecorderRepositoryProvider);
        expect(repo, isA<AudioRecorderRepository>());
        expect(repo, same(mockRepo));
      },
    );

    test(
      'provider disposal releases exactly the platform recorder it created',
      () {
        final platform = MockRecordPlatform();
        final calls = <(String, String)>[];
        when(() => platform.create(any())).thenAnswer((invocation) async {
          calls.add((
            'create',
            invocation.positionalArguments.single as String,
          ));
        });
        when(() => platform.dispose(any())).thenAnswer((invocation) async {
          calls.add((
            'dispose',
            invocation.positionalArguments.single as String,
          ));
        });
        // Use the real repository and recorder, replacing only the platform
        // boundary. Restore this process-wide singleton after the test.
        final previousPlatform = RecordPlatform.instance;
        RecordPlatform.instance = platform;
        addTearDown(() => RecordPlatform.instance = previousPlatform);

        fakeAsync((async) {
          final container = ProviderContainer();
          var disposed = false;
          try {
            final repository = container.read(audioRecorderRepositoryProvider);
            async.flushMicrotasks();
            expect(calls.map((call) => call.$1), ['create']);
            final recorderId = calls.single.$2;
            expect(
              recorderId,
              isA<String>().having((id) => id.isNotEmpty, 'nonempty', isTrue),
            );
            expect(
              container.read(audioRecorderRepositoryProvider),
              same(repository),
            );

            container.dispose();
            disposed = true;
            async.flushMicrotasks();
            expect(calls, [('create', recorderId), ('dispose', recorderId)]);
            verifyNoMoreInteractions(mockDomainLogger);
          } finally {
            if (!disposed) container.dispose();
            async.flushMicrotasks();
          }
        });
      },
    );
  });
}
