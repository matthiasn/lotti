import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/audio_note.dart';

void main() {
  group('AudioNote', () {
    final createdAt = DateTime(2024, 3, 15, 10, 30);
    const duration = Duration(minutes: 5, seconds: 30);

    test('holds all fields correctly', () {
      final note = AudioNote(
        createdAt: createdAt,
        audioFile: 'recording.m4a',
        audioDirectory: '/audio/2024',
        duration: duration,
      );

      expect(note.createdAt, createdAt);
      expect(note.audioFile, 'recording.m4a');
      expect(note.audioDirectory, '/audio/2024');
      expect(note.duration, duration);
    });

    test('JSON round-trip preserves all fields', () {
      final note = AudioNote(
        createdAt: createdAt,
        audioFile: 'clip.m4a',
        audioDirectory: '/recordings/march',
        duration: const Duration(seconds: 90),
      );

      final decoded = AudioNote.fromJson(
        jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.createdAt, note.createdAt);
      expect(decoded.audioFile, note.audioFile);
      expect(decoded.audioDirectory, note.audioDirectory);
      expect(decoded.duration, note.duration);
      expect(decoded, note);
    });

    test('JSON round-trip preserves sub-second precision in duration', () {
      final note = AudioNote(
        createdAt: createdAt,
        audioFile: 'precise.m4a',
        audioDirectory: '/audio',
        duration: const Duration(milliseconds: 3750),
      );

      final decoded = AudioNote.fromJson(
        jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.duration, const Duration(milliseconds: 3750));
    });

    test('equality distinguishes all fields', () {
      final a = AudioNote(
        createdAt: createdAt,
        audioFile: 'a.m4a',
        audioDirectory: '/dir',
        duration: duration,
      );
      final b = AudioNote(
        createdAt: createdAt,
        audioFile: 'a.m4a',
        audioDirectory: '/dir',
        duration: duration,
      );
      final c = AudioNote(
        createdAt: createdAt,
        audioFile: 'b.m4a',
        audioDirectory: '/dir',
        duration: duration,
      );

      expect(a, b);
      expect(a, isNot(c));
    });

    test('copyWith updates individual fields', () {
      final original = AudioNote(
        createdAt: createdAt,
        audioFile: 'old.m4a',
        audioDirectory: '/old',
        duration: duration,
      );

      final updated = original.copyWith(audioFile: 'new.m4a');

      expect(updated.audioFile, 'new.m4a');
      expect(updated.audioDirectory, '/old');
      expect(updated.duration, duration);
    });

    glados.Glados(
      glados.any.generatedAudioNote,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated notes through JSON', (scenario) {
      final note = scenario.note;

      final decoded = AudioNote.fromJson(
        jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(note), reason: '$scenario');
      expect(decoded.createdAt, note.createdAt, reason: '$scenario');
      expect(decoded.duration, note.duration, reason: '$scenario');
    }, tags: 'glados');
  });
}

class _GeneratedAudioNote {
  const _GeneratedAudioNote({
    required this.createdAtSlot,
    required this.audioFile,
    required this.audioDirectory,
    required this.durationMicroseconds,
  });

  final int createdAtSlot;
  final String audioFile;
  final String audioDirectory;
  final int durationMicroseconds;

  AudioNote get note => AudioNote(
    createdAt: DateTime.utc(
      2024 + (createdAtSlot % 4),
      (createdAtSlot % 12) + 1,
      (createdAtSlot % 28) + 1,
      createdAtSlot % 24,
      createdAtSlot % 60,
      createdAtSlot % 60,
      createdAtSlot % 1000,
      createdAtSlot % 1000,
    ),
    audioFile: audioFile,
    audioDirectory: audioDirectory,
    duration: Duration(microseconds: durationMicroseconds),
  );

  @override
  String toString() {
    return '_GeneratedAudioNote('
        'createdAtSlot: $createdAtSlot, '
        'audioFile: "$audioFile", '
        'audioDirectory: "$audioDirectory", '
        'durationMicroseconds: $durationMicroseconds)';
  }
}

extension _AnyAudioNote on glados.Any {
  glados.Generator<String> get _audioText =>
      glados.AnyUtils(this).choose(const [
        '',
        'clip.m4a',
        'voice note.ogg',
        'nested/path/audio.wav',
        r'escaped\name.m4a',
        'unicode-äudio.m4a',
      ]);

  glados.Generator<_GeneratedAudioNote> get generatedAudioNote =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 720),
        _audioText,
        _audioText,
        glados.IntAnys(this).intInRange(0, 900000000),
        (
          int createdAtSlot,
          String audioFile,
          String audioDirectory,
          int durationMicroseconds,
        ) => _GeneratedAudioNote(
          createdAtSlot: createdAtSlot,
          audioFile: audioFile,
          audioDirectory: audioDirectory,
          durationMicroseconds: durationMicroseconds,
        ),
      );
}
