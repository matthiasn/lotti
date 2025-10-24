import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/state/audio_waveform_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockAudioWaveformService extends Mock implements AudioWaveformService {}

void main() {
  late _MockAudioWaveformService mockService;

  setUpAll(() {
    final audio = JournalAudio(
      meta: Metadata(
        id: 'fallback',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
      ),
      data: AudioData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
        audioFile: 'fallback.m4a',
        audioDirectory: '/audio/2024-01-01/',
        duration: const Duration(seconds: 5),
      ),
      entryText: const EntryText(plainText: 'fallback'),
    );
    registerFallbackValue(audio);
  });

  setUp(() async {
    await getIt.reset();
    mockService = _MockAudioWaveformService();
    getIt.registerSingleton<AudioWaveformService>(mockService);
  });

  JournalAudio createAudio({
    String id = 'audio-1',
    Duration duration = const Duration(seconds: 30),
  }) {
    final recordedAt = DateTime(2024, 1, 1, 9);
    return JournalAudio(
      meta: Metadata(
        id: id,
        createdAt: recordedAt,
        updatedAt: recordedAt,
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
      ),
      data: AudioData(
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
        audioFile: '$id.m4a',
        audioDirectory:
            '/audio/${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}/',
        duration: duration,
      ),
      entryText: const EntryText(plainText: 'sample'),
    );
  }

  AudioWaveformData createWaveformData({
    Duration duration = const Duration(seconds: 30),
    List<double> amplitudes = const <double>[0.1, 0.5, 0.9],
  }) {
    return AudioWaveformData(
      amplitudes: amplitudes,
      bucketDuration: const Duration(milliseconds: 20),
      audioDuration: duration,
    );
  }

  test('provider returns waveform data for valid request', () async {
    final audio = createAudio();
    final request = AudioWaveformRequest(audio: audio, bucketCount: 200);
    final expected = createWaveformData();

    when(
      () => mockService.loadWaveform(
        request.audio,
        targetBuckets: request.bucketCount,
      ),
    ).thenAnswer((_) async => expected);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(audioWaveformProvider(request).future);

    expect(result, same(expected));
    verify(
      () => mockService.loadWaveform(
        request.audio,
        targetBuckets: request.bucketCount,
      ),
    ).called(1);
  });

  test('provider caches identical requests within keep-alive window', () {
    fakeAsync((async) {
      final audio = createAudio();
      final request = AudioWaveformRequest(audio: audio, bucketCount: 120);
      final expected = createWaveformData();

      var callCount = 0;
      when(
        () => mockService.loadWaveform(
          request.audio,
          targetBuckets: request.bucketCount,
        ),
      ).thenAnswer((_) async {
        callCount++;
        return expected;
      });

      late ProviderContainer container;
      async.run((_) async {
        container = ProviderContainer();
        final sub =
            container.listen(audioWaveformProvider(request), (_, __) {});
        await container.read(audioWaveformProvider(request).future);
        sub.close();
      });

      expect(callCount, 1);
      expect(
        async.pendingTimers
            .where(
              (timer) =>
                  timer.duration == const Duration(minutes: 15) &&
                  !timer.isPeriodic,
            )
            .length,
        1,
      );

      async
        ..elapse(const Duration(minutes: 14, seconds: 50))
        ..flushMicrotasks()
        ..run((_) async {
          final result =
              await container.read(audioWaveformProvider(request).future);
          expect(result, same(expected));
        });

      expect(callCount, 1);
      async.run((_) {
        container.dispose();
      });
    });
  });

  test('provider refreshes after keep-alive timer fires', () {
    fakeAsync((async) {
      final audio = createAudio();
      final request = AudioWaveformRequest(audio: audio, bucketCount: 160);
      final first = createWaveformData(amplitudes: const <double>[0.2, 0.4]);
      final second = createWaveformData(amplitudes: const <double>[0.7, 0.8]);
      var callCount = 0;

      when(
        () => mockService.loadWaveform(
          request.audio,
          targetBuckets: request.bucketCount,
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? first : second;
      });

      late ProviderContainer container;
      async.run((_) async {
        container = ProviderContainer();
        await container.read(audioWaveformProvider(request).future);
      });

      expect(callCount, 1);
      async
        ..elapse(const Duration(minutes: 15, seconds: 1))
        ..flushMicrotasks()
        ..run((_) async {
          final result =
              await container.read(audioWaveformProvider(request).future);
          expect(result, same(second));
        });

      expect(callCount, 2);
      async.run((_) {
        container.dispose();
      });
    });
  });

  test('keep-alive timer is canceled on provider disposal', () {
    fakeAsync((async) {
      final audio = createAudio();
      final request = AudioWaveformRequest(audio: audio, bucketCount: 90);

      when(
        () => mockService.loadWaveform(
          request.audio,
          targetBuckets: request.bucketCount,
        ),
      ).thenAnswer((_) async => createWaveformData());

      late ProviderContainer container;
      async.run((_) async {
        container = ProviderContainer();
        await container.read(audioWaveformProvider(request).future);
      });

      expect(
        async.pendingTimers
            .where(
              (timer) =>
                  timer.duration == const Duration(minutes: 15) &&
                  !timer.isPeriodic,
            )
            .length,
        1,
      );

      async.run((_) {
        container.dispose();
      });

      expect(
        async.pendingTimers
            .where(
              (timer) =>
                  timer.duration == const Duration(minutes: 15) &&
                  !timer.isPeriodic,
            )
            .length,
        0,
      );
    });
  });

  test('different bucket count creates new cache entry', () async {
    final audio = createAudio();
    final requestA = AudioWaveformRequest(audio: audio, bucketCount: 100);
    final requestB = AudioWaveformRequest(audio: audio, bucketCount: 200);

    when(
      () => mockService.loadWaveform(
        requestA.audio,
        targetBuckets: requestA.bucketCount,
      ),
    ).thenAnswer(
        (_) async => createWaveformData(amplitudes: const <double>[0.2]));

    when(
      () => mockService.loadWaveform(
        requestB.audio,
        targetBuckets: requestB.bucketCount,
      ),
    ).thenAnswer(
        (_) async => createWaveformData(amplitudes: const <double>[0.6]));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container.read(audioWaveformProvider(requestA).future);
    final second = await container.read(audioWaveformProvider(requestB).future);

    expect(first?.amplitudes, equals(const <double>[0.2]));
    expect(second?.amplitudes, equals(const <double>[0.6]));

    verify(
      () => mockService.loadWaveform(
        requestA.audio,
        targetBuckets: requestA.bucketCount,
      ),
    ).called(1);
    verify(
      () => mockService.loadWaveform(
        requestB.audio,
        targetBuckets: requestB.bucketCount,
      ),
    ).called(1);
  });

  test('provider caches responses using request equality', () async {
    final audio = createAudio();
    final requestA = AudioWaveformRequest(audio: audio, bucketCount: 140);
    final requestB = AudioWaveformRequest(audio: audio, bucketCount: 140);
    final expected = createWaveformData();

    when(
      () => mockService.loadWaveform(
        any<JournalAudio>(),
        targetBuckets: any(named: 'targetBuckets'),
      ),
    ).thenAnswer((_) async => expected);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container.read(audioWaveformProvider(requestA).future);
    final second = await container.read(audioWaveformProvider(requestB).future);

    expect(identical(first, second), isTrue);
    verify(
      () => mockService.loadWaveform(
        requestA.audio,
        targetBuckets: requestA.bucketCount,
      ),
    ).called(1);
  });
}
