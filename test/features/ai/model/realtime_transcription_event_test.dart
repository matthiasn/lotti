import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';

void main() {
  group('RealtimeTranscriptionDone', () {
    test('stores text and usage', () {
      const done = RealtimeTranscriptionDone(
        text: 'Hello world',
        usage: {'audio_seconds': 5.0, 'input_tokens': 100},
      );
      expect(done.text, 'Hello world');
      expect(done.usage, isNotNull);
      expect(done.usage!['audio_seconds'], 5.0);
    });

    test('usage defaults to null', () {
      const done = RealtimeTranscriptionDone(text: 'abc');
      expect(done.text, 'abc');
      expect(done.usage, isNull);
    });

    test('handles empty text', () {
      const done = RealtimeTranscriptionDone(text: '');
      expect(done.text, isEmpty);
    });
  });

  group('RealtimeTranscriptionError', () {
    test('stores all fields', () {
      const error = RealtimeTranscriptionError(
        message: 'Something went wrong',
        code: 'internal_error',
        type: 'server_error',
      );
      expect(error.message, 'Something went wrong');
      expect(error.code, 'internal_error');
      expect(error.type, 'server_error');
    });

    test('code and type default to null', () {
      const error = RealtimeTranscriptionError(message: 'fail');
      expect(error.message, 'fail');
      expect(error.code, isNull);
      expect(error.type, isNull);
    });
  });

  group('RealtimeStopResult', () {
    test('stores transcript and audio path', () {
      const result = RealtimeStopResult(
        transcript: 'Hello world',
        audioFilePath: '/tmp/audio.m4a',
      );
      expect(result.transcript, 'Hello world');
      expect(result.audioFilePath, '/tmp/audio.m4a');
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('audioFilePath defaults to null', () {
      const result = RealtimeStopResult(transcript: 'text');
      expect(result.audioFilePath, isNull);
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('usedTranscriptFallback reflects timeout fallback', () {
      const result = RealtimeStopResult(
        transcript: 'partial',
        usedTranscriptFallback: true,
      );
      expect(result.usedTranscriptFallback, isTrue);
    });

    test('handles empty transcript', () {
      const result = RealtimeStopResult(transcript: '');
      expect(result.transcript, isEmpty);
    });
  });
}
