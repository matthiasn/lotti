import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_error_message.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  /// Resolves the mapping against a real localized context.
  Future<String> resolve(
    WidgetTester tester,
    ChatRecorderErrorKind? kind, {
    bool keptInJournal = false,
  }) async {
    late String message;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            message = chatRecorderErrorMessage(
              context,
              kind,
              keptInJournal: keptInJournal,
            );
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

  testWidgets('a failed transcription whose take could not be kept claims '
      'nothing about the recording', (tester) async {
    expect(
      await resolve(tester, ChatRecorderErrorKind.transcriptionFailed),
      'Transcribing the recording failed. Please try again.',
    );
  });

  testWidgets('a failed transcription whose take was kept says where it is', (
    tester,
  ) async {
    expect(
      await resolve(
        tester,
        ChatRecorderErrorKind.transcriptionFailed,
        keptInJournal: true,
      ),
      'Transcribing failed. Your recording is saved in the logbook, so '
      'nothing is lost.',
    );
  });

  testWidgets('a missing audio model with the take kept says so before '
      'pointing at AI settings', (tester) async {
    expect(
      await resolve(
        tester,
        ChatRecorderErrorKind.noAudioModel,
        keptInJournal: true,
      ),
      'No transcription model is set up yet. Your recording is saved in the '
      'logbook. Add an audio-capable model in AI settings.',
    );
  });

  testWidgets('kept or not changes nothing about the other reasons', (
    tester,
  ) async {
    expect(
      await resolve(
        tester,
        ChatRecorderErrorKind.noAudioFile,
        keptInJournal: true,
      ),
      'No audio was recorded. Try again.',
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
