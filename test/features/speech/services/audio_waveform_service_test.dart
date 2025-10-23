import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  Object? errorToThrow;
  bool createTempOutput = false;
  bool retainTempOutput = false;
  File? lastWaveOutFile;

  Future<Waveform> extract({
    required File audioFile,
    required File waveOutFile,
    required WaveformZoom zoom,
  }) async {
    callCount++;
    lastWaveOutFile = waveOutFile;
    if (createTempOutput) {
      waveOutFile
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(8, 1));
      if (!retainTempOutput) {
        waveOutFile.deleteSync();
      }
    }
    final error = errorToThrow;
    if (error != null) {
      if (error is Error) {
        throw error;
      }
      if (error is Exception) {
        throw error;
      }
      throw Exception(error.toString());
    }
    return waveform;
  }
}

void main() {
  late Directory tempDir;
  late MockLoggingService loggingService;
  late _FakeWaveformExtractor extractor;
  late AudioWaveformService service;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(StateError('waveform missing'));
    registerFallbackValue(
      const FileSystemException('permission denied'),
    );
    registerFallbackValue(StackTrace.fromString('fallback'));
  });

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

  File audioFileFor(JournalAudio audio) {
    final relativePath =
        AudioUtils.getRelativeAudioPath(audio).replaceFirst(RegExp('^/'), '');
    return File(p.join(tempDir.path, relativePath));
  }

  File cacheFileFor(JournalAudio audio, int bucketCount) {
    final sanitizedId = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final prefix = sanitizedId.length >= 2 ? sanitizedId.substring(0, 2) : '00';
    final cacheDir = Directory(p.join(tempDir.path, 'audio_waveforms', prefix))
      ..createSync(recursive: true);
    return File(p.join(cacheDir.path, '${sanitizedId}_$bucketCount.json'));
  }

  Map<String, dynamic> buildPayload(
    JournalAudio audio, {
    required int bucketCount,
    int? version,
    int? sizeBytes,
    DateTime? modifiedAt,
    int? durationMs,
    int? bucketDurationMicros,
    List<double>? amplitudes,
    String? relativePath,
    int? sampleCount,
  }) {
    final audioFile = audioFileFor(audio);
    final stat = audioFile.statSync();
    return <String, dynamic>{
      'version': version ?? audioWaveformCacheVersion,
      'audioFileRelativePath':
          relativePath ?? AudioUtils.getRelativeAudioPath(audio),
      'audioFileSizeBytes': sizeBytes ?? stat.size,
      'audioFileModifiedAt':
          (modifiedAt ?? stat.modified.toUtc()).millisecondsSinceEpoch,
      'audioDurationMs': durationMs ?? audio.data.duration.inMilliseconds,
      'bucketDurationMicros': bucketDurationMicros ??
          const Duration(milliseconds: 20).inMicroseconds,
      'amplitudes': amplitudes ?? <double>[0.1, 0.2],
      'sampleCount': sampleCount ?? bucketCount,
    };
  }

  void writeCache({
    required JournalAudio audio,
    required int bucketCount,
    Map<String, dynamic>? overrides,
  }) {
    final file = cacheFileFor(audio, bucketCount);
    final payload =
        buildPayload(audio, bucketCount: bucketCount, sampleCount: bucketCount)
          ..addAll(overrides ?? <String, dynamic>{});
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
  }

  List<File> populateCacheEntries(int count) {
    final cacheDir = Directory(p.join(tempDir.path, 'audio_waveforms', 'aa'))
      ..createSync(recursive: true);
    final baseTime = DateTime.utc(2024, 1, 1, 12);
    final files = <File>[];
    for (var i = 0; i < count; i++) {
      final file = File(p.join(cacheDir.path, 'entry_$i.json'))
        ..writeAsStringSync('{}')
        ..setLastModifiedSync(baseTime.add(Duration(seconds: i)));
      files.add(file);
    }
    return files;
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

  group('cache invalidation', () {
    Waveform buildWaveform() {
      return Waveform(
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
    }

    test('invalidates cache when file size changes', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 20),
        modified: DateTime.utc(2024, 1, 2, 10),
      );
      writeCache(
        audio: audio,
        bucketCount: 2,
        overrides: <String, dynamic>{
          'audioFileSizeBytes': audioFileFor(audio).statSync().size + 5,
        },
      );

      extractor
        ..callCount = 0
        ..waveform = buildWaveform();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);
    });

    test('invalidates cache when file modified time changes', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 15),
        modified: DateTime.utc(2024, 1, 1, 9),
      );
      writeCache(
        audio: audio,
        bucketCount: 2,
        overrides: <String, dynamic>{
          'audioFileModifiedAt':
              DateTime.utc(2024, 1, 1, 8).millisecondsSinceEpoch,
        },
      );

      extractor
        ..callCount = 0
        ..waveform = buildWaveform();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);
    });

    test('invalidates cache when version mismatches', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 25),
        modified: DateTime.utc(2024, 1, 3, 9),
      );
      writeCache(
        audio: audio,
        bucketCount: 2,
        overrides: <String, dynamic>{
          'version': audioWaveformCacheVersion - 1,
        },
      );

      extractor
        ..callCount = 0
        ..waveform = buildWaveform();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);
    });

    test('invalidates cache when bucket count differs', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 18),
        modified: DateTime.utc(2024, 1, 4, 9),
      );
      writeCache(
        audio: audio,
        bucketCount: 2,
        overrides: <String, dynamic>{
          'sampleCount': 3,
        },
      );

      extractor
        ..callCount = 0
        ..waveform = buildWaveform();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);
    });

    test('invalidates cache when relative path changes', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 22),
        modified: DateTime.utc(2024, 1, 5, 9),
      );
      writeCache(
        audio: audio,
        bucketCount: 2,
        overrides: <String, dynamic>{
          'audioFileRelativePath': '/audio/2024-01-01/other_clip.m4a',
        },
      );

      extractor
        ..callCount = 0
        ..waveform = buildWaveform();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);
    });

    test('stale cache is replaced with fresh extraction after metadata change',
        () async {
      final audio = createAudio(
        duration: const Duration(seconds: 12),
        modified: DateTime.utc(2024, 1, 6, 9),
      );

      extractor.waveform = buildWaveform();
      await service.loadWaveform(audio, targetBuckets: 2);
      expect(extractor.callCount, 1);

      final audioFile = audioFileFor(audio)
        ..writeAsBytesSync(List<int>.filled(64, 1))
        ..setLastModifiedSync(DateTime.utc(2024, 1, 6, 10));

      extractor
        ..callCount = 0
        ..waveform = Waveform(
          version: 1,
          flags: 0,
          sampleRate: 48000,
          samplesPerPixel: 480,
          length: 4,
          data: <int>[
            -4096,
            4096,
            -2048,
            2048,
            -1024,
            1024,
            0,
            0,
          ],
        );

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      expect(extractor.callCount, 1);

      final cacheFile = cacheFileFor(audio, 2);
      final cachedPayload =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      expect(
        cachedPayload['audioFileModifiedAt'],
        audioFile.statSync().modified.toUtc().millisecondsSinceEpoch,
      );
      final cachedAmplitudes =
          (cachedPayload['amplitudes'] as List<dynamic>).cast<double>();
      expect(cachedAmplitudes, result!.amplitudes);
    });
  });

  group('normalization edge cases', () {
    test('returns empty amplitudes when waveform has zero length', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 5),
        modified: DateTime.utc(2024, 1, 7, 9),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 0,
        data: <int>[],
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 4,
      );

      expect(result, isNotNull);
      expect(result!.amplitudes, isEmpty);
      expect(result.bucketDuration, Duration.zero);
      expect(result.audioDuration, Duration.zero);
    });

    test('handles single pixel waveforms', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 3),
        modified: DateTime.utc(2024, 1, 7, 10),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 1,
        data: <int>[
          -32768,
          32767,
        ],
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 4,
      );

      expect(result, isNotNull);
      expect(result!.amplitudes, <double>[1]);
      expect(result.bucketDuration, const Duration(milliseconds: 10));
      expect(result.audioDuration, const Duration(milliseconds: 10));
    });

    test('uses 8-bit max amplitude when flags set', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 4),
        modified: DateTime.utc(2024, 1, 7, 11),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 1,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 2,
        data: <int>[
          -128,
          127,
          -64,
          64,
        ],
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 2,
      );

      expect(result, isNotNull);
      expect(
        result!.amplitudes.first,
        closeTo(1.0, 1e-6),
      );
      expect(
        result.amplitudes.last,
        closeTo(0.5, 1e-6),
      );
    });

    test('does not downsample when target buckets exceed pixel count',
        () async {
      final audio = createAudio(
        duration: const Duration(seconds: 6),
        modified: DateTime.utc(2024, 1, 7, 12),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 3,
        data: <int>[
          -32768,
          32767,
          -16384,
          16384,
          -8192,
          8192,
        ],
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 10,
      );

      expect(result, isNotNull);
      expect(result!.amplitudes, hasLength(3));
      expect(result.amplitudes[0], closeTo(1.0, 1e-6));
      expect(result.amplitudes[1], closeTo(0.5, 1e-6));
      expect(result.amplitudes[2], closeTo(0.25, 1e-6));
    });

    test('reduces to single bucket and blends peak with RMS', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 8),
        modified: DateTime.utc(2024, 1, 7, 13),
      );
      final pixelPairs = <List<int>>[
        <int>[-32768, 32767],
        <int>[-16384, 16384],
        <int>[-8192, 8192],
        <int>[-1024, 1024],
      ];
      final amplitudes = <double>[1, 0.5, 0.25, 0.03125];

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: pixelPairs.length,
        data: pixelPairs.expand((pair) => pair).toList(growable: false),
      );

      final expectedRms = math.sqrt(
        amplitudes
                .map((value) => value * value)
                .reduce((value, element) => value + element) /
            amplitudes.length,
      );
      final expectedBlended =
          amplitudes.reduce(math.max) * 0.7 + expectedRms * 0.3;

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 1,
      );

      expect(result, isNotNull);
      expect(result!.amplitudes, hasLength(1));
      expect(result.amplitudes.first, closeTo(expectedBlended, 1e-6));
    });

    test('all-zero waveform produces all-zero output', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 3),
        modified: DateTime.utc(2024, 1, 7, 14),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 4,
        data: List<int>.filled(8, 0),
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 4,
      );

      expect(result, isNotNull);
      expect(
        result!.amplitudes.every((value) => value == 0),
        isTrue,
      );
    });

    test('amplitudes are clamped to the range [0, 1]', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 5),
        modified: DateTime.utc(2024, 1, 7, 15),
      );

      extractor.waveform = Waveform(
        version: 1,
        flags: 0,
        sampleRate: 48000,
        samplesPerPixel: 480,
        length: 2,
        data: <int>[
          -40000,
          40000,
          -32000,
          32000,
        ],
      );

      final result = await service.loadWaveform(
        audio,
        targetBuckets: 2,
      );

      expect(result, isNotNull);
      expect(
        result!.amplitudes.every((value) => value >= 0 && value <= 1),
        isTrue,
      );
      expect(result.amplitudes.first, equals(1.0));
    });
  });

  group('extraction failures', () {
    test('returns null and logs when extractor throws', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 20),
        modified: DateTime.utc(2024, 1, 8, 9),
      );
      extractor
        ..errorToThrow = Exception('boom')
        ..createTempOutput = true
        ..retainTempOutput = true;

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNull);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'audio_waveform_service',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      expect(
        extractor.lastWaveOutFile?.existsSync(),
        isFalse,
      );
    });

    test('logs state error when extractor cannot provide waveform', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 18),
        modified: DateTime.utc(2024, 1, 8, 10),
      );
      extractor.errorToThrow = StateError(
        'Waveform extraction completed without emitting waveform data.',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNull);
      verify(
        () => loggingService.captureException(
          any<StateError>(),
          domain: 'audio_waveform_service',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('returns null when audio file is missing', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 14),
        modified: DateTime.utc(2024, 1, 8, 11),
      );
      audioFileFor(audio).deleteSync();

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNull);
      verify(
        () => loggingService.captureEvent(
          any<String>(),
          domain: 'audio_waveform_service',
          subDomain: 'missing_source',
        ),
      ).called(1);
    });

    test('returns null when audio file is unreadable', () async {
      if (Platform.isWindows) {
        return;
      }
      final audio = createAudio(
        duration: const Duration(seconds: 16),
        modified: DateTime.utc(2024, 1, 8, 12),
      );
      final audioFile = audioFileFor(audio);
      final removePermissions =
          await Process.run('chmod', <String>['000', audioFile.path]);
      expect(removePermissions.exitCode, 0);

      extractor.errorToThrow = const FileSystemException('Permission denied');

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNull);
      verify(
        () => loggingService.captureException(
          any<FileSystemException>(),
          domain: 'audio_waveform_service',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      final restorePermissions =
          await Process.run('chmod', <String>['600', audioFile.path]);
      expect(restorePermissions.exitCode, 0);
    });

    test('cleans up temporary file after successful extraction', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 10),
        modified: DateTime.utc(2024, 1, 8, 13),
      );
      extractor
        ..createTempOutput = true
        ..retainTempOutput = true;

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNotNull);
      final tempFile = extractor.lastWaveOutFile;
      expect(tempFile, isNotNull);
      expect(tempFile!.existsSync(), isFalse);
    });

    test('cleans up temporary file after failed extraction', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 9),
        modified: DateTime.utc(2024, 1, 8, 14),
      );
      extractor
        ..createTempOutput = true
        ..retainTempOutput = true
        ..errorToThrow = Exception('extraction failed');

      final result = await service.loadWaveform(audio, targetBuckets: 2);

      expect(result, isNull);
      final tempFile = extractor.lastWaveOutFile;
      expect(tempFile, isNotNull);
      expect(tempFile!.existsSync(), isFalse);
      verify(
        () => loggingService.captureException(
          any<Object>(),
          domain: 'audio_waveform_service',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('cache read failures', () {
    test('recovers when cache JSON is truncated', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 18),
        audioId: 'corrupted-json',
        fileName: 'corrupted.m4a',
      );

      final cacheFile = cacheFileFor(audio, 4)
        ..createSync(recursive: true)
        ..writeAsStringSync('{"version":1');

      clearInteractions(loggingService);

      final result = await service.loadWaveform(audio, targetBuckets: 4);
      expect(result, isNotNull);

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_read',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      expect(cacheFile.readAsStringSync(), isNotEmpty);
    });

    test('recovers when cache file contains non-json data', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 20),
        audioId: 'plain-text',
        fileName: 'plain.m4a',
      );

      final cacheFile = cacheFileFor(audio, 3)
        ..createSync(recursive: true)
        ..writeAsStringSync('not-json');

      clearInteractions(loggingService);

      final result = await service.loadWaveform(audio, targetBuckets: 3);
      expect(result, isNotNull);

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_read',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      expect(cacheFile.readAsStringSync(), isNotEmpty);
    });

    test('recovers when cache file is empty', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 16),
        audioId: 'empty-cache',
        fileName: 'empty.m4a',
      );

      final cacheFile = cacheFileFor(audio, 2)
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      clearInteractions(loggingService);

      final result = await service.loadWaveform(audio, targetBuckets: 2);
      expect(result, isNotNull);

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_read',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      expect(cacheFile.readAsStringSync(), isNotEmpty);
    });

    test('logs unexpected payload shape for array caches', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 24),
        audioId: 'array-cache',
        fileName: 'array.m4a',
      );

      final cacheFile = cacheFileFor(audio, 5)
        ..createSync(recursive: true)
        ..writeAsStringSync('[]');

      clearInteractions(loggingService);

      final result = await service.loadWaveform(audio, targetBuckets: 5);
      expect(result, isNotNull);

      verify(
        () => loggingService.captureEvent(
          'Unexpected cache payload shape: []',
          domain: 'audio_waveform_service',
          subDomain: 'cache_read',
        ),
      ).called(1);

      verifyNever(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_read',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      );

      expect(cacheFile.readAsStringSync(), isNotEmpty);
    });
  });

  group('cache write failures', () {
    test('logs exception when cache directory is read only', () async {
      if (Platform.isWindows) {
        return;
      }

      final audio = createAudio(
        duration: const Duration(seconds: 22),
        audioId: 'write-failure',
        fileName: 'write.m4a',
      );

      final sanitized = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.length >= 2 ? sanitized.substring(0, 2) : '00';
      final targetDir =
          Directory(p.join(tempDir.path, 'audio_waveforms', prefix))
            ..createSync(recursive: true);
      final cacheFile = File(p.join(targetDir.path, '${sanitized}_3.json'));
      final removeWrite =
          await Process.run('chmod', <String>['-w', targetDir.path]);
      expect(removeWrite.exitCode, 0);

      clearInteractions(loggingService);

      try {
        final result = await service.loadWaveform(audio, targetBuckets: 3);
        expect(result, isNotNull);
      } finally {
        final restore =
            await Process.run('chmod', <String>['+w', targetDir.path]);
        expect(restore.exitCode, 0);
      }

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_write',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);

      expect(cacheFile.existsSync(), isFalse);
    });

    test('logs parent directory creation failure', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 26),
        audioId: 'pf_parent_failure',
        fileName: 'parent.m4a',
      );

      final sanitizedId =
          audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix =
          sanitizedId.length >= 2 ? sanitizedId.substring(0, 2) : '00';
      final prefixPath = p.join(tempDir.path, 'audio_waveforms', prefix);
      Directory(prefixPath).createSync(recursive: true);

      service = AudioWaveformService(
        extractor: ({
          required File audioFile,
          required File waveOutFile,
          required WaveformZoom zoom,
        }) async {
          final waveform = await extractor.extract(
            audioFile: audioFile,
            waveOutFile: waveOutFile,
            zoom: zoom,
          );
          final directory = Directory(prefixPath);
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
          File(prefixPath).createSync(recursive: true);
          return waveform;
        },
      );

      clearInteractions(loggingService);

      final result = await service.loadWaveform(audio, targetBuckets: 3);
      expect(result, isNotNull);

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_write',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('path sanitization', () {
    test('sanitizes special characters in audio id', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 30),
        audioId: r'note:/\?*<>"|',
        fileName: 'special.m4a',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 4);
      expect(result, isNotNull);

      final sanitized = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.length >= 2 ? sanitized.substring(0, 2) : '00';
      final cacheFile = File(
        p.join(
          tempDir.path,
          'audio_waveforms',
          prefix,
          '${sanitized}_4.json',
        ),
      );
      expect(cacheFile.existsSync(), isTrue);
    });

    test('creates prefix directory for single character ids', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 28),
        audioId: 'z',
        fileName: 'single.m4a',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 2);
      expect(result, isNotNull);

      final sanitized = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.length >= 2 ? sanitized.substring(0, 2) : '00';
      final cacheFile = File(
        p.join(
          tempDir.path,
          'audio_waveforms',
          prefix,
          '${sanitized}_2.json',
        ),
      );
      expect(cacheFile.existsSync(), isTrue);
    });

    test('handles very long audio ids', () async {
      final longId = List<String>.filled(260, 'a').join();
      final audio = createAudio(
        duration: const Duration(seconds: 32),
        audioId: longId,
        fileName: 'long.m4a',
      );

      clearInteractions(loggingService);
      final result = await service.loadWaveform(audio, targetBuckets: 3);
      expect(result, isNotNull);

      final sanitized = longId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.substring(0, 2);
      final cacheFile = File(
        p.join(
          tempDir.path,
          'audio_waveforms',
          prefix,
          '${sanitized}_3.json',
        ),
      );
      expect(
          Directory(p.join(tempDir.path, 'audio_waveforms', prefix))
              .existsSync(),
          isTrue);

      if (cacheFile.existsSync()) {
        expect(p.basename(cacheFile.path), '${sanitized}_3.json');
        verifyNever(
          () => loggingService.captureException(
            any<dynamic>(),
            domain: 'audio_waveform_service',
            subDomain: 'cache_write',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        );
      } else {
        verify(
          () => loggingService.captureException(
            any<dynamic>(),
            domain: 'audio_waveform_service',
            subDomain: 'cache_write',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      }
    });

    test('sanitizes unicode audio ids', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 34),
        audioId: '音频-äudio',
        fileName: 'unicode.m4a',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 3);
      expect(result, isNotNull);

      final sanitized = audio.meta.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.substring(0, 2);
      final cacheFile = File(
        p.join(
          tempDir.path,
          'audio_waveforms',
          prefix,
          '${sanitized}_3.json',
        ),
      );
      expect(cacheFile.existsSync(), isTrue);
    });

    test('creates nested directories for sanitized prefix', () async {
      final audio = createAudio(
        duration: const Duration(seconds: 36),
        audioId: 'abc123',
        fileName: 'subdir.m4a',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 2);
      expect(result, isNotNull);

      final cacheDir = Directory(p.join(tempDir.path, 'audio_waveforms', 'ab'));
      expect(cacheDir.existsSync(), isTrue);
      final cacheFile = File(p.join(cacheDir.path, 'abc123_2.json'));
      expect(cacheFile.existsSync(), isTrue);
    });
  });

  group('cache pruning', () {
    test('prunes oldest files when exceeding 1000 entries', () async {
      populateCacheEntries(1009);
      clearInteractions(loggingService);
      final audio = createAudio(
        duration: const Duration(seconds: 30),
        audioId: 'new-audio',
        fileName: 'new.m4a',
      );

      extractor
        ..callCount = 0
        ..waveform = Waveform(
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

      final result = await service.loadWaveform(audio, targetBuckets: 2);
      expect(result, isNotNull);

      final allFiles = Directory(p.join(tempDir.path, 'audio_waveforms'))
          .listSync(recursive: true)
          .whereType<File>()
          .toList();

      expect(allFiles.length, 1000);

      final remainingNames = allFiles
          .map((file) => p.basename(file.path))
          .where((name) => name.startsWith('entry_'))
          .toSet();
      expect(remainingNames.contains('entry_0.json'), isFalse);
      expect(remainingNames.contains('entry_9.json'), isFalse);
      expect(remainingNames.contains('entry_10.json'), isTrue);

      verify(
        () => loggingService.captureEvent(
          'Pruned 10 waveform cache files (now 1000 entries)',
          domain: 'audio_waveform_service',
          subDomain: 'cache_prune',
        ),
      ).called(1);
    });

    test('skips pruning when under cache limit', () async {
      populateCacheEntries(5);
      clearInteractions(loggingService);
      final audio = createAudio(
        duration: const Duration(seconds: 25),
        audioId: 'under-limit',
        fileName: 'under.m4a',
      );

      await service.loadWaveform(audio, targetBuckets: 2);

      final allFiles = Directory(p.join(tempDir.path, 'audio_waveforms'))
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(allFiles.length, 6);
      verifyNever(
        () => loggingService.captureEvent(
          any<String>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_prune',
        ),
      );
    });

    test('handles non-existent cache directory gracefully', () async {
      final cacheRoot = Directory(p.join(tempDir.path, 'audio_waveforms'));
      if (cacheRoot.existsSync()) {
        cacheRoot.deleteSync(recursive: true);
      }
      clearInteractions(loggingService);
      final audio = createAudio(
        duration: const Duration(seconds: 20),
        audioId: 'missing-dir',
        fileName: 'missing.m4a',
      );

      final result = await service.loadWaveform(audio, targetBuckets: 2);
      expect(result, isNotNull);

      verifyNever(
        () => loggingService.captureEvent(
          any<String>(),
          domain: 'audio_waveform_service',
          subDomain: 'cache_prune',
        ),
      );
    });

    test('logs and continues when pruning deletion fails', () async {
      if (Platform.isWindows) {
        return;
      }
      final files = populateCacheEntries(1009);
      final targetDir = files.first.parent;
      final removeWrite =
          await Process.run('chmod', <String>['-w', targetDir.path]);
      expect(removeWrite.exitCode, 0);
      clearInteractions(loggingService);

      final audio = createAudio(
        duration: const Duration(seconds: 28),
        audioId: 'prune-error',
        fileName: 'error.m4a',
      );

      try {
        await service.loadWaveform(audio, targetBuckets: 2);
      } finally {
        final restore =
            await Process.run('chmod', <String>['+w', targetDir.path]);
        expect(restore.exitCode, 0);
      }

      verify(
        () => loggingService.captureEvent(
          'Pruned 10 waveform cache files (now 1000 entries)',
          domain: 'audio_waveform_service',
          subDomain: 'cache_prune',
        ),
      ).called(1);
    });
  });
}
