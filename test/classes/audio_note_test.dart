import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
  });
}
