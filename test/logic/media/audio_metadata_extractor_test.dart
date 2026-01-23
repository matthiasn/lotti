import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';

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
    });

    group('computeTargetFileName', () {
      test('formats filename with full timestamp', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);
        final filename =
            AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
        expect(filename, equals('2024-01-15_10-30-45-123.m4a'));
      });

      test('handles zero milliseconds', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45);
        final filename =
            AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
        expect(filename, equals('2024-01-15_10-30-45-000.m4a'));
      });

      test('handles maximum milliseconds', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 45, 999);
        final filename =
            AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
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
        final filename =
            AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
        expect(filename, equals('2024-01-15_00-00-00-000.m4a'));
      });

      test('handles end of day timestamp', () {
        final timestamp = DateTime(2024, 1, 15, 23, 59, 59, 999);
        final filename =
            AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
        expect(filename, equals('2024-01-15_23-59-59-999.m4a'));
      });
    });

    group('isSupported', () {
      test('returns true for supported extensions', () {
        expect(AudioMetadataExtractor.isSupported('m4a'), isTrue);
        expect(AudioMetadataExtractor.isSupported('aac'), isTrue);
        expect(AudioMetadataExtractor.isSupported('mp3'), isTrue);
        expect(AudioMetadataExtractor.isSupported('wav'), isTrue);
        expect(AudioMetadataExtractor.isSupported('ogg'), isTrue);
      });

      test('returns false for unsupported extensions', () {
        expect(AudioMetadataExtractor.isSupported('flac'), isFalse);
        expect(AudioMetadataExtractor.isSupported('wma'), isFalse);
        expect(AudioMetadataExtractor.isSupported('jpg'), isFalse);
        expect(AudioMetadataExtractor.isSupported('pdf'), isFalse);
      });

      test('is case insensitive', () {
        expect(AudioMetadataExtractor.isSupported('M4A'), isTrue);
        expect(AudioMetadataExtractor.isSupported('MP3'), isTrue);
        expect(AudioMetadataExtractor.isSupported('WAV'), isTrue);
      });

      test('returns false for empty string', () {
        expect(AudioMetadataExtractor.isSupported(''), isFalse);
      });
    });

    group('extractDuration', () {
      test('returns zero duration when bypass flag is set', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final duration =
            await AudioMetadataExtractor.extractDuration('/fake/path.m4a');
        expect(duration, Duration.zero);

        AudioMetadataExtractor.bypassMediaKitInTests = false;
      });

      test('handles non-existent file path', () async {
        AudioMetadataExtractor.bypassMediaKitInTests = true;

        final duration =
            await AudioMetadataExtractor.extractDuration('/does/not/exist.m4a');
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

        final reader =
            AudioMetadataExtractor.selectReader(registeredReader: customReader);
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
