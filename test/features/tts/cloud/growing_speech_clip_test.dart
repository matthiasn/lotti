import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/cloud/growing_speech_clip.dart';

/// A streamed WAV header: 16-bit mono 24 kHz, its lengths not known yet.
Uint8List _header() {
  final header = ByteData(GrowingSpeechClip.headerBytes);
  void tag(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 0xFFFFFFFF, Endian.little);
  tag(8, 'WAVEfmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 24000, Endian.little)
    ..setUint32(28, 48000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, 0xFFFFFFFF, Endian.little);
  return header.buffer.asUint8List();
}

Uint8List _samples(int bytes, [int value = 7]) =>
    Uint8List(bytes)..fillRange(0, bytes, value);

void main() {
  late Directory temp;
  late File file;
  late StreamController<Uint8List> audio;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('growing_clip_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    file = File('${temp.path}/clip.wav');
    audio = StreamController<Uint8List>();
  });

  // Whether [future] has completed once everything already under way ran.
  Future<bool> settled(Future<void> future) async {
    var done = false;
    future.then((_) => done = true).ignore();
    await pumpEventQueue();
    return done;
  }

  test('is playable once the lead is written, long before it is whole, and '
      'every byte written is in the file as it arrives', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    const half = (GrowingSpeechClip.playableBytes ~/ 2) + 1;

    audio.add(Uint8List.fromList([..._header(), ..._samples(half - 44)]));
    expect(await settled(clip.playable), isFalse);

    audio.add(_samples(half));
    await clip.playable;
    expect(clip.isComplete, isFalse);
    expect(clip.hasAudio, isTrue);
    expect(file.lengthSync(), 2 * half);
    expect(await settled(clip.done), isFalse);

    await audio.close();
    await clip.done;
    expect(clip.isComplete, isTrue);
    expect(clip.failure, isNull);
  });

  test('once it is whole its header says how long it is, as every reader '
      'of a WAV expects', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    audio
      ..add(_header())
      ..add(_samples(1000));
    await audio.close();
    await clip.done;

    final bytes = file.readAsBytesSync();
    final view = ByteData.sublistView(bytes);
    expect(bytes, hasLength(1044));
    expect(view.getUint32(4, Endian.little), 1044 - 8);
    expect(view.getUint32(40, Endian.little), 1000);
    // Only the two lengths were touched.
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    expect(bytes.sublist(44), everyElement(7));
  });

  test('a clip shorter than the lead is playable when it ends', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    audio.add(Uint8List.fromList([..._header(), ..._samples(200)]));
    expect(await settled(clip.playable), isFalse);

    await audio.close();
    await clip.playable;
    expect(clip.hasAudio, isTrue);
    expect(clip.isComplete, isTrue);
  });

  test('a stream that ends without audio is no failure, and nothing to '
      'play', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    await audio.close();
    await clip.playable;
    await clip.done;

    expect(clip.hasAudio, isFalse);
    expect(clip.isComplete, isFalse);
    expect(clip.failure, isNull);
  });

  test('a stream that fails ends both waits without throwing, and says '
      'why; what was written stays, its header untouched', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    audio
      ..add(Uint8List.fromList([..._header(), ..._samples(200)]))
      ..addError(const SocketException('connection reset'));
    await clip.playable;
    await clip.done;

    expect(clip.failure!.error, isA<SocketException>());
    expect(clip.isComplete, isFalse);
    expect(clip.hasAudio, isTrue);
    expect(
      ByteData.sublistView(file.readAsBytesSync()).getUint32(40, Endian.little),
      0xFFFFFFFF,
    );
  });

  test('cancelled, it stops writing and both waits end: the file is left '
      'for its owner to delete', () async {
    final clip = await GrowingSpeechClip.start(file, audio.stream);
    audio.add(Uint8List.fromList([..._header(), ..._samples(200)]));
    await pumpEventQueue();

    await clip.cancel();
    await clip.playable;
    await clip.done;

    expect(clip.isComplete, isFalse);
    expect(audio.hasListener, isFalse);
    expect(file.existsSync(), isTrue);
    // Nothing more is written, whatever still arrives.
    final length = file.lengthSync();
    audio.add(_samples(500));
    await pumpEventQueue();
    expect(file.lengthSync(), length);
  });
}
