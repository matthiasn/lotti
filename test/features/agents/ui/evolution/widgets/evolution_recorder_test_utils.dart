import 'package:flutter/material.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';

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

/// Controller that starts in processing state.
class ProcessingTestController extends ChatRecorderController {
  ProcessingTestController({required this._partialTranscript});

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
  int clearResultCalls = 0;

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

  void emitError(String error) {
    state = state.copyWith(
      status: ChatRecorderStatus.idle,
      error: error,
      errorType: ChatRecorderErrorType.transcriptionFailed,
    );
  }

  @override
  void clearResult() {
    clearResultCalls++;
    state = ChatRecorderState(
      status: state.status,
      amplitudeHistory: state.amplitudeHistory,
    );
  }
}

/// Idle controller that tracks start calls.
class IdleCallbackController extends ChatRecorderController {
  IdleCallbackController({this.onStartCalled});

  final VoidCallback? onStartCalled;

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
}
