import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/voiced_text_track.dart';

/// Builds the mouth for a clip being played: [clipPath] is the WAV, [text]
/// the words it speaks.
typedef SpokenTrackLoader =
    Future<MouthTrack> Function(String clipPath, String text);

/// The loader `CompanionSpeaker` uses; a test swaps it for one that needs no
/// file.
final spokenTrackLoaderProvider = Provider<SpokenTrackLoader>(
  (ref) => loadSpokenTrack,
  name: 'spokenTrackLoaderProvider',
);

/// The mouth for the on-device voice speaking [text] from the WAV at
/// [clipPath]: the words' shapes, timed and gated by the clip's loudness
/// ([VoicedTextTrack]).
///
/// The loudness, and the pinning of the voice's pauses to the words', are
/// computed off the UI isolate, because a long summary is minutes of samples. If the clip cannot be read (deleted because playback
/// already ended) or is not the 16-bit PCM the voice writes, the mouth falls
/// back to the words alone ([TextLipSync]). The voice still plays, so she
/// keeps talking, only less exactly in time with it.
Future<MouthTrack> loadSpokenTrack(
  String clipPath,
  String text, {
  Future<Uint8List> Function(String path)? readBytes,
}) async {
  try {
    final bytes = await (readBytes ?? _readFile)(clipPath);
    return await Isolate.run(
      () => VoicedTextTrack(SpeechEnvelope.fromWav(bytes), text),
    );
  } on FileSystemException {
    return TextLipSync(text);
  } on FormatException {
    return TextLipSync(text);
  }
}

Future<Uint8List> _readFile(String path) => File(path).readAsBytes();
