import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';

class _FakeWaveformExtractor {
  _FakeWaveformExtractor(this.waveform);

  Waveform waveform;
  int callCount = 0;

  Future<Waveform> extract({
    required File audioFile,
    required File waveOutFile,
    required WaveformZoom zoom,
  }) async {
    callCount++;
    return waveform;
  }
}

void main() {
  late Directory tempDir;
  late MockLoggingService loggingService;
  late _FakeWaveformExtractor extractor;
  late AudioWaveformService service;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() async {
    await getIt.reset();
    tempDir = await Directory.systemTemp.createTemp('waveform_service_test');
    loggingService = MockLoggingService();
    extractor = _FakeWaveformExtractor(
      Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 1,
        data: <int>[-1, 1],
      ),
    );

    getIt
      ..registerSingleton<LoggingService>(loggingService)
      ..registerSingleton<Directory>(tempDir);

    service = AudioWaveformService(
      extractor: extractor.extract,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  JournalAudio createAudio({
    required Duration duration,
    DateTime? modified,
    String audioId = 'audio-1',
    String fileName = 'sample.m4a',
  }) {
    final recordedAt = DateTime(2024, 1, 1, 10);
    final directory =
        '/audio/${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}/';
    final audio = JournalAudio(
      meta: Metadata(
        id: audioId,
        createdAt: recordedAt,
        updatedAt: recordedAt,
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
      ),
      data: AudioData(
        dateFrom: recordedAt,
        dateTo: recordedAt.add(duration),
        audioFile: fileName,
        audioDirectory: directory,
        duration: duration,
      ),
      entryText: const EntryText(plainText: 'Test'),
    );

    final relativePath =
        AudioUtils.getRelativeAudioPath(audio).replaceFirst(RegExp('^/'), '');
    final filePath = p.join(tempDir.path, relativePath);
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(32, 0));
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }

    return audio;
  }

  test('returns null when audio duration exceeds limit', () async {
    final audio = createAudio(
      duration: const Duration(minutes: 5),
    );

    final result = await service.loadWaveform(
      audio,
      targetBuckets: 200,
    );

    expect(result, isNull);
    verify(
      () => loggingService.captureEvent(
        any<String>(),
        domain: 'audio_waveform_service',
        subDomain: 'duration_gate',
      ),
    ).called(1);
  });

  test('normalizes waveform and caches result', () async {
    final audio = createAudio(
      duration: const Duration(seconds: 10),
      modified: DateTime.utc(2024, 1, 1, 12),
    );

    extractor.waveform = Waveform(
      version: 1,
      flags: 0,
      sampleRate: 48000,
      samplesPerPixel: 480,
      length: 4,
      data: <int>[
        -32768,
        32767,
        -16384,
        16384,
        -8192,
        8192,
        0,
        0,
      ],
    );

    final result = await service.loadWaveform(
      audio,
      targetBuckets: 2,
    );

    expect(result, isNotNull);
    expect(result!.amplitudes, hasLength(2));
    expect(result.amplitudes.first, closeTo(0.94, 1e-2));
    expect(result.amplitudes.last, closeTo(0.23, 1e-2));
    expect(result.bucketDuration, const Duration(milliseconds: 20));
    expect(result.audioDuration, const Duration(milliseconds: 40));
    expect(extractor.callCount, 1);

    final sanitizedId = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final prefix = sanitizedId.length >= 2 ? sanitizedId.substring(0, 2) : '00';
    final cacheFile = File(
      p.join(
          tempDir.path, 'audio_waveforms', prefix, '${audio.meta.id}_2.json'),
    );
    expect(cacheFile.existsSync(), isTrue);

    final cached = await service.loadWaveform(
      audio,
      targetBuckets: 2,
    );
    expect(cached, isNotNull);
    expect(cached!.amplitudes.first, closeTo(result.amplitudes.first, 1e-6));
    expect(cached.amplitudes.last, closeTo(result.amplitudes.last, 1e-6));
    expect(
        extractor.callCount, 1); // Cache hit should not call extractor again.
  });

  test('reuses cache when metadata matches request', () async {
    final audio = createAudio(
      duration: const Duration(seconds: 30),
      modified: DateTime.utc(2024, 1, 1, 9),
    );
    final stat = File(await AudioUtils.getFullAudioPath(audio)).statSync();

    final sanitizedId = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final prefix = sanitizedId.length >= 2 ? sanitizedId.substring(0, 2) : '00';
    final cacheDir = Directory(p.join(tempDir.path, 'audio_waveforms', prefix))
      ..createSync(recursive: true);
    final cacheFile = File(p.join(cacheDir.path, '${audio.meta.id}_2.json'));

    final payload = {
      'version': audioWaveformCacheVersion,
      'audioFileRelativePath': AudioUtils.getRelativeAudioPath(audio),
      'audioFileSizeBytes': stat.size,
      'audioFileModifiedAt': stat.modified.toUtc().millisecondsSinceEpoch,
      'audioDurationMs': 30000,
      'bucketDurationMicros': 20000,
      'amplitudes': <double>[0.2, 0.4],
      'sampleCount': 2,
    };

    cacheFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    extractor.waveform = Waveform(
      version: 1,
      flags: 0,
      sampleRate: 48000,
      samplesPerPixel: 480,
      length: 2,
      data: <int>[-1, 1, -1, 1],
    );

    final result = await service.loadWaveform(
      audio,
      targetBuckets: 2,
    );

    expect(result, isNotNull);
    expect(result!.amplitudes, <double>[0.2, 0.4]);
    expect(result.bucketDuration, const Duration(microseconds: 20000));
    expect(result.audioDuration, const Duration(milliseconds: 30000));
    expect(extractor.callCount, 0);
  });
}
