import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_lame/flutter_lame.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Converts encoded M4A bytes to PCM WAV bytes without changing the archive.
typedef M4aBytesToWavConverter = Future<Uint8List> Function(Uint8List bytes);

/// Creates the sample encoder used to emit MP3 frames.
typedef Mp3FrameEncoderFactory =
    Mp3FrameEncoder Function({
      required int sampleRate,
      required int numChannels,
      required int bitRate,
    });

/// Minimal encoder surface used by the temporary-file pipeline.
abstract interface class Mp3FrameEncoder {
  /// Encodes one chunk of normalized PCM samples.
  Future<Uint8List> encode({
    required Float64List leftChannel,
    Float64List? rightChannel,
  });

  /// Flushes the encoder's buffered MP3 frames.
  Future<Uint8List> flush();

  /// Releases the encoder and its worker isolate.
  Future<void> close();
}

/// Error raised when temporary MP3 preparation fails.
final class TemporaryMp3EncodingException implements Exception {
  /// Creates an encoding error with the original [cause].
  const TemporaryMp3EncodingException(this.message, {this.cause});

  /// Human-readable failure detail.
  final String message;

  /// Original decoder, encoder, or filesystem failure.
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

/// Converts M4A or WAV bytes to a temporary MP3 file for API transmission.
///
/// M4A input is first decoded to PCM WAV through Lotti's cross-platform native
/// decoder. The archived source bytes are never modified. The caller owns the
/// returned file and must delete it after the API request completes.
Future<File> encodeAudioBytesToTemporaryMp3(
  Uint8List sourceBytes, {
  M4aBytesToWavConverter? m4aToWavConverter,
  Mp3FrameEncoderFactory? encoderFactory,
  Directory? temporaryDirectory,
  String? fileStem,
  int bitRate = 64,
}) async {
  if (sourceBytes.isEmpty) {
    throw const TemporaryMp3EncodingException('Audio data cannot be empty');
  }

  try {
    final wavBytes = _isWavAudio(sourceBytes)
        ? sourceBytes
        : await (m4aToWavConverter ?? convertM4aBytesToTemporaryWav)(
            sourceBytes,
          );
    return await encodeWavBytesToTemporaryMp3(
      wavBytes,
      encoderFactory: encoderFactory,
      temporaryDirectory: temporaryDirectory,
      fileStem: fileStem,
      bitRate: bitRate,
    );
  } on TemporaryMp3EncodingException {
    rethrow;
  } on Exception catch (error) {
    throw TemporaryMp3EncodingException(
      'Failed to prepare temporary MP3 audio',
      cause: error,
    );
  }
}

/// Encodes PCM WAV bytes to a temporary MP3 file in bounded sample chunks.
///
/// The WAV parser accepts mono or stereo PCM and IEEE-float samples, including
/// WAVE_FORMAT_EXTENSIBLE files. Only one second of samples per channel is
/// materialized at a time, so long recordings do not require a second full PCM
/// copy in memory. Partial MP3 files are removed before failures propagate.
Future<File> encodeWavBytesToTemporaryMp3(
  Uint8List wavBytes, {
  Mp3FrameEncoderFactory? encoderFactory,
  Directory? temporaryDirectory,
  String? fileStem,
  int bitRate = 64,
}) async {
  if (bitRate <= 0) {
    throw ArgumentError.value(bitRate, 'bitRate', 'must be positive');
  }

  final wav = _WavPcmSource.parse(wavBytes);
  final directory = temporaryDirectory ?? Directory.systemTemp;
  final stem = fileStem ?? 'lotti_voxtral_${const Uuid().v4()}';
  final outputFile = File(p.join(directory.path, '$stem.mp3'));
  final createEncoder = encoderFactory ?? _createBundledLameEncoder;

  Mp3FrameEncoder? encoder;
  IOSink? sink;
  var completed = false;
  try {
    await directory.create(recursive: true);
    sink = outputFile.openWrite();
    encoder = createEncoder(
      sampleRate: wav.sampleRate,
      numChannels: wav.numChannels,
      bitRate: bitRate,
    );

    for (var frameOffset = 0; frameOffset < wav.frameCount;) {
      final frameLength = math.min(
        wav.sampleRate,
        wav.frameCount - frameOffset,
      );
      final leftChannel = wav.readChannel(
        channel: 0,
        frameOffset: frameOffset,
        frameLength: frameLength,
      );
      final rightChannel = wav.numChannels == 2
          ? wav.readChannel(
              channel: 1,
              frameOffset: frameOffset,
              frameLength: frameLength,
            )
          : null;
      sink.add(
        await encoder.encode(
          leftChannel: leftChannel,
          rightChannel: rightChannel,
        ),
      );
      frameOffset += frameLength;
    }

    sink.add(await encoder.flush());
    await sink.flush();
    await sink.close();
    sink = null;
    await encoder.close();
    encoder = null;

    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      throw const TemporaryMp3EncodingException(
        'LAME completed without producing MP3 data',
      );
    }
    completed = true;
    return outputFile;
  } on TemporaryMp3EncodingException {
    rethrow;
  } on Exception catch (error) {
    throw TemporaryMp3EncodingException(
      'Failed to encode temporary MP3 audio',
      cause: error,
    );
  } finally {
    try {
      await encoder?.close();
    } on Exception {
      // The primary encoding failure is more useful than a close failure.
    }
    try {
      await sink?.close();
    } on Exception {
      // The primary encoding failure is more useful than a close failure.
    }
    if (!completed) {
      try {
        if (outputFile.existsSync()) outputFile.deleteSync();
      } on FileSystemException {
        // Partial-file cleanup is best-effort.
      }
    }
  }
}

Mp3FrameEncoder _createBundledLameEncoder({
  required int sampleRate,
  required int numChannels,
  required int bitRate,
}) => _FlutterLameFrameEncoder(
  sampleRate: sampleRate,
  numChannels: numChannels,
  bitRate: bitRate,
);

final class _FlutterLameFrameEncoder implements Mp3FrameEncoder {
  _FlutterLameFrameEncoder({
    required int sampleRate,
    required int numChannels,
    required int bitRate,
  }) : _encoder = LameMp3Encoder(
         sampleRate: sampleRate,
         numChannels: numChannels,
         bitRate: bitRate,
       );

  final LameMp3Encoder _encoder;

  @override
  Future<Uint8List> encode({
    required Float64List leftChannel,
    Float64List? rightChannel,
  }) => _encoder.encodeDouble(
    leftChannel: leftChannel,
    rightChannel: rightChannel,
  );

  @override
  Future<Uint8List> flush() => _encoder.flush();

  @override
  Future<void> close() async {
    await _encoder.close();
  }
}

bool _isWavAudio(Uint8List bytes) =>
    bytes.length >= 12 &&
    _hasFourCc(bytes, 0, 0x52, 0x49, 0x46, 0x46) &&
    _hasFourCc(bytes, 8, 0x57, 0x41, 0x56, 0x45);

bool _hasFourCc(
  Uint8List bytes,
  int offset,
  int first,
  int second,
  int third,
  int fourth,
) =>
    bytes[offset] == first &&
    bytes[offset + 1] == second &&
    bytes[offset + 2] == third &&
    bytes[offset + 3] == fourth;

enum _WavSampleEncoding { pcm, ieeeFloat }

final class _WavPcmSource {
  const _WavPcmSource({
    required this.bytes,
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.dataOffset,
    required this.frameCount,
    required this.sampleEncoding,
  });

  factory _WavPcmSource.parse(Uint8List bytes) {
    if (!_isWavAudio(bytes)) {
      throw const TemporaryMp3EncodingException(
        'Audio decoder output is not a RIFF/WAVE file',
      );
    }

    final data = ByteData.sublistView(bytes);
    int? formatOffset;
    int? formatLength;
    int? audioDataOffset;
    int? audioDataLength;
    var chunkOffset = 12;
    while (chunkOffset + 8 <= bytes.length) {
      final chunkLength = data.getUint32(chunkOffset + 4, Endian.little);
      final contentOffset = chunkOffset + 8;
      final contentEnd = contentOffset + chunkLength;
      if (contentEnd > bytes.length) {
        throw const TemporaryMp3EncodingException(
          'WAV contains a truncated chunk',
        );
      }
      if (_hasFourCc(bytes, chunkOffset, 0x66, 0x6D, 0x74, 0x20)) {
        formatOffset = contentOffset;
        formatLength = chunkLength;
      } else if (_hasFourCc(
        bytes,
        chunkOffset,
        0x64,
        0x61,
        0x74,
        0x61,
      )) {
        audioDataOffset = contentOffset;
        audioDataLength = chunkLength;
      }
      chunkOffset = contentEnd + (chunkLength.isOdd ? 1 : 0);
    }

    if (formatOffset == null || formatLength == null || formatLength < 16) {
      throw const TemporaryMp3EncodingException(
        'WAV is missing a valid fmt chunk',
      );
    }
    if (audioDataOffset == null ||
        audioDataLength == null ||
        audioDataLength == 0) {
      throw const TemporaryMp3EncodingException(
        'WAV is missing non-empty PCM data',
      );
    }

    var audioFormat = data.getUint16(formatOffset, Endian.little);
    final numChannels = data.getUint16(formatOffset + 2, Endian.little);
    final sampleRate = data.getUint32(formatOffset + 4, Endian.little);
    final blockAlign = data.getUint16(formatOffset + 12, Endian.little);
    final bitsPerSample = data.getUint16(formatOffset + 14, Endian.little);
    if (audioFormat == 0xFFFE) {
      if (formatLength < 40) {
        throw const TemporaryMp3EncodingException(
          'WAVE_FORMAT_EXTENSIBLE fmt chunk is truncated',
        );
      }
      audioFormat = data.getUint16(formatOffset + 24, Endian.little);
    }

    final sampleEncoding = switch (audioFormat) {
      1 => _WavSampleEncoding.pcm,
      3 => _WavSampleEncoding.ieeeFloat,
      _ => throw TemporaryMp3EncodingException(
        'Unsupported WAV sample format: $audioFormat',
      ),
    };
    if (numChannels < 1 || numChannels > 2) {
      throw TemporaryMp3EncodingException(
        'LAME supports mono or stereo WAV input, got $numChannels channels',
      );
    }
    if (sampleRate == 0) {
      throw const TemporaryMp3EncodingException(
        'WAV sample rate must be positive',
      );
    }
    final supportedBits = switch (sampleEncoding) {
      _WavSampleEncoding.pcm => const {8, 16, 24, 32},
      _WavSampleEncoding.ieeeFloat => const {32, 64},
    };
    if (!supportedBits.contains(bitsPerSample)) {
      throw TemporaryMp3EncodingException(
        'Unsupported WAV bit depth: $bitsPerSample',
      );
    }
    final bytesPerSample = bitsPerSample ~/ 8;
    if (blockAlign < numChannels * bytesPerSample) {
      throw const TemporaryMp3EncodingException(
        'WAV block alignment is smaller than one sample frame',
      );
    }

    return _WavPcmSource(
      bytes: data,
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitsPerSample: bitsPerSample,
      blockAlign: blockAlign,
      dataOffset: audioDataOffset,
      frameCount: audioDataLength ~/ blockAlign,
      sampleEncoding: sampleEncoding,
    );
  }

  final ByteData bytes;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final int blockAlign;
  final int dataOffset;
  final int frameCount;
  final _WavSampleEncoding sampleEncoding;

  Float64List readChannel({
    required int channel,
    required int frameOffset,
    required int frameLength,
  }) {
    final samples = Float64List(frameLength);
    final bytesPerSample = bitsPerSample ~/ 8;
    for (var index = 0; index < frameLength; index++) {
      final sampleOffset =
          dataOffset +
          (frameOffset + index) * blockAlign +
          channel * bytesPerSample;
      samples[index] = _readNormalizedSample(sampleOffset);
    }
    return samples;
  }

  double _readNormalizedSample(int offset) {
    if (sampleEncoding == _WavSampleEncoding.ieeeFloat) {
      final sample = bitsPerSample == 32
          ? bytes.getFloat32(offset, Endian.little)
          : bytes.getFloat64(offset, Endian.little);
      if (!sample.isFinite) return 0;
      return sample.clamp(-1.0, 1.0);
    }

    return switch (bitsPerSample) {
      8 => (bytes.getUint8(offset) - 128) / 128,
      16 => bytes.getInt16(offset, Endian.little) / 32768,
      24 => _readSignedInt24(offset) / 8388608,
      32 => bytes.getInt32(offset, Endian.little) / 2147483648,
      _ => throw StateError('Validated WAV bit depth changed unexpectedly'),
    };
  }

  int _readSignedInt24(int offset) {
    var sample =
        bytes.getUint8(offset) |
        (bytes.getUint8(offset + 1) << 8) |
        (bytes.getUint8(offset + 2) << 16);
    if ((sample & 0x800000) != 0) sample |= ~0xFFFFFF;
    return sample;
  }
}
