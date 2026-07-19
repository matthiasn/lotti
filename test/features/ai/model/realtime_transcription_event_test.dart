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
      final result = RealtimeStopResult(
        transcript: 'Hello world',
        recordingSessionId: 'test-session',
        audioFilePath: '/tmp/audio.m4a',
        captureDisposition: RealtimeCaptureDisposition.complete,
      );
      expect(result.transcript, 'Hello world');
      expect(result.audioFilePath, '/tmp/audio.m4a');
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('recovery result permits no finalized audio path', () {
      final result = RealtimeStopResult(
        transcript: 'text',
        recordingSessionId: 'test-session',
        captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
      );
      expect(result.audioFilePath, isNull);
      expect(result.detectedLanguage, isNull);
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('stores detectedLanguage when reported by the server', () {
      final result = RealtimeStopResult(
        transcript: 'Hallo Welt',
        recordingSessionId: 'test-session',
        detectedLanguage: 'de',
        captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
      );
      expect(result.transcript, 'Hallo Welt');
      expect(result.detectedLanguage, 'de');
    });

    test('usedTranscriptFallback reflects timeout fallback', () {
      final result = RealtimeStopResult(
        transcript: 'partial',
        recordingSessionId: 'test-session',
        usedTranscriptFallback: true,
        captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
      );
      expect(result.usedTranscriptFallback, isTrue);
    });

    test('handles empty transcript', () {
      final result = RealtimeStopResult(
        transcript: '',
        recordingSessionId: 'test-session',
        captureDisposition: RealtimeCaptureDisposition.noAudio,
      );
      expect(result.transcript, isEmpty);
    });

    test('rejects complete disposition without an audio path', () {
      expect(
        () => RealtimeStopResult(
          transcript: 'text',
          recordingSessionId: 'test-session',
          captureDisposition: RealtimeCaptureDisposition.complete,
        ),
        throwsArgumentError,
      );
    });

    test('rejects no-audio disposition with a fabricated path', () {
      expect(
        () => RealtimeStopResult(
          transcript: '',
          recordingSessionId: 'test-session',
          audioFilePath: '/tmp/empty.wav',
          captureDisposition: RealtimeCaptureDisposition.noAudio,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty durable recording identity', () {
      expect(
        () => RealtimeStopResult(
          transcript: '',
          recordingSessionId: '  ',
          captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
        ),
        throwsArgumentError,
      );
    });
  });
}
