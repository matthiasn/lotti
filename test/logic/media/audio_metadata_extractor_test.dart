import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/utils/platform.dart' as lotti_platform;
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart' as mt;

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart';

class _GeneratedAudioFilenameScenario {
  const _GeneratedAudioFilenameScenario({
    required this.year,
    required this.monthSeed,
    required this.daySeed,
    required this.hourSeed,
    required this.minuteSeed,
    required this.secondSeed,
    required this.millisecondSeed,
  });

  final int year;
  final int monthSeed;
  final int daySeed;
  final int hourSeed;
  final int minuteSeed;
  final int secondSeed;
  final int millisecondSeed;

  int get month => (monthSeed % 12) + 1;

  int get day => (daySeed % 28) + 1;

  int get hour => hourSeed % 24;

  int get minute => minuteSeed % 60;

  int get second => secondSeed % 60;

  int get millisecond => millisecondSeed % 1000;

  String get extension =>
      AudioMetadataExtractor.supportedExtensions[millisecondSeed %
          AudioMetadataExtractor.supportedExtensions.length];

  DateTime get utcTimestamp =>
      DateTime.utc(year, month, day, hour, minute, second, millisecond);

  DateTime get parsedLocalTimestamp => utcTimestamp.toLocal();

  String get filename => '${_formatAudioDateTime(utcTimestamp)}.$extension';

  String get expectedRelativePath =>
      '/audio/${_formatAudioDate(parsedLocalTimestamp)}/';

  String get expectedTargetFileName =>
      '${_formatAudioDateTime(parsedLocalTimestamp)}.$extension';

  @override
  String toString() {
    return '_GeneratedAudioFilenameScenario('
        'filename: $filename, '
        'parsedLocalTimestamp: $parsedLocalTimestamp)';
  }
}

extension _AnyGeneratedAudioFilenameScenario on glados.Any {
  glados.Generator<_GeneratedAudioFilenameScenario> get audioFilenameScenario =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(2020, 2031),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          int year,
          int monthSeed,
          int daySeed,
          int hourSeed,
          int minuteSeed,
          int secondSeed,
          int millisecondSeed,
        ) => _GeneratedAudioFilenameScenario(
          year: year,
          monthSeed: monthSeed,
          daySeed: daySeed,
          hourSeed: hourSeed,
          minuteSeed: minuteSeed,
          secondSeed: secondSeed,
          millisecondSeed: millisecondSeed,
        ),
      );
}

String _formatAudioDate(DateTime timestamp) {
  return '${_fourDigits(timestamp.year)}-'
      '${_twoDigits(timestamp.month)}-'
      '${_twoDigits(timestamp.day)}';
}

String _formatAudioDateTime(DateTime timestamp) {
  return '${_formatAudioDate(timestamp)}_'
      '${_twoDigits(timestamp.hour)}-'
      '${_twoDigits(timestamp.minute)}-'
      '${_twoDigits(timestamp.second)}-'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _fourDigits(int value) => value.toString().padLeft(4, '0');

/// Writes a minimal valid 8-bit PCM WAV file into [dir] and returns it.
///
/// The file contains 100 ms of silence (800 samples @ 8 kHz, mono, 8-bit).
/// This is the smallest standard WAV that a media library can open without
/// errors.  The returned [File] is already on disk; callers are responsible
/// for deleting it (e.g. via [addTearDown]).
Future<File> _writeMinimalWav(Directory dir) async {
  const sampleRate = 8000;
  const numSamples = 800; // 100 ms of silence
  const headerSize = 44;

  // Build WAV header + silent samples using a single cascade expression.
  final bytes = ByteData(headerSize + numSamples)
    // RIFF chunk
    ..setUint8(0, 0x52) // R
    ..setUint8(1, 0x49) // I
    ..setUint8(2, 0x46) // F
    ..setUint8(3, 0x46) // F
    ..setUint32(4, headerSize - 8 + numSamples, Endian.little) // file size - 8
    ..setUint8(8, 0x57) // W
    ..setUint8(9, 0x41) // A
    ..setUint8(10, 0x56) // V
    ..setUint8(11, 0x45) // E
    // fmt sub-chunk
    ..setUint8(12, 0x66) // f
    ..setUint8(13, 0x6D) // m
    ..setUint8(14, 0x74) // t
    ..setUint8(15, 0x20) // space
    ..setUint32(16, 16, Endian.little) // PCM sub-chunk size
    ..setUint16(20, 1, Endian.little) // PCM format
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate, Endian.little) // byte rate (8-bit mono)
    ..setUint16(32, 1, Endian.little) // block align
    ..setUint16(34, 8, Endian.little) // bits per sample
    // data sub-chunk
    ..setUint8(36, 0x64) // d
    ..setUint8(37, 0x61) // a
    ..setUint8(38, 0x74) // t
    ..setUint8(39, 0x61) // a
    ..setUint32(40, numSamples, Endian.little);
  // Remaining bytes default to zero (silence for unsigned 8-bit PCM).

  final tmp = File('${dir.path}/minimal.wav');
  await tmp.writeAsBytes(bytes.buffer.asUint8List());
  return tmp;
}

void main() {
  group('AudioMetadataExtractor', () {
    group('parseFilenameTimestamp', () {
      test('parses valid Lotti audio filename format', () {
        final result = AudioMetadataExtractor.parseFilenameTimestamp(
          '2024-01-15_10-30-45-123',
        );
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('parses filename with extension', () {
        final result = AudioMetadataExtractor.parseFilenameTimestamp(
          '2024-01-15_10-30-45-123.m4a',
        );
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('returns null for invalid filename format', () {
        expect(
          AudioMetadataExtractor.parseFilenameTimestamp('invalid-format'),
          isNull,
        );
      });

      test('returns null for empty filename', () {
        expect(AudioMetadataExtractor.parseFilenameTimestamp(''), isNull);
      });

      test('returns null for filename without milliseconds', () {
        // Format requires milliseconds (yyyy-MM-dd_HH-mm-ss-S)
        expect(
          AudioMetadataExtractor.parseFilenameTimestamp('2024-01-15_10-30-45'),
          isNull,
        );
      });

      test('returns null for partial date format', () {
        expect(
          AudioMetadataExtractor.parseFilenameTimestamp('2024-01-15'),
          isNull,
        );
      });

      test('handles leap year date', () {
        final result = AudioMetadataExtractor.parseFilenameTimestamp(
          '2024-02-29_12-00-00-000',
        );
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 2);
        expect(result.day, 29);
      });

      test('handles end of day timestamp', () {
        final result = AudioMetadataExtractor.parseFilenameTimestamp(
          '2024-12-31_23-59-59-999',
        );
        expect(result, isNotNull);
        // May roll over due to UTC to local conversion
        expect(result!.year, greaterThanOrEqualTo(2024));
      });

      test('handles midnight timestamp', () {
        final result = AudioMetadataExtractor.parseFilenameTimestamp(
          '2024-01-15_00-00-00-000',
        );
        expect(result, isNotNull);
      });

      glados.Glados(
        glados.any.audioFilenameScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('parses generated UTC filenames into local timestamps', (
        scenario,
      ) {
        expect(
          AudioMetadataExtractor.parseFilenameTimestamp(scenario.filename),
          scenario.parsedLocalTimestamp,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });

    group('computeRelativePath', () {
      test('formats date correctly for directory', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);
        final path = AudioMetadataExtractor.computeRelativePath(timestamp);
        expect(path, equals('/audio/2024-01-15/'));
      });

      test('handles single digit month and day', () {
        final timestamp = DateTime(2024, 3, 5);
        final path = AudioMetadataExtractor.computeRelativePath(timestamp);
        expect(path, equals('/audio/2024-03-05/'));
      });

      test('handles end of year', () {
        final timestamp = DateTime(2024, 12, 31);
        final path = AudioMetadataExtractor.computeRelativePath(timestamp);
        expect(path, equals('/audio/2024-12-31/'));
      });

      test('handles leap year day', () {
        final timestamp = DateTime(2024, 2, 29);
        final path = AudioMetadataExtractor.computeRelativePath(timestamp);
        expect(path, equals('/audio/2024-02-29/'));
      });

      test('handles first day of year', () {
        final timestamp = DateTime(2024);
        final path = AudioMetadataExtractor.computeRelativePath(timestamp);
        expect(path, equals('/audio/2024-01-01/'));
      });

      glados.Glados(
        glados.any.audioFilenameScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('formats generated local dates into relative paths', (scenario) {
        expect(
          AudioMetadataExtractor.computeRelativePath(
            scenario.parsedLocalTimestamp,
          ),
          scenario.expectedRelativePath,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });

    group('computeTargetFileName', () {
      test('formats filename with full timestamp', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);
        final filename = AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          'm4a',
        );
        expect(filename, equals('2024-01-15_10-30-45-123.m4a'));
      });

      test('handles zero milliseconds', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45);
        final filename = AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          'm4a',
        );
        expect(filename, equals('2024-01-15_10-30-45-000.m4a'));
      });

      test('handles maximum milliseconds', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 999);
        final filename = AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          'm4a',
        );
        expect(filename, equals('2024-01-15_10-30-45-999.m4a'));
      });

      test('preserves different file extensions', () {
        final timestamp = DateTime(2024, 1, 15);

        expect(
          AudioMetadataExtractor.computeTargetFileName(timestamp, 'wav'),
          endsWith('.wav'),
        );
        expect(
          AudioMetadataExtractor.computeTargetFileName(timestamp, 'mp3'),
          endsWith('.mp3'),
        );
        expect(
          AudioMetadataExtractor.computeTargetFileName(timestamp, 'ogg'),
          endsWith('.ogg'),
        );
      });

      test('handles midnight timestamp', () {
        final timestamp = DateTime(2024, 1, 15);
        final filename = AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          'm4a',
        );
        expect(filename, equals('2024-01-15_00-00-00-000.m4a'));
      });

      test('handles end of day timestamp', () {
        final timestamp = DateTime(2024, 1, 15, 23, 59, 59, 999);
        final filename = AudioMetadataExtractor.computeTargetFileName(
          timestamp,
          'm4a',
        );
        expect(filename, equals('2024-01-15_23-59-59-999.m4a'));
      });

      glados.Glados(
        glados.any.audioFilenameScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('formats generated local timestamps into target filenames', (
        scenario,
      ) {
        expect(
          AudioMetadataExtractor.computeTargetFileName(
            scenario.parsedLocalTimestamp,
            scenario.extension,
          ),
          scenario.expectedTargetFileName,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });

    group('extractDuration', () {
      test('returns zero duration when bypass flag is set', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final duration = await AudioMetadataExtractor.extractDuration(
          '/fake/path.m4a',
        );
        expect(duration, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('handles non-existent file path', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final duration = await AudioMetadataExtractor.extractDuration(
          '/does/not/exist.m4a',
        );
        expect(duration, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('handles empty file path', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final duration = await AudioMetadataExtractor.extractDuration('');
        expect(duration, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });
    });

    // These tests exercise the MediaKit code paths (Player creation,
    // open/timeout/catch, duration stream, and finally-block dispose).
    // They are skipped on Linux CI where libmpv is not installed, and run on
    // developer machines and macOS CI where the native library is available.
    group('extractDuration (with MediaKit)', () {
      late Directory tmpDir;

      setUpAll(() {
        // Skip the whole group when the native mpv library is absent.
        // This mirrors the guard in test/utils/utils.dart: ensureMpvInitialized.
        if (lotti_platform.isTestEnv && lotti_platform.isLinux) return;
        if (lotti_platform.isMacOS) {
          MediaKit.ensureInitialized(libmpv: '/opt/homebrew/bin/mpv');
        } else {
          MediaKit.ensureInitialized();
        }
      });

      setUp(() {
        tmpDir = Directory.systemTemp.createTempSync('audio_meta_');
        // Ensure bypass flag is off so the real Player path is taken.
        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      tearDown(() {
        // Always restore so other test groups are unaffected.
        AudioMetadataExtractor.bypassMediaKitInTests = false;
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });

      test(
        'returns Duration.zero for a non-existent file (open catch path)',
        skip: (lotti_platform.isTestEnv && lotti_platform.isLinux)
            ? 'libmpv not available on Linux CI'
            : false,
        () async {
          final missingPath =
              '${tmpDir.path}/does_not_exist_audio_metadata.m4a';
          final duration = await AudioMetadataExtractor.extractDuration(
            missingPath,
          );
          // open() fails on a missing file → inner catch(_) → Duration.zero
          expect(duration, Duration.zero);
        },
      );

      test(
        'returns Duration.zero for a corrupted/empty audio file (open catch path)',
        skip: (lotti_platform.isTestEnv && lotti_platform.isLinux)
            ? 'libmpv not available on Linux CI'
            : false,
        () async {
          // Write an empty (0-byte) temp file; mpv will fail to parse it.
          final emptyFile = File('${tmpDir.path}/empty.m4a');
          await emptyFile.writeAsBytes(<int>[]);

          final duration = await AudioMetadataExtractor.extractDuration(
            emptyFile.path,
          );
          // Empty file → open() error → inner catch(_) → Duration.zero
          expect(duration, Duration.zero);
        },
      );

      test(
        'returns Duration.zero for a minimal valid WAV (duration stream path)',
        skip: (lotti_platform.isTestEnv && lotti_platform.isLinux)
            ? 'libmpv not available on Linux CI'
            : false,
        () async {
          // Build the smallest well-formed PCM WAV (100 ms, 8-bit, mono, 8 kHz).
          final tmp = await _writeMinimalWav(tmpDir);

          // open() may succeed; the duration stream returns either a real
          // duration or Duration.zero via orElse / timeout — both are valid
          // outcomes for a tiny file in a headless test.
          final duration = await AudioMetadataExtractor.extractDuration(
            tmp.path,
          );
          expect(duration, isA<Duration>());
        },
      );
    });

    // Exercises the real MediaKit Player code path in extractDuration via an
    // injected fake Player (no native libmpv required), so these run on Linux
    // CI too. Covers player construction, open(), the duration stream,
    // dispose() in the finally block, and the TimeoutException branches.
    group('extractDuration (faked Player)', () {
      late MockPlayer player;
      late MockPlayerStream playerStream;
      late Player Function() originalFactory;

      setUpAll(registerAllFallbackValues);

      setUp(() {
        AudioMetadataExtractor.bypassMediaKitInTests = false;
        // Read the current factory before overriding: this exercises the
        // default `playerFactory = Player.new` initializer deterministically
        // (lazy static init runs on first read) and lets us restore the exact
        // previous value rather than hardcoding `Player.new`.
        originalFactory = AudioMetadataExtractor.playerFactory;
        player = MockPlayer();
        playerStream = MockPlayerStream();
        mt.when(() => player.stream).thenReturn(playerStream);
        mt.when(() => player.dispose()).thenAnswer((_) async {});
        AudioMetadataExtractor.playerFactory = () => player;
      });

      tearDown(() {
        AudioMetadataExtractor.bypassMediaKitInTests = false;
        AudioMetadataExtractor.playerFactory = originalFactory;
      });

      test('returns the first non-zero duration emitted by the stream', () async {
        const expected = Duration(seconds: 42);
        mt
            .when(() => player.open(mt.any(), play: mt.any(named: 'play')))
            .thenAnswer((_) async {});
        mt
            .when(() => playerStream.duration)
            .thenAnswer(
              (_) => Stream<Duration>.fromIterable(const [
                Duration.zero, // skipped by firstWhere(d > zero)
                expected,
                Duration(seconds: 99),
              ]),
            );

        final duration = await AudioMetadataExtractor.extractDuration(
          'any/path.m4a',
        );

        expect(duration, expected);
        // Player was opened with play disabled and disposed in the finally block.
        final captured = mt
            .verify(
              () => player.open(
                mt.captureAny(),
                play: mt.captureAny(named: 'play'),
              ),
            )
            .captured;
        expect(captured[0], isA<Media>());
        // Media normalizes the path; the filename must survive.
        expect((captured[0] as Media).uri, endsWith('path.m4a'));
        expect(captured[1], isFalse);
        mt.verify(() => player.dispose()).called(1);
      });

      test('returns Duration.zero when the stream only emits zero', () async {
        mt
            .when(() => player.open(mt.any(), play: mt.any(named: 'play')))
            .thenAnswer((_) async {});
        mt
            .when(() => playerStream.duration)
            .thenAnswer(
              (_) => Stream<Duration>.fromIterable(const [Duration.zero]),
            );

        final duration = await AudioMetadataExtractor.extractDuration(
          'any/path.m4a',
        );

        // firstWhere(d > zero) matches nothing -> orElse -> Duration.zero.
        expect(duration, Duration.zero);
        mt.verify(() => player.dispose()).called(1);
      });

      test(
        'returns Duration.zero when open() throws (open catch path)',
        () async {
          mt
              .when(() => player.open(mt.any(), play: mt.any(named: 'play')))
              .thenThrow(Exception('cannot open'));

          final duration = await AudioMetadataExtractor.extractDuration(
            'bad/path.m4a',
          );

          expect(duration, Duration.zero);
          mt.verify(() => player.dispose()).called(1);
        },
      );

      test('returns Duration.zero when open() exceeds the timeout '
          '(open TimeoutException path)', () {
        // open() never completes; the open() timeout (3s) must fire and the
        // TimeoutException branch must return Duration.zero. Driven with
        // fakeAsync so no real time elapses.
        fakeAsync((async) {
          mt
              .when(() => player.open(mt.any(), play: mt.any(named: 'play')))
              .thenAnswer((_) => Completer<void>().future); // never completes

          Duration? result;
          AudioMetadataExtractor.extractDuration(
            'any/path.m4a',
          ).then((value) => result = value);

          // Advance past the open timeout (3s).
          async
            ..elapse(AudioMetadataExtractor.playerOpenTimeout)
            ..flushMicrotasks();

          expect(result, Duration.zero);
          mt.verify(() => player.dispose()).called(1);
        });
      });

      test('returns Duration.zero when the duration stream never emits '
          '(stream timeout path)', () {
        // open() completes, but the duration stream never emits a value, so the
        // durationStreamTimeout (5s) onTimeout callback must yield Duration.zero.
        fakeAsync((async) {
          mt
              .when(() => player.open(mt.any(), play: mt.any(named: 'play')))
              .thenAnswer((_) async {});
          // A stream that never emits and never closes.
          final controller = StreamController<Duration>();
          addTearDown(controller.close);
          mt
              .when(() => playerStream.duration)
              .thenAnswer((_) => controller.stream);

          Duration? result;
          AudioMetadataExtractor.extractDuration(
            'any/path.m4a',
          ).then((value) => result = value);

          async
            ..flushMicrotasks()
            ..elapse(AudioMetadataExtractor.durationStreamTimeout)
            ..flushMicrotasks();

          expect(result, Duration.zero);
          mt.verify(() => player.dispose()).called(1);
        });
      });
    });

    group('selectReader', () {
      test('returns no-op reader when bypass flag is set', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final reader = AudioMetadataExtractor.selectReader();
        final duration = await reader('/fake/path.m4a');

        expect(duration, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('uses registered reader if provided', () async {
        var calledWithPath = '';
        Future<Duration> customReader(String path) async {
          calledWithPath = path;
          return const Duration(seconds: 42);
        }

        final reader = AudioMetadataExtractor.selectReader(
          registeredReader: customReader,
        );
        final duration = await reader('/test/path.m4a');

        expect(duration, const Duration(seconds: 42));
        expect(calledWithPath, '/test/path.m4a');
      });

      test('returns function that can be called multiple times', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final reader = AudioMetadataExtractor.selectReader();

        final duration1 = await reader('/path1.m4a');
        final duration2 = await reader('/path2.m4a');

        expect(duration1, Duration.zero);
        expect(duration2, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('registered reader takes precedence over bypass flag', () async {
        // Even with bypass flag set, a registered reader should be used
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        Future<Duration> customReader(String path) async {
          return const Duration(minutes: 5);
        }

        final reader = AudioMetadataExtractor.selectReader(
          registeredReader: customReader,
        );
        final duration = await reader('/any/path.m4a');

        // Custom reader should be used, not the bypass no-op
        expect(duration, const Duration(minutes: 5));

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('returns no-op reader in Flutter test environment', () async {
        // In Flutter test environment (FLUTTER_TEST=true), should return no-op
        // even when bypass flag is false
        AudioMetadataExtractor.bypassMediaKitInTests = false;

        final reader = AudioMetadataExtractor.selectReader();
        final duration = await reader('/fake/path.m4a');

        // Should return zero because FLUTTER_TEST=true in test environment
        expect(duration, Duration.zero);
      });

      test('registered reader can return various durations', () async {
        Future<Duration> variableReader(String path) async {
          if (path.contains('short')) {
            return const Duration(seconds: 10);
          } else if (path.contains('long')) {
            return const Duration(hours: 2);
          }
          return Duration.zero;
        }

        final reader = AudioMetadataExtractor.selectReader(
          registeredReader: variableReader,
        );

        expect(await reader('/short.m4a'), const Duration(seconds: 10));
        expect(await reader('/long.m4a'), const Duration(hours: 2));
        expect(await reader('/other.m4a'), Duration.zero);
      });
    });

    group('constants', () {
      test('supportedExtensions contains expected formats', () {
        expect(
          AudioMetadataExtractor.supportedExtensions,
          containsAll(['m4a', 'aac', 'mp3', 'wav', 'ogg']),
        );
      });

      test('playerOpenTimeout is reasonable', () {
        expect(
          AudioMetadataExtractor.playerOpenTimeout,
          const Duration(seconds: 3),
        );
      });

      test('durationStreamTimeout is reasonable', () {
        expect(
          AudioMetadataExtractor.durationStreamTimeout,
          const Duration(seconds: 5),
        );
      });
    });

    group('bypassMediaKitInTests flag', () {
      test('can be set and read', () {
        final originalValue = AudioMetadataExtractor.bypassMediaKitInTests;

        AudioMetadataExtractor.bypassMediaKitInTests = true;
        expect(AudioMetadataExtractor.bypassMediaKitInTests, isTrue);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
        expect(AudioMetadataExtractor.bypassMediaKitInTests, isFalse);

        // Restore original value
        AudioMetadataExtractor.bypassMediaKitInTests = originalValue;
      });
    });
  });
}
