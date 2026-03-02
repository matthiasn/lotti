import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockRealtimeService extends Mock
    implements RealtimeTranscriptionService {}

/// Creates a [MockRealtimeService] that reports realtime config available.
MockRealtimeService realtimeServiceWithConfig() {
  final mock = MockRealtimeService();
  when(mock.resolveRealtimeConfig).thenAnswer(
    (_) async => (
      provider: const FakeProvider(),
      model: const FakeModel(),
    ),
  );
  return mock;
}

class FakeProvider implements AiConfigInferenceProvider {
  const FakeProvider();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeModel implements AiConfigModel {
  const FakeModel();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Controller that starts in recording state.
class RecordingTestController extends ChatRecorderController {
  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.recording,
      amplitudeHistory: [],
    );
  }

  @override
  List<double> getNormalizedAmplitudeHistory() => [];
}

/// Recording controller that tracks cancel/stop calls.
class RecordingCallbackController extends ChatRecorderController {
  RecordingCallbackController({
    this.onCancelCalled,
    this.onStopCalled,
  });

  final VoidCallback? onCancelCalled;
  final VoidCallback? onStopCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.recording,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> cancel() async {
    onCancelCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  Future<void> stopAndTranscribe() async {
    onStopCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  List<double> getNormalizedAmplitudeHistory() => [];
}

/// Controller that starts in realtime recording state.
class RealtimeRecordingTestController extends ChatRecorderController {
  RealtimeRecordingTestController({String? partialTranscript})
      : _partialTranscript = partialTranscript;

  final String? _partialTranscript;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.realtimeRecording,
      amplitudeHistory: const [],
      partialTranscript: _partialTranscript,
    );
  }
}

/// Realtime controller that tracks cancel/stop calls.
class RealtimeCallbackController extends ChatRecorderController {
  RealtimeCallbackController({
    this.onCancelCalled,
    this.onStopCalled,
  });

  final VoidCallback? onCancelCalled;
  final VoidCallback? onStopCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.realtimeRecording,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> cancel() async {
    onCancelCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  @override
  Future<void> stopRealtime() async {
    onStopCalled?.call();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }
}

/// Controller that starts in processing state.
class ProcessingTestController extends ChatRecorderController {
  ProcessingTestController({required String? partialTranscript})
      : _partialTranscript = partialTranscript;

  final String? _partialTranscript;

  @override
  ChatRecorderState build() {
    return ChatRecorderState(
      status: ChatRecorderStatus.processing,
      amplitudeHistory: const [],
      partialTranscript: _partialTranscript,
    );
  }
}

/// Idle controller that can emit a transcript.
class TranscriptEmittingController extends ChatRecorderController {
  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: [],
    );
  }

  void emitTranscript(String transcript) {
    state = state.copyWith(
      status: ChatRecorderStatus.idle,
      transcript: transcript,
    );
  }

  @override
  void clearResult() {
    state = ChatRecorderState(
      status: state.status,
      amplitudeHistory: state.amplitudeHistory,
    );
  }
}

/// Idle controller that tracks start calls.
class IdleCallbackController extends ChatRecorderController {
  IdleCallbackController({
    this.onStartCalled,
    this.onStartRealtimeCalled,
  });

  final VoidCallback? onStartCalled;
  final VoidCallback? onStartRealtimeCalled;

  @override
  ChatRecorderState build() {
    return const ChatRecorderState(
      status: ChatRecorderStatus.idle,
      amplitudeHistory: [],
    );
  }

  @override
  Future<void> start() async {
    onStartCalled?.call();
  }

  @override
  Future<void> startRealtime() async {
    onStartRealtimeCalled?.call();
  }
}
