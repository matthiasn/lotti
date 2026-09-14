import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
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
    bool reRecordEnabled = true,
    String text = '',
    double width = 600,
    bool transcriptEdited = false,
    int restMinLines = 3,
  }) async {
    controller = TextEditingController(text: text);
    focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    // The view is the field's real width — the tiered captions measure
    // against layout, not the media query — pinned here so the bundle's
    // previous test cannot hand this one a wider or narrower window.
    tester.view
      ..physicalSize = Size(width, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
            transcriptEdited: transcriptEdited,
            restMinLines: restMinLines,
            onDictate: dictateEnabled ? () => calls.add('dictate') : null,
            onAddMore: () => calls.add('add-more'),
            onReRecord: reRecordEnabled ? () => calls.add('re-record') : null,
            onTypeInstead: () => calls.add('type-instead'),
            onRetryTranscript: () => calls.add('retry-transcript'),
            onOpenSettings: () => calls.add('open-settings'),
            onDismissFailure: () => calls.add('dismiss'),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: Size(width, 1200),
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

    testWidgets('the shortcut waits for words: beside a held Save it would '
        'promise what the footer denies', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        shortcutHint: '⌘Enter',
      );
      expect(find.textContaining('⌘Enter to save'), findsNothing);
      expect(find.byKey(const ValueKey('check-in-word-count')), findsNothing);
    });

    testWidgets('the empty field rests as tall as its host asks: two lines '
        'in the dialog, three on the phone', (tester) async {
      await pump(tester, phase: const CheckInSpeechIdle(), restMinLines: 2);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .minLines,
        2,
      );
      await pump(tester, phase: const CheckInSpeechIdle());
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .minLines,
        3,
      );
    });

    testWidgets('the caption ladder sheds the count before the shortcut: '
        'the hint pays off where the actions leave the least room', (
      tester,
    ) async {
      List<String> tiers() => tester
          .widget<DsTieredText>(
            find.ancestor(
              of: find.byKey(const ValueKey('check-in-word-count')),
              matching: find.byType(DsTieredText),
            ),
          )
          .tiers;
      await pump(
        tester,
        phase: const CheckInSpeechReady(
          transcript: 'The words that landed.',
          textBefore: '',
          length: Duration(seconds: 23),
        ),
        wordCount: 26,
        shortcutHint: '⌘Enter',
      );
      expect(tiers(), [
        'Transcript added · 26 words · ⌘Enter to save',
        'Transcript added · ⌘Enter to save',
        'Transcript added',
      ]);

      // Without a shortcut (the phone), the count is the only thing to shed.
      await pump(
        tester,
        phase: const CheckInSpeechReady(
          transcript: 'The words that landed.',
          textBefore: '',
          length: Duration(seconds: 23),
        ),
        wordCount: 26,
      );
      expect(tiers(), ['Transcript added · 26 words', 'Transcript added']);
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
    // The accent, not the error tone: a live take is not an error.
    // The accent hairline means focus only; the dot, the waveform and Stop
    // say live.
    expect(borderColor(tester), tokens(tester).colors.decorative.level01);
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
      // The saved-audio line is tiered: the route is the segment that goes
      // when the line is narrow, and assistive technology hears it either
      // way.
      final saved = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('check-in-audio-saved')),
          matching: find.byType(Text),
        ),
      );
      expect(
        saved.data,
        anyOf(
          '0:23 of audio saved · Whisper · via Groq · usually under a minute',
          '0:23 of audio saved · Whisper · via Groq',
          '0:23 of audio saved',
        ),
      );
      // In words for a reader: the clock is a shape, not a number.
      expect(
        saved.semanticsLabel,
        '23 seconds of audio saved · Whisper · via Groq · usually under a minute',
      );
      expect(find.byKey(const ValueKey('check-in-narrative')), findsNothing);
      // Caption-sized: the wait outranks the exit; the target keeps 48pt.
      final typeInstead = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('check-in-type-instead')),
      );
      expect(typeInstead.size, DesignSystemButtonSize.dense);
      expect(typeInstead.tapTargetSize, MaterialTapTargetSize.padded);
      await tester.tap(find.byKey(const ValueKey('check-in-type-instead')));
      expect(calls, ['type-instead']);
    });

    testWidgets('without a route the saved line is the length alone', (
      tester,
    ) async {
      // A phone's width, so the time expectation cannot fit beside Type
      // instead in any font the bundle may have loaded — the ladder is the
      // contract; the rendered tier only confirms which rung it took.
      await pump(
        tester,
        phase: const CheckInSpeechTranscribing(
          audioEntryId: 'audio-1',
          length: Duration(minutes: 1, seconds: 5),
        ),
        width: 360,
      );
      expect(
        tester
            .widget<DsTieredText>(
              find.ancestor(
                of: find.text('1:05 of audio saved'),
                matching: find.byType(DsTieredText),
              ),
            )
            .tiers,
        ['1:05 of audio saved · usually under a minute', '1:05 of audio saved'],
      );
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

  testWidgets('a landed transcript is announced once: live until it is '
      'edited, and always as "Transcript added", never as the count', (
    tester,
  ) async {
    const phase = CheckInSpeechReady(
      transcript: 'The words that landed.',
      textBefore: '',
      length: Duration(seconds: 23),
    );
    SemanticsNode caption() => tester.getSemantics(
      find.byKey(const ValueKey('check-in-word-count')),
    );
    await pump(tester, phase: phase, wordCount: 4, shortcutHint: '⌘Enter');
    expect(caption().flagsCollection.isLiveRegion, isTrue);
    expect(caption().label, 'Transcript added');

    await pump(
      tester,
      phase: phase,
      wordCount: 5,
      shortcutHint: '⌘Enter',
      transcriptEdited: true,
    );
    expect(caption().flagsCollection.isLiveRegion, isFalse);
    expect(caption().label, 'Transcript added · 5 words · ⌘Enter to save');
  });

  testWidgets('Re-record is not offered once the transcript has been edited', (
    tester,
  ) async {
    await pump(
      tester,
      text: 'The words that landed, edited.',
      phase: const CheckInSpeechReady(
        transcript: 'The words that landed.',
        textBefore: '',
        length: Duration(seconds: 23),
      ),
      wordCount: 5,
      reRecordEnabled: false,
    );
    expect(find.byKey(const ValueKey('check-in-re-record')), findsNothing);
    expect(find.byKey(const ValueKey('check-in-add-more')), findsOneWidget);
  });

  testWidgets('the actions keep one corner: beside the caption on a wide '
      'field, on their own line at the trailing edge on a phone — and on '
      'every width once a transcript has landed', (tester) async {
    const phase = CheckInSpeechReady(
      transcript: 'The words that landed.',
      textBefore: '',
      length: Duration(seconds: 23),
    );
    final addMore = find.byKey(const ValueKey('check-in-add-more'));
    final count = find.byKey(const ValueKey('check-in-word-count'));
    final field = find.byKey(const ValueKey('check-in-narrative-field'));

    // Wide, transcribing: one caption row with Type instead beside it.
    await pump(
      tester,
      phase: const CheckInSpeechTranscribing(
        audioEntryId: 'audio-1',
        length: Duration(seconds: 23),
      ),
      width: 1200,
    );
    final typeInstead = find.byKey(const ValueKey('check-in-type-instead'));
    final saved = find.textContaining('0:23 of audio saved');
    expect(
      tester.getRect(typeInstead).top,
      lessThan(tester.getRect(saved).bottom),
      reason: 'wide: caption and actions share a line',
    );

    // Wide, transcript landed: Re-record · Add more take their own line so
    // the caption keeps its shortcut.
    await pump(
      tester,
      phase: phase,
      wordCount: 4,
      shortcutHint: '⌘Enter',
      width: 1200,
    );
    expect(
      tester.getRect(addMore).top,
      greaterThanOrEqualTo(tester.getRect(count).bottom),
      reason: 'ready: the actions drop under the caption at any width',
    );
    expect(find.text('Transcript added · 4 words · ⌘Enter to save'), findsOne);

    await pump(tester, phase: phase, wordCount: 4, width: 402);
    expect(
      tester.getRect(addMore).top,
      greaterThanOrEqualTo(tester.getRect(count).bottom),
      reason: 'phone: the actions drop under the caption',
    );
    final inset = tokens(tester).spacing.step5;
    expect(
      tester.getRect(addMore).right,
      closeTo(tester.getRect(field).right - inset, 1),
      reason: 'and sit at the trailing edge, where Dictate sits when idle',
    );
  });

  testWidgets('ready keeps the text, names the transcript, and offers '
      'Re-record and Add more', (tester) async {
    await pump(
      tester,
      text: 'The words that landed.',
      phase: const CheckInSpeechReady(
        transcript: 'The words that landed.',
        textBefore: '',
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
    // A landed transcript is ordinary text again: the field rests.
    expect(borderColor(tester), tokens(tester).colors.decorative.level01);
  });

  group('failed', () {
    testWidgets('a denied microphone: the error card, Open settings, Try '
        'again, and the field still there to type into', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
      );
      expect(find.text('Allow microphone access'), findsOneWidget);
      expect(find.text('Or type it here…'), findsOneWidget);
      // The field's own ladder holds under the card: the placeholder steps
      // down a size and the retry is a quiet text action, so the card's
      // pill is the face's one shape.
      final tokens = tester
          .element(find.byKey(const ValueKey('check-in-narrative')))
          .designTokens;
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .decoration!
            .hintStyle!
            .fontSize,
        tokens.typography.styles.body.bodyMedium.fontSize,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-dictate')),
            )
            .variant,
        DesignSystemButtonVariant.tertiary,
      );
      // The card offers typing as a quiet button — the way out, not a
      // second accent — and its recommended action is the secondary pill:
      // the alert tone is the card's one colour.
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-type-instead-denied')),
            )
            .variant,
        DesignSystemButtonVariant.quiet,
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-type-instead-denied')),
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-open-settings')),
            )
            .variant,
        DesignSystemButtonVariant.secondary,
      );
      await tester.tap(find.byKey(const ValueKey('check-in-open-settings')));
      // Two actions like every card; the field's own Dictate beneath is the
      // retry.
      expect(find.byKey(const ValueKey('check-in-retry-audio')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-dictate')));
      expect(calls, ['dismiss', 'open-settings', 'dictate']);
      // Nor a "0 words" count under a card that already says nothing was
      // recorded.
      expect(find.byKey(const ValueKey('check-in-word-count')), findsNothing);
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

    testWidgets('a take that could not be saved says so — not that it never '
        'started — and offers to try again', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recordingNotSaved),
        ),
      );
      expect(find.text("Recording couldn't be saved"), findsOneWidget);
      expect(find.text("Recording didn't start"), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-retry-audio')));
      expect(calls, ['dictate']);
    });

    testWidgets("someone else's recording running is a warning that says "
        'where to stop it', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.recorderBusy),
        ),
      );
      expect(find.text('A recording is already running'), findsOneWidget);
      expect(
        find.textContaining('Stop it from the recording indicator first'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('check-in-dismiss-failure')));
      expect(calls, ['dismiss']);
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
      // The header names the state; the card's title is the next step, not
      // a cause the service cannot tell apart. The body says the audio stays.
      expect(
        find.text('Try again, or type it'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Your 0:23 recording is saved in the journal, even if you cancel',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('check-in-dictate')),
        findsNothing,
        reason: 'the card holds the way forward; no fourth door',
      );
      await tester.tap(
        find.byKey(const ValueKey('check-in-retry-transcript')),
      );
      expect(calls, ['retry-transcript']);
    });

    testWidgets('a dismissed missing-transcript card folds into one caption '
        'row that keeps the retry', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(
            CheckInSpeechFailureKind.transcriptMissing,
            audioEntryId: 'audio-1',
            length: Duration(seconds: 23),
          ),
          cardDismissed: true,
        ),
      );
      // No card, the ordinary hint — and the take is not forgotten.
      expect(
        find.byKey(const ValueKey('check-in-speech-failure')),
        findsNothing,
      );
      expect(find.text('Or type it here…'), findsNothing);
      expect(find.text('0:23 of audio saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-retry-transcript')));
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
