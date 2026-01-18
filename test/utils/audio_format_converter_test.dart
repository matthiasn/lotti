import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/audio_format_converter.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFormatConverter -', () {
    setUpAll(setFakeDocumentsPath);

    group('isM4aFile', () {
      test('returns true for .m4a extension', () {
        expect(AudioFormatConverter.isM4aFile('/path/to/audio.m4a'), isTrue);
      });

      test('returns true for .M4A extension (case insensitive)', () {
        expect(AudioFormatConverter.isM4aFile('/path/to/audio.M4A'), isTrue);
      });

      test('returns false for .wav extension', () {
        expect(AudioFormatConverter.isM4aFile('/path/to/audio.wav'), isFalse);
      });

      test('returns false for .mp3 extension', () {
        expect(AudioFormatConverter.isM4aFile('/path/to/audio.mp3'), isFalse);
      });

      test('returns false for .aac extension', () {
        expect(AudioFormatConverter.isM4aFile('/path/to/audio.aac'), isFalse);
      });
    });

    group('isWavFile', () {
      test('returns true for .wav extension', () {
        expect(AudioFormatConverter.isWavFile('/path/to/audio.wav'), isTrue);
      });

      test('returns true for .WAV extension (case insensitive)', () {
        expect(AudioFormatConverter.isWavFile('/path/to/audio.WAV'), isTrue);
      });

      test('returns false for .m4a extension', () {
        expect(AudioFormatConverter.isWavFile('/path/to/audio.m4a'), isFalse);
      });

      test('returns false for .mp3 extension', () {
        expect(AudioFormatConverter.isWavFile('/path/to/audio.mp3'), isFalse);
      });
    });

    group('AudioConversionResult', () {
      test('success result has outputPath', () {
        final result = AudioConversionResult(
          success: true,
          outputPath: '/tmp/converted.wav',
        );

        expect(result.success, isTrue);
        expect(result.outputPath, equals('/tmp/converted.wav'));
        expect(result.error, isNull);
      });

      test('failure result has error message', () {
        final result = AudioConversionResult(
          success: false,
          error: 'Conversion failed',
        );

        expect(result.success, isFalse);
        expect(result.outputPath, isNull);
        expect(result.error, equals('Conversion failed'));
      });
    });

    group('AudioConversionException', () {
      test('toString includes message', () {
        final exception = AudioConversionException('FFmpeg not found');

        expect(
          exception.toString(),
          equals('AudioConversionException: FFmpeg not found'),
        );
      });

      test('toString handles null message', () {
        final exception = AudioConversionException(null);

        expect(
          exception.toString(),
          equals('AudioConversionException: Unknown error'),
        );
      });
    });

    group('convertM4aToWav', () {
      test('returns error when input file does not exist', () async {
        final result = await AudioFormatConverter.convertM4aToWav(
          '/nonexistent/path/audio.m4a',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Input file does not exist'));
        expect(result.outputPath, isNull);
      });

      // Note: Actual conversion tests require integration testing since
      // FFmpegKit is a native plugin that isn't available in unit tests.
      // The conversion logic is tested indirectly through integration tests.
    });

    group('deleteConvertedFile', () {
      test('deletes file when it exists', () async {
        final tempDir = await getTemporaryDirectory();

        // Ensure temp directory exists
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final testFile = File('${tempDir.path}/test_delete.wav');
        await testFile.writeAsString('test content');

        expect(testFile.existsSync(), isTrue);

        await AudioFormatConverter.deleteConvertedFile(testFile.path);

        expect(testFile.existsSync(), isFalse);
      });

      test('handles null path gracefully', () async {
        // Should not throw
        await AudioFormatConverter.deleteConvertedFile(null);
      });

      test('handles non-existent file gracefully', () async {
        // Should not throw
        await AudioFormatConverter.deleteConvertedFile(
          '/nonexistent/path/file.wav',
        );
      });
    });
  });
}
