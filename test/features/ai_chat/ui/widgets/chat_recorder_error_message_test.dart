import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_recorder_error_message.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  /// Resolves the mapping against a real localized context.
  Future<String> resolve(
    WidgetTester tester,
    ChatRecorderErrorKind? kind,
  ) async {
    late String message;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            message = chatRecorderErrorMessage(context, kind);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return message;
  }

  testWidgets('a denied microphone names the permission and its fix', (
    tester,
  ) async {
    expect(
      await resolve(tester, ChatRecorderErrorKind.permissionDenied),
      "Lotti can't use the microphone. Enable microphone access for Lotti "
      'in your system settings.',
    );
  });

  testWidgets('a missing audio model points at AI settings', (tester) async {
    expect(
      await resolve(tester, ChatRecorderErrorKind.noAudioModel),
      'No transcription model is set up yet. Add an audio-capable model in '
      'AI settings.',
    );
  });

  testWidgets('a failed transcription says the audio was captured', (
    tester,
  ) async {
    expect(
      await resolve(tester, ChatRecorderErrorKind.transcriptionFailed),
      'The recording was captured, but transcribing it failed. Please try '
      'again.',
    );
  });

  testWidgets('an empty capture reuses the no-audio line', (tester) async {
    expect(
      await resolve(tester, ChatRecorderErrorKind.noAudioFile),
      'No audio was recorded. Try again.',
    );
  });

  testWidgets('transient failures and an unknown kind fall back to retry', (
    tester,
  ) async {
    const fallback = 'Recording failed. Please try again.';
    // Busy and start failures are genuinely transient; null covers a state
    // whose error arrived without a kind.
    expect(await resolve(tester, ChatRecorderErrorKind.busy), fallback);
    expect(await resolve(tester, ChatRecorderErrorKind.startFailed), fallback);
    expect(await resolve(tester, null), fallback);
  });

  testWidgets('every kind maps to a non-empty message, and the three '
      'diagnosable ones are distinct', (tester) async {
    final byKind = <ChatRecorderErrorKind, String>{};
    for (final kind in ChatRecorderErrorKind.values) {
      byKind[kind] = await resolve(tester, kind);
    }

    expect(byKind.keys, ChatRecorderErrorKind.values);
    expect(byKind.values.every((message) => message.trim().isNotEmpty), isTrue);

    // The whole point of the enum: these three no longer collapse into one
    // indistinguishable toast.
    final diagnosable = {
      byKind[ChatRecorderErrorKind.permissionDenied],
      byKind[ChatRecorderErrorKind.noAudioModel],
      byKind[ChatRecorderErrorKind.transcriptionFailed],
    };
    expect(diagnosable, hasLength(3));
    expect(
      diagnosable.contains(byKind[ChatRecorderErrorKind.startFailed]),
      isFalse,
    );
  });
}
