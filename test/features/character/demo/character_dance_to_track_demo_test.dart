import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/character_dance_to_track_demo.dart';

void main() {
  group('formatDancePlaybackTimestamp', () {
    test('formats sub-hour positions as mm:ss.mmm', () {
      expect(formatDancePlaybackTimestamp(0), '00:00.000');
      expect(formatDancePlaybackTimestamp(93.433), '01:33.433');
      expect(formatDancePlaybackTimestamp(144.06), '02:24.060');
    });

    test('rounds to the nearest millisecond and carries into minutes', () {
      expect(formatDancePlaybackTimestamp(59.9996), '01:00.000');
      expect(formatDancePlaybackTimestamp(61.2345), '01:01.235');
    });

    test('uses h:mm:ss.mmm after the first hour', () {
      expect(formatDancePlaybackTimestamp(3661.234), '1:01:01.234');
    });

    test('clamps invalid or negative positions to zero', () {
      expect(formatDancePlaybackTimestamp(-1), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.nan), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.infinity), '00:00.000');
    });
  });
}
