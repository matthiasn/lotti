import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/voiced_text_track.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';

const _rate = 16000;

/// A clip as the on-device voice writes it: 0.5 s of silence, then 1 s of a
/// tone.
Uint8List _voiceClip() => encodeWavBytes([
  for (var i = 0; i < _rate ~/ 2; i++) 0.0,
  for (var i = 0; i < _rate; i++) 0.5 * math.sin(i * 2 * math.pi * 220 / _rate),
], _rate);

Future<Uint8List> Function(String) _serving(Uint8List bytes) =>
    (_) async => bytes;

void main() {
  group('loadSpokenTrack', () {
    test('times the words by the clip it reads', () async {
      final track = await loadSpokenTrack(
        '/clips/a.wav',
        'Good morning',
        readBytes: _serving(_voiceClip()),
      );

      expect(track, isA<VoicedTextTrack>());
      final voiced = track as VoicedTextTrack;
      expect(voiced.envelope.length.inMilliseconds, closeTo(1500, 20));
      // Silent first half: the lips stay closed until the voice starts.
      expect(track.mouthAt(const Duration(milliseconds: 200)).open, 0);
      expect(
        track.loudnessAt(const Duration(milliseconds: 1000)),
        greaterThan(0.5),
      );
    });

    test('reads the clip named by the path it is given', () async {
      final requested = <String>[];
      await loadSpokenTrack(
        '/clips/b.wav',
        'Hi',
        readBytes: (path) async {
          requested.add(path);
          return _voiceClip();
        },
      );
      expect(requested, ['/clips/b.wav']);
    });

    test('reads a real file when no reader is given', () async {
      final dir = Directory.systemTemp.createTempSync('spoken_track_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/clip.wav')..writeAsBytesSync(_voiceClip());

      final track = await loadSpokenTrack(file.path, 'Hi');

      expect(track, isA<VoicedTextTrack>());
    });

    test('falls back to the words when the clip is already gone', () async {
      final track = await loadSpokenTrack(
        '/no/such/clip.wav',
        'Good morning',
      );

      expect(track, isA<TextLipSync>());
      expect(track.length, TextLipSync('Good morning').length);
    });

    test('falls back to the words when the clip is not a WAV', () async {
      final track = await loadSpokenTrack(
        '/clips/c.mp3',
        'Good morning',
        readBytes: _serving(Uint8List.fromList([1, 2, 3, 4])),
      );

      expect(track, isA<TextLipSync>());
    });

    test('lets an unexpected failure through', () async {
      await expectLater(
        loadSpokenTrack(
          '/clips/d.wav',
          'Hi',
          readBytes: (_) async => throw StateError('disk on fire'),
        ),
        throwsStateError,
      );
    });
  });

  test('the provider hands out loadSpokenTrack', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(spokenTrackLoaderProvider), loadSpokenTrack);
  });
}
