import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.matthiasn.lotti/audio_converter');

  group('AudioConverterChannel', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns true on successful conversion', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'convertWavToM4a');
        final args = call.arguments as Map<dynamic, dynamic>;
        expect(args['inputPath'], '/tmp/input.wav');
        expect(args['outputPath'], '/tmp/output.m4a');
        return true;
      });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isTrue);
    });

    test('returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'CONVERSION_ERROR',
          message: 'Failed',
        );
      });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
    });

    test('returns false on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
    });

    test('returns false when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return null;
      });

      final result = await AudioConverterChannel.convertWavToM4a(
        inputPath: '/tmp/input.wav',
        outputPath: '/tmp/output.m4a',
      );
      expect(result, isFalse);
    });
  });
}
