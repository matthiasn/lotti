import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_narrative_field.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;
  final calls = <String>[];

  setUp(calls.clear);

  Future<void> pump(
    WidgetTester tester, {
    required CheckInSpeechPhase phase,
    int wordCount = 0,
    String? shortcutHint,
    Widget? recorder,
    bool disableAnimations = false,
    bool dictateEnabled = true,
    String text = '',
  }) async {
    controller = TextEditingController(text: text);
    focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: CheckInNarrativeField(
            controller: controller,
            focusNode: focusNode,
            phase: phase,
            wordCount: wordCount,
            recorder: recorder,
            shortcutHint: shortcutHint,
            onDictate: dictateEnabled ? () => calls.add('dictate') : null,
            onAddMore: () => calls.add('add-more'),
            onReRecord: () => calls.add('re-record'),
            onTypeInstead: () => calls.add('type-instead'),
            onRetryTranscript: () => calls.add('retry-transcript'),
            onOpenSettings: () => calls.add('open-settings'),
            onDismissFailure: () => calls.add('dismiss'),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(600, 1200),
          disableAnimations: disableAnimations,
        ),
      ),
    );
    await tester.pump();
  }

  Color borderColor(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('check-in-narrative-field')),
    );
    return (box.decoration! as BoxDecoration).border!.top.color;
  }

  DsTokens tokens(WidgetTester tester) => tester
      .element(find.byKey(const ValueKey('check-in-narrative-field')))
      .designTokens;

  group('idle', () {
    testWidgets('is the text field, the word count and Dictate', (
      tester,
    ) async {
      await pump(tester, phase: const CheckInSpeechIdle(), wordCount: 3);

      expect(find.byKey(const ValueKey('check-in-narrative')), findsOneWidget);
      expect(find.text('3 words'), findsOneWidget);
      expect(
        find.text('What did you talk about? One line is enough.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('check-in-dictate')));
      expect(calls, ['dictate']);
      expect(
        find.byKey(const ValueKey('check-in-inline-recorder')),
        findsNothing,
      );
      expect(borderColor(tester), tokens(tester).colors.decorative.level01);
    });

    testWidgets('one word is singular, and the shortcut rides the count', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        wordCount: 1,
        shortcutHint: '⌘Enter',
      );
      expect(find.text('1 word · ⌘Enter to save'), findsOneWidget);
    });

    testWidgets('focus lifts the border to the interactive accent', (
      tester,
    ) async {
      await pump(tester, phase: const CheckInSpeechIdle());
      focusNode.requestFocus();
      // The focus change lands in a microtask; the border follows a frame
      // later.
      await tester.pump();
      await tester.pump();
      expect(borderColor(tester), tokens(tester).colors.interactive.enabled);
    });

    testWidgets('a null Dictate disables the button without hiding it', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        dictateEnabled: false,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-dictate')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  testWidgets('preparing keeps the text and says so, with Dictate busy', (
    tester,
  ) async {
    await pump(tester, phase: const CheckInSpeechPreparing());
    expect(find.byKey(const ValueKey('check-in-preparing')), findsOneWidget);
    final dictate = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('check-in-dictate')),
    );
    expect(dictate.isLoading, isTrue);
    expect(dictate.onPressed, isNull);
    expect(find.byKey(const ValueKey('check-in-narrative')), findsOneWidget);
  });

  testWidgets('recording replaces the text with the hint and the recorder', (
    tester,
  ) async {
    await pump(
      tester,
      phase: const CheckInSpeechRecording(),
      recorder: const SizedBox(key: ValueKey('fake-recorder'), height: 40),
    );
    expect(find.byKey(const ValueKey('check-in-narrative')), findsNothing);
    expect(find.byKey(const ValueKey('fake-recorder')), findsOneWidget);
    expect(
      find.text('Speak normally. Words appear here when you stop.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
    expect(borderColor(tester), tokens(tester).colors.alert.error.defaultColor);
  });

  group('transcribing', () {
    testWidgets('shows the skeleton, the saved audio with its route, and '
        'Type instead', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechTranscribing(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
          route: 'Whisper · via Groq',
        ),
      );
      expect(
        find.byKey(const ValueKey('check-in-transcript-skeleton')),
        findsOneWidget,
      );
      expect(
        find.text('0:23 of audio saved · Whisper · via Groq'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('check-in-narrative')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-type-instead')));
      expect(calls, ['type-instead']);
    });

    testWidgets('without a route the saved line is the length alone', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechTranscribing(
          audioEntryId: 'audio-1',
          length: Duration(minutes: 1, seconds: 5),
        ),
      );
      expect(find.text('1:05 of audio saved'), findsOneWidget);
    });

    testWidgets('the skeleton breathes, and holds still under reduced motion', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechTranscribing(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 1),
        ),
      );
      double opacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('check-in-transcript-skeleton'),
                  ),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      final before = opacity();
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacity(), isNot(before), reason: 'the pulse moves');

      await pump(
        tester,
        phase: const CheckInSpeechTranscribing(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 1),
        ),
        disableAnimations: true,
      );
      final still = opacity();
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacity(), still, reason: 'no motion for a reduced-motion user');
    });
  });

  testWidgets('ready keeps the text, names the transcript, and offers '
      'Re-record and Add more', (tester) async {
    await pump(
      tester,
      text: 'The words that landed.',
      phase: const CheckInSpeechReady(
        transcript: 'The words that landed.',
        length: Duration(seconds: 23),
      ),
      wordCount: 4,
    );
    expect(
      find.byKey(const ValueKey('check-in-transcript-added')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('check-in-re-record')));
    await tester.tap(find.byKey(const ValueKey('check-in-add-more')));
    expect(calls, ['re-record', 'add-more']);
    expect(borderColor(tester), tokens(tester).colors.interactive.enabled);
  });

  group('failed', () {
    testWidgets('a denied microphone: the error card, Open settings, Dismiss, '
        'and the field still there to type into', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
      );
      expect(find.text("Lotti can't use the microphone"), findsOneWidget);
      expect(find.text('Or type it here…'), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-audio-kept')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-open-settings')));
      await tester.tap(find.byKey(const ValueKey('check-in-dismiss-failure')));
      expect(calls, ['open-settings', 'dismiss']);
      // Dictate stays, wearing the muted glyph, so a retry after the
      // settings trip is one tap away.
      final dictate = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('check-in-dictate')),
      );
      expect(dictate.leadingIcon, LottiIcons.micIdle);
      expect(dictate.onPressed, isNotNull);
    });

    testWidgets('a failed start offers Try again, which records again', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recordingFailed),
        ),
      );
      expect(find.text("Recording didn't start"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('check-in-retry-audio')));
      expect(calls, ['dictate']);
    });

    testWidgets('no transcription model: a warning with the settings hint '
        'and only Type instead', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(
            CheckInSpeechFailureKind.transcriptionUnavailable,
          ),
        ),
      );
      expect(find.text('No transcription model set up'), findsOneWidget);
      expect(
        find.textContaining('Choose a default inference profile'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('check-in-retry-audio')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-dismiss-failure')));
      expect(calls, ['dismiss']);
    });

    testWidgets('a missing transcript quotes the saved length, retries the '
        'transcript rather than the recording, and says the audio stays', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(
            CheckInSpeechFailureKind.transcriptMissing,
            audioEntryId: 'audio-1',
            length: Duration(seconds: 23),
          ),
        ),
      );
      expect(
        find.text("Couldn't reach the transcription server"),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your 0:23 recording is saved on this device'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('check-in-audio-kept')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-retry-transcript')),
      );
      expect(calls, ['retry-transcript']);
    });

    testWidgets("the provider's own reason replaces the generic body", (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(
            CheckInSpeechFailureKind.transcriptMissing,
            audioEntryId: 'audio-1',
            detail: 'HTTP 503 · Transcription service unavailable',
          ),
        ),
      );
      expect(
        find.text('HTTP 503 · Transcription service unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('recording is saved'), findsNothing);
    });
  });
}
