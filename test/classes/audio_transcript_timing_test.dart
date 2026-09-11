import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_transcript_timing.dart';

import '../features/agents/query/query_audio_test_utils.dart';

void main() {
  test(
    'timing wire data preserves source identity and millisecond precision',
    () {
      final timing = audioTiming();
      final json = jsonDecode(jsonEncode(timing)) as Map<String, dynamic>;
      expect(json['audioSha256'], timing.audioSha256);
      expect(json['sourceFingerprint'], timing.sourceFingerprint);
      expect((json['segments'] as List).single, {
        'text': queryAudioWords,
        'startMilliseconds': 120000,
        'endMilliseconds': 130000,
      });
      expect(AudioTranscriptTiming.fromJson(json), timing);
    },
  );
}
