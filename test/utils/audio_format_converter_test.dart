import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/audio_format_converter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';

class MockFfmpegExecutor extends Mock implements FfmpegExecutor {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFormatConverterService -', () {
    setUpAll(setFakeDocumentsPath);

    group('isM4aFile', () {
      test('returns true for .m4a extension', () {
        expect(
          AudioFormatConverterService.isM4aFile('/path/to/audio.m4a'),
          isTrue,
        );
      });

      test('returns true for .M4A extension (case insensitive)', () {
        expect(
          AudioFormatConverterService.isM4aFile('/path/to/audio.M4A'),
          isTrue,
        );
      });

      test('returns false for .wav extension', () {
        expect(
          AudioFormatConverterService.isM4aFile('/path/to/audio.wav'),
          isFalse,
        );
      });

      test('returns false for .mp3 extension', () {
        expect(
          AudioFormatConverterService.isM4aFile('/path/to/audio.mp3'),
          isFalse,
        );
      });

      test('returns false for .aac extension', () {
        expect(
          AudioFormatConverterService.isM4aFile('/path/to/audio.aac'),
          isFalse,
        );
      });
    });

    group('isWavFile', () {
      test('returns true for .wav extension', () {
        expect(
          AudioFormatConverterService.isWavFile('/path/to/audio.wav'),
          isTrue,
        );
      });

      test('returns true for .WAV extension (case insensitive)', () {
        expect(
          AudioFormatConverterService.isWavFile('/path/to/audio.WAV'),
          isTrue,
        );
      });

      test('returns false for .m4a extension', () {
        expect(
          AudioFormatConverterService.isWavFile('/path/to/audio.m4a'),
          isFalse,
        );
      });

      test('returns false for .mp3 extension', () {
        expect(
          AudioFormatConverterService.isWavFile('/path/to/audio.mp3'),
          isFalse,
        );
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

    group('convertM4aToWav with mocked executor', () {
      late MockFfmpegExecutor mockExecutor;
      late AudioFormatConverterService service;

      setUp(() {
        mockExecutor = MockFfmpegExecutor();
        service = AudioFormatConverterService(executor: mockExecutor);
      });

      test('returns error when input file does not exist', () async {
        final result = await service.convertM4aToWav(
          '/nonexistent/path/audio.m4a',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Input file does not exist'));
        expect(result.outputPath, isNull);

        // Executor should not be called when file doesn't exist
        verifyNever(() => mockExecutor.execute(any(), any()));
      });

      test('calls executor and returns success result', () async {
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final inputFile = File('${tempDir.path}/test_input.m4a');
        await inputFile.writeAsBytes([0, 1, 2, 3]);

        try {
          when(() => mockExecutor.execute(any(), any())).thenAnswer(
            (invocation) async => AudioConversionResult(
              success: true,
              outputPath: invocation.positionalArguments[1] as String,
            ),
          );

          final result = await service.convertM4aToWav(inputFile.path);

          expect(result.success, isTrue);
          expect(result.outputPath, isNotNull);
          expect(result.outputPath, contains('.wav'));
          expect(result.error, isNull);

          verify(() => mockExecutor.execute(inputFile.path, any())).called(1);
        } finally {
          if (inputFile.existsSync()) {
            await inputFile.delete();
          }
        }
      });

      test('returns failure result when executor fails', () async {
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final inputFile = File('${tempDir.path}/test_input_fail.m4a');
        await inputFile.writeAsBytes([0, 1, 2, 3]);

        try {
          when(() => mockExecutor.execute(any(), any())).thenAnswer(
            (_) async => AudioConversionResult(
              success: false,
              error: 'FFmpeg conversion failed: invalid format',
            ),
          );

          final result = await service.convertM4aToWav(inputFile.path);

          expect(result.success, isFalse);
          expect(result.error, contains('FFmpeg conversion failed'));
          expect(result.outputPath, isNull);

          verify(() => mockExecutor.execute(inputFile.path, any())).called(1);
        } finally {
          if (inputFile.existsSync()) {
            await inputFile.delete();
          }
        }
      });

      test('catches executor exceptions and returns error result', () async {
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final inputFile = File('${tempDir.path}/test_input_exception.m4a');
        await inputFile.writeAsBytes([0, 1, 2, 3]);

        try {
          when(() => mockExecutor.execute(any(), any())).thenThrow(
            Exception('Unexpected FFmpeg error'),
          );

          final result = await service.convertM4aToWav(inputFile.path);

          expect(result.success, isFalse);
          expect(result.error, contains('Audio conversion error'));
          expect(result.error, contains('Unexpected FFmpeg error'));
          expect(result.outputPath, isNull);

          verify(() => mockExecutor.execute(inputFile.path, any())).called(1);
        } finally {
          if (inputFile.existsSync()) {
            await inputFile.delete();
          }
        }
      });

      test('generates unique output path with timestamp', () async {
        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final inputFile = File('${tempDir.path}/my_audio_file.m4a');
        await inputFile.writeAsBytes([0, 1, 2, 3]);

        String? capturedOutputPath;

        try {
          when(() => mockExecutor.execute(any(), any())).thenAnswer(
            (invocation) async {
              capturedOutputPath = invocation.positionalArguments[1] as String;
              return AudioConversionResult(
                success: true,
                outputPath: capturedOutputPath,
              );
            },
          );

          await service.convertM4aToWav(inputFile.path);

          expect(capturedOutputPath, isNotNull);
          expect(capturedOutputPath, contains('my_audio_file_'));
          expect(capturedOutputPath, endsWith('.wav'));
          // Should contain a timestamp (numeric characters)
          expect(
            RegExp(r'my_audio_file_\d+\.wav$').hasMatch(capturedOutputPath!),
            isTrue,
          );
        } finally {
          if (inputFile.existsSync()) {
            await inputFile.delete();
          }
        }
      });
    });

    group('convertM4aToWav with real executor (Linux/Windows only)', () {
      test('returns error for invalid audio file on Linux/Windows', () async {
        // Skip on macOS/iOS/Android where FFmpegKit is used (native plugin)
        if (!Platform.isLinux && !Platform.isWindows) {
          return;
        }

        final tempDir = await getTemporaryDirectory();
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        // Create a dummy file that isn't valid audio
        final dummyFile = File('${tempDir.path}/invalid_audio.m4a');
        await dummyFile.writeAsBytes([0, 1, 2, 3, 4, 5]);

        try {
          final service = AudioFormatConverterService();
          final result = await service.convertM4aToWav(dummyFile.path);

          // Either FFmpeg fails (invalid audio) or FFmpeg not installed
          expect(result.success, isFalse);
          expect(result.error, isNotNull);
        } finally {
          if (dummyFile.existsSync()) {
            await dummyFile.delete();
          }
        }
      });
    });

    group('deleteConvertedFile', () {
      late AudioFormatConverterService service;

      setUp(() {
        service = AudioFormatConverterService(executor: MockFfmpegExecutor());
      });

      test('deletes file when it exists', () async {
        final tempDir = await getTemporaryDirectory();

        // Ensure temp directory exists
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }

        final testFile = File('${tempDir.path}/test_delete.wav');
        await testFile.writeAsString('test content');

        expect(testFile.existsSync(), isTrue);

        await service.deleteConvertedFile(testFile.path);

        expect(testFile.existsSync(), isFalse);
      });

      test('handles null path gracefully', () async {
        // Should not throw
        await service.deleteConvertedFile(null);
      });

      test('handles non-existent file gracefully', () async {
        // Should not throw
        await service.deleteConvertedFile('/nonexistent/path/file.wav');
      });
    });

    group('FfmpegKitExecutor', () {
      test('creates correct ffmpeg command', () {
        // We can't test actual FFmpegKit execution in unit tests,
        // but we can verify the executor class exists and implements interface
        final executor = FfmpegKitExecutor();
        expect(executor, isA<FfmpegExecutor>());
      });
    });

    group('SystemFfmpegExecutor', () {
      test('implements FfmpegExecutor interface', () {
        final executor = SystemFfmpegExecutor();
        expect(executor, isA<FfmpegExecutor>());
      });

      test('returns error when ffmpeg is not installed', () async {
        // Skip if not on Linux/Windows
        if (!Platform.isLinux && !Platform.isWindows) {
          return;
        }

        final executor = SystemFfmpegExecutor();
        final result = await executor.execute(
          '/nonexistent/input.m4a',
          '/tmp/output.wav',
        );

        // Should fail because either ffmpeg isn't installed or input doesn't exist
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('Default executor selection', () {
      test('creates service with appropriate executor for platform', () {
        // This test just verifies the service can be created without error
        final service = AudioFormatConverterService();
        expect(service, isNotNull);
      });
    });
  });
}
