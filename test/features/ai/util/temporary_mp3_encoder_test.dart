import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/temporary_mp3_encoder.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'lotti_temporary_mp3_encoder_test_',
    );
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'decodes M4A, normalizes PCM samples, and returns temporary MP3',
    () async {
      final wavBytes = _pcm16Wav(
        sampleRate: 16000,
        samples: [-32768, 0, 32767],
      );
      final encoders = <_RecordingMp3FrameEncoder>[];
      var converterCalled = false;

      final file = await encodeAudioBytesToTemporaryMp3(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: temporaryDirectory,
        fileStem: 'converted',
        m4aToWavConverter: (bytes) async {
          converterCalled = true;
          expect(bytes, [1, 2, 3]);
          return wavBytes;
        },
        encoderFactory: _recordingEncoderFactory(encoders),
      );

      expect(converterCalled, isTrue);
      expect(file.path, endsWith('converted.mp3'));
      expect(file.readAsBytesSync(), [0xA0, 0xFF]);
      expect(encoders, hasLength(1));
      final encoder = encoders.single;
      expect(encoder.sampleRate, 16000);
      expect(encoder.numChannels, 1);
      expect(encoder.bitRate, 64);
      expect(encoder.closed, isTrue);
      expect(encoder.leftChunks.single[0], -1);
      expect(encoder.leftChunks.single[1], 0);
      expect(encoder.leftChunks.single[2], closeTo(0.99997, 0.00001));
      expect(encoder.rightChunks.single, isNull);
    },
  );

  test('reuses WAV input without invoking the M4A decoder', () async {
    final wavBytes = _pcm16Wav(sampleRate: 8000, samples: [0, 1]);
    var converterCalled = false;

    final file = await encodeAudioBytesToTemporaryMp3(
      wavBytes,
      temporaryDirectory: temporaryDirectory,
      fileStem: 'wav-input',
      m4aToWavConverter: (_) async {
        converterCalled = true;
        throw StateError('WAV input must bypass M4A decoding');
      },
      encoderFactory: _recordingEncoderFactory([]),
    );

    expect(converterCalled, isFalse);
    expect(file.readAsBytesSync(), [0xA0, 0xFF]);
  });

  test('passes normalized stereo channels to the encoder', () async {
    final wavBytes = _pcm16Wav(
      sampleRate: 44100,
      numChannels: 2,
      samples: [-32768, 32767, 16384, -16384],
    );
    final encoders = <_RecordingMp3FrameEncoder>[];

    await encodeWavBytesToTemporaryMp3(
      wavBytes,
      temporaryDirectory: temporaryDirectory,
      encoderFactory: _recordingEncoderFactory(encoders),
    );

    final encoder = encoders.single;
    expect(encoder.numChannels, 2);
    expect(encoder.leftChunks.single, [-1, 0.5]);
    expect(encoder.rightChunks.single, [closeTo(0.99997, 0.00001), -0.5]);
  });

  test('encodes audio longer than two minutes in bounded chunks', () async {
    const sampleRate = 8000;
    const durationSeconds = 121;
    const frameCount = sampleRate * durationSeconds;
    final wavBytes = _pcm16Wav(
      sampleRate: sampleRate,
      frameCount: frameCount,
    );
    final encoders = <_RecordingMp3FrameEncoder>[];

    final file = await encodeWavBytesToTemporaryMp3(
      wavBytes,
      temporaryDirectory: temporaryDirectory,
      fileStem: 'long-recording',
      encoderFactory: _recordingEncoderFactory(encoders),
    );

    final encoder = encoders.single;
    expect(encoder.leftChunks, hasLength(durationSeconds));
    expect(
      encoder.leftChunks.fold<int>(0, (sum, samples) => sum + samples.length),
      frameCount,
    );
    expect(
      encoder.leftChunks.map((samples) => samples.length),
      everyElement(lessThanOrEqualTo(sampleRate)),
    );
    expect(file.lengthSync(), lessThan(wavBytes.length ~/ 1000));
  });

  test('removes a partial MP3 and closes LAME when encoding fails', () async {
    final wavBytes = _pcm16Wav(
      sampleRate: 2,
      frameCount: 5,
    );
    late _RecordingMp3FrameEncoder encoder;
    final outputFile = File('${temporaryDirectory.path}/failed.mp3');

    await expectLater(
      encodeWavBytesToTemporaryMp3(
        wavBytes,
        temporaryDirectory: temporaryDirectory,
        fileStem: 'failed',
        encoderFactory:
            ({
              required sampleRate,
              required numChannels,
              required bitRate,
            }) {
              return encoder = _RecordingMp3FrameEncoder(
                sampleRate: sampleRate,
                numChannels: numChannels,
                bitRate: bitRate,
                failAtEncodeCall: 2,
              );
            },
      ),
      throwsA(
        isA<TemporaryMp3EncodingException>().having(
          (error) => error.toString(),
          'message',
          contains('synthetic LAME failure'),
        ),
      ),
    );

    expect(encoder.closed, isTrue);
    expect(outputFile.existsSync(), isFalse);
  });

  test('surfaces decoder failures as MP3 preparation errors', () async {
    await expectLater(
      encodeAudioBytesToTemporaryMp3(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: temporaryDirectory,
        m4aToWavConverter: (_) async =>
            throw Exception('GStreamer AAC decoder unavailable'),
        encoderFactory: _recordingEncoderFactory([]),
      ),
      throwsA(
        isA<TemporaryMp3EncodingException>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('Failed to prepare temporary MP3 audio'),
            contains('GStreamer AAC decoder unavailable'),
          ),
        ),
      ),
    );
  });

  test('rejects invalid WAV output before creating a file', () async {
    final outputFile = File('${temporaryDirectory.path}/invalid.mp3');

    await expectLater(
      encodeWavBytesToTemporaryMp3(
        Uint8List.fromList([1, 2, 3]),
        temporaryDirectory: temporaryDirectory,
        fileStem: 'invalid',
        encoderFactory: _recordingEncoderFactory([]),
      ),
      throwsA(
        isA<TemporaryMp3EncodingException>().having(
          (error) => error.message,
          'message',
          contains('not a RIFF/WAVE file'),
        ),
      ),
    );
    expect(outputFile.existsSync(), isFalse);
  });

  test('rejects empty audio and invalid bit rates', () async {
    await expectLater(
      encodeAudioBytesToTemporaryMp3(
        Uint8List(0),
        temporaryDirectory: temporaryDirectory,
        encoderFactory: _recordingEncoderFactory([]),
      ),
      throwsA(isA<TemporaryMp3EncodingException>()),
    );

    expect(
      () => encodeWavBytesToTemporaryMp3(
        _pcm16Wav(sampleRate: 8000, samples: [0]),
        temporaryDirectory: temporaryDirectory,
        bitRate: 0,
        encoderFactory: _recordingEncoderFactory([]),
      ),
      throwsArgumentError,
    );
  });
}

Mp3FrameEncoderFactory _recordingEncoderFactory(
  List<_RecordingMp3FrameEncoder> encoders,
) {
  return ({
    required int sampleRate,
    required int numChannels,
    required int bitRate,
  }) {
    final encoder = _RecordingMp3FrameEncoder(
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitRate: bitRate,
    );
    encoders.add(encoder);
    return encoder;
  };
}

final class _RecordingMp3FrameEncoder implements Mp3FrameEncoder {
  _RecordingMp3FrameEncoder({
    required this.sampleRate,
    required this.numChannels,
    required this.bitRate,
    this.failAtEncodeCall,
  });

  final int sampleRate;
  final int numChannels;
  final int bitRate;
  final int? failAtEncodeCall;
  final leftChunks = <Float64List>[];
  final rightChunks = <Float64List?>[];
  bool closed = false;

  @override
  Future<Uint8List> encode({
    required Float64List leftChannel,
    Float64List? rightChannel,
  }) async {
    leftChunks.add(Float64List.fromList(leftChannel));
    rightChunks.add(
      rightChannel == null ? null : Float64List.fromList(rightChannel),
    );
    if (leftChunks.length == failAtEncodeCall) {
      throw Exception('synthetic LAME failure');
    }
    return Uint8List.fromList([0xA0]);
  }

  @override
  Future<Uint8List> flush() async => Uint8List.fromList([0xFF]);

  @override
  Future<void> close() async {
    closed = true;
  }
}

Uint8List _pcm16Wav({
  required int sampleRate,
  int numChannels = 1,
  int? frameCount,
  List<int>? samples,
}) {
  final resolvedFrameCount = frameCount ?? samples!.length ~/ numChannels;
  final dataLength = resolvedFrameCount * numChannels * 2;
  final wav = ByteData(44 + dataLength)
    ..setUint32(0, 0x52494646)
    ..setUint32(4, 36 + dataLength, Endian.little)
    ..setUint32(8, 0x57415645)
    ..setUint32(12, 0x666D7420)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, numChannels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * numChannels * 2, Endian.little)
    ..setUint16(32, numChannels * 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461)
    ..setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < resolvedFrameCount * numChannels; index++) {
    wav.setInt16(44 + index * 2, samples?[index] ?? 0, Endian.little);
  }
  return wav.buffer.asUint8List();
}
