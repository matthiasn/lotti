import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_narrative_field.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
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
    double width = 600,
    int restMinLines = 3,
    bool offersDictation = true,
    List<CheckInTake> takes = const [],
    bool undoOffered = false,
    int removedAt = 0,
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
            restMinLines: restMinLines,
            offersDictation: offersDictation,
            takes: takes,
            onDictate: dictateEnabled ? () => calls.add('dictate') : null,
            onRetryTake: (id) => calls.add('retry $id'),
            onRemoveTake: (id) => calls.add('remove $id'),
            onUndoRemove: undoOffered ? () => calls.add('undo') : null,
            removedAt: removedAt,
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

  BoxDecoration frame(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.byKey(const ValueKey('check-in-narrative-field')),
              )
              .decoration!
          as BoxDecoration;

  Color borderColor(WidgetTester tester) => frame(tester).border!.top.color;

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
      // The design-system field frame: the shared hairline at rest, and no
      // well of its own — the sheet's surface shows through.
      expect(
        borderColor(tester),
        designSystemFieldBorderColor(tokens(tester)),
      );
      expect(frame(tester).color, isNull);
    });

    testWidgets('focused, the frame is the shared accent hairline at full '
        'weight', (tester) async {
      await pump(tester, phase: const CheckInSpeechIdle());
      await tester.tap(find.byKey(const ValueKey('check-in-narrative')));
      await tester.pump();
      expect(
        borderColor(tester),
        designSystemFieldBorderColor(tokens(tester), focused: true),
      );
      expect(frame(tester).border!.top.width, 2);
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
        phase: const CheckInSpeechIdle(),
        wordCount: 26,
        shortcutHint: '⌘Enter',
      );
      expect(tiers(), ['26 words · ⌘Enter to save', '⌘Enter to save']);

      // Without a shortcut (the phone), the count is all there is.
      await pump(tester, phase: const CheckInSpeechIdle(), wordCount: 26);
      expect(tiers(), ['26 words']);
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

    testWidgets("focus draws one frame: the theme's focused outline never "
        'rings the text inside the accent hairline', (tester) async {
      await pump(tester, phase: const CheckInSpeechIdle());
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      // The decoration the TextField hands its decorator, after the app's
      // InputDecorationTheme has filled in whatever the field left null.
      final effective = tester
          .widget<InputDecorator>(
            find.descendant(
              of: find.byKey(const ValueKey('check-in-narrative')),
              matching: find.byType(InputDecorator),
            ),
          )
          .decoration;
      expect(effective.focusedBorder, InputBorder.none);
      expect(effective.enabledBorder, InputBorder.none);
      expect(effective.focusedErrorBorder, InputBorder.none);
      expect(effective.filled, isFalse);
    });

    testWidgets('a field that offers no dictation has no Dictate, and still '
        'counts the words', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        wordCount: 3,
        offersDictation: false,
      );
      expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
      expect(find.text('3 words'), findsOneWidget);

      // Nor under a card whose recovery would otherwise be the field's own
      // Dictate.
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
        offersDictation: false,
      );
      expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
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
    // Nothing over the recorder: its orb, caption and the status dot say
    // what an instruction line used to narrate.
    expect(find.byKey(const ValueKey('check-in-recording-hint')), findsNothing);
    expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
    // No frame at all while the recorder owns the box: it sits on the
    // sheet as the recording sheet's recorder does, not in a box inside it.
    expect(borderColor(tester), Colors.transparent);
    expect(frame(tester).color, isNull);
  });

  // ADR 0062: each recording is the check-in's entry, shown under the note
  // with its words — never merged into the note — and Save never waits.
  group('takes', () {
    const take = CheckInTake(
      audioEntryId: 'audio-1',
      length: Duration(seconds: 23),
    );

    testWidgets('a take still transcribing gives its length and route, then '
        'the shared status, and says Save does not wait', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        takes: [take.withRoute('whisper · via Melious')],
        width: 1200,
      );

      expect(find.text('00:23 · whisper · via Melious'), findsOneWidget);
      // A narrow row sheds the route first; the length is the fact.
      expect(
        tester
            .widget<DsTieredText>(
              find.ancestor(
                of: find.byKey(const ValueKey('check-in-take-meta')),
                matching: find.byType(DsTieredText),
              ),
            )
            .tiers,
        ['00:23 · whisper · via Melious', '00:23'],
      );
      // Where the words are is said once, by the component every check-in
      // surface shares, with the composer's reassurance as its detail.
      final status = tester.widget<RecordingTranscript>(
        find.byType(RecordingTranscript),
      );
      expect(status.status, TranscriptStatus.transcribing);
      expect(status.folded, isFalse);
      expect(find.text('Transcribing…'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transcript-detail-audio-1')),
            )
            .data,
        'You can save now — the words follow.',
      );
      expect(
        find.byKey(const ValueKey('check-in-narrative')),
        findsOneWidget,
        reason: 'the note stays a field to type in beside the recording',
      );
      expect(
        find.byKey(const ValueKey('check-in-dictate')),
        findsOneWidget,
        reason: 'another take can always follow',
      );
    });

    testWidgets('a heard take shows its words as its own, not in the note', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        text: 'Send krill tonight.',
        wordCount: 3,
        takes: [take.heard('Pip wants the contract signed before the freeze.')],
      );

      expect(find.text('00:23'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transcript-words-audio-1')),
            )
            .data,
        'Pip wants the contract signed before the freeze.',
      );
      expect(controller.text, 'Send krill tonight.');
      // Beside a take the note's count would read as the take's: it goes.
      expect(find.textContaining('words'), findsNothing);
    });

    testWidgets(
      "a take whose words never came says so, offers the same recording's "
      "words again, and names the provider's reason when it left one",
      (
        tester,
      ) async {
        await pump(
          tester,
          phase: const CheckInSpeechIdle(),
          takes: [take.missing(null)],
        );
        // Nothing came and nothing said why: not transcribed, in the same
        // words a goal's rail uses.
        expect(find.text('00:23'), findsOneWidget);
        expect(find.text('Not transcribed'), findsOneWidget);
        expect(
          find.textContaining('Your recording is saved in the journal'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('transcript-retry-audio-1')),
        );
        expect(calls, ['retry audio-1']);

        await pump(
          tester,
          phase: const CheckInSpeechIdle(),
          takes: [take.missing('HTTP 503 · Transcription service unavailable')],
        );
        // The provider said why: it failed, and its reason is the detail.
        expect(find.text('Transcription failed'), findsOneWidget);
        expect(
          find.text('HTTP 503 · Transcription service unavailable'),
          findsOneWidget,
        );
        expect(find.textContaining('recording is saved'), findsNothing);
      },
    );

    testWidgets('every take can be left out, each by its own id', (
      tester,
    ) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        takes: [
          take.heard('First.'),
          const CheckInTake(
            audioEntryId: 'audio-2',
            length: Duration(seconds: 4),
          ),
        ],
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('check-in-take-audio-2')),
          matching: find.byKey(const ValueKey('check-in-take-remove')),
        ),
      );
      expect(calls, ['remove audio-2']);
      expect(find.byTooltip('Remove recording'), findsNWidgets(2));
    });

    testWidgets('beside a recording the note asks for one line, and the '
        'shortcut is offered with no words typed', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        shortcutHint: '⌘Enter',
        takes: [take],
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .minLines,
        1,
      );
      expect(find.text('⌘Enter to save'), findsOneWidget);
    });

    testWidgets('what was said leads: the takes stand above the note, whose '
        'placeholder invites a note of its own in the same tier', (
      tester,
    ) async {
      await pump(tester, phase: const CheckInSpeechIdle());
      final note = find.byKey(const ValueKey('check-in-narrative'));
      final restingHint = tester.widget<TextField>(note).decoration!;
      expect(
        restingHint.hintText,
        'What did you talk about? One line is enough.',
      );

      await pump(tester, phase: const CheckInSpeechIdle(), takes: [take]);
      final besideTake = tester.widget<TextField>(note).decoration!;
      expect(besideTake.hintText, 'Add a note…');
      // The placeholder keeps its size when a take lands; the copy changes.
      expect(
        besideTake.hintStyle!.fontSize,
        restingHint.hintStyle!.fontSize,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('check-in-take-audio-1')))
            .dy,
        lessThan(tester.getTopLeft(note).dy),
      );
    });

    testWidgets('the offer to put a removed take back stands in its slot, '
        'and Undo asks for it', (tester) async {
      const second = CheckInTake(
        audioEntryId: 'audio-2',
        length: Duration(seconds: 9),
      );
      // The middle of three was removed: the offer stands between the two
      // that remain.
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        takes: [take, second],
        undoOffered: true,
        removedAt: 1,
      );
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final slot = find.byKey(const ValueKey('check-in-take-removed'));
      expect(
        find.descendant(
          of: slot,
          matching: find.text('Recording removed'),
        ),
        findsOneWidget,
      );
      expect(
        top(slot),
        greaterThan(top(find.byKey(const ValueKey('check-in-take-audio-1')))),
      );
      expect(
        top(slot),
        lessThan(top(find.byKey(const ValueKey('check-in-take-audio-2')))),
      );

      await tester.tap(find.byKey(const ValueKey('check-in-take-undo')));
      expect(calls, ['undo']);

      // The slot counts as a take for the footer: with only the slot left,
      // Dictate stays quiet and the note's count stays away, so removing a
      // take never reshapes the footer.
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        wordCount: 5,
        undoOffered: true,
      );
      final dictate = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('check-in-dictate')),
      );
      expect(dictate.variant, DesignSystemButtonVariant.tertiary);
      expect(dictate.size, DesignSystemButtonSize.dense);
      // Nor the note's hint: the long one would wrap and grow the field.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('check-in-narrative')))
            .decoration!
            .hintText,
        'Add a note…',
      );
      // Removing the only take leaves nothing to save: no shortcut either.
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        shortcutHint: '⌘Enter',
        undoOffered: true,
      );
      expect(find.textContaining('to save'), findsNothing);
      expect(find.textContaining('5 words'), findsNothing);

      // A slot past the takes there are now is clamped to the end.
      await pump(
        tester,
        phase: const CheckInSpeechIdle(),
        takes: [take],
        undoOffered: true,
        removedAt: 5,
      );
      expect(
        top(slot),
        greaterThan(top(find.byKey(const ValueKey('check-in-take-audio-1')))),
      );
    });
  });

  testWidgets('the actions keep one corner: beside the caption on a wide '
      'field, on their own line at the trailing edge at large text', (
    tester,
  ) async {
    final dictate = find.byKey(const ValueKey('check-in-dictate'));
    final count = find.byKey(const ValueKey('check-in-word-count'));
    final field = find.byKey(const ValueKey('check-in-narrative-field'));

    await pump(
      tester,
      phase: const CheckInSpeechIdle(),
      wordCount: 4,
      width: 1200,
    );
    expect(
      tester.getRect(dictate).top,
      lessThan(tester.getRect(count).bottom),
      reason: 'wide: caption and actions share a line',
    );
    final inset = tokens(tester).spacing.step5;
    expect(
      tester.getRect(dictate).right,
      closeTo(tester.getRect(field).right - inset, 1),
      reason: 'Dictate sits at the trailing edge',
    );
  });

  testWidgets('beside a take a one-line note is one line tall — no blank '
      'second line on a touch platform', (tester) async {
    await pump(
      tester,
      phase: const CheckInSpeechIdle(),
      // Short enough to stay one line in the test font, whose every glyph
      // is a full em wide — beside a hint that is not.
      text: 'Krill.',
      wordCount: 1,
      width: 400,
      takes: [
        const CheckInTake(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
        ).heard('Reviewed the launch.'),
      ],
    );
    final field = find.byKey(const ValueKey('check-in-narrative'));
    final editable = tester
        .state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        )
        .renderEditable;
    // The hidden two-line hint holds no second line open.
    expect(editable.size.height, closeTo(editable.preferredLineHeight, 0.5));
    expect(
      tester.getSize(field).height,
      closeTo(editable.preferredLineHeight, 0.5),
    );
  });

  testWidgets('a heard take shows its whole transcript; once a take is in, '
      'Dictate steps down to a dense text action so Save leads', (
    tester,
  ) async {
    const long =
        'Reviewed the habitat launch with Pip. The window slips a week, '
        'Pip is calm about it, the krill contract needs signing before the '
        'freeze, and the pad-3 decision is not to be reopened.';
    await pump(
      tester,
      phase: const CheckInSpeechIdle(),
      takes: [
        const CheckInTake(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
        ).heard(long),
      ],
    );
    final transcript = tester.widget<Text>(
      find.byKey(const ValueKey('transcript-words-audio-1')),
    );
    expect(transcript.maxLines, isNull);
    expect(transcript.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(const ValueKey('check-in-dictate')),
          )
          .variant,
      DesignSystemButtonVariant.tertiary,
    );
    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(const ValueKey('check-in-dictate')),
          )
          .size,
      DesignSystemButtonSize.dense,
    );

    await pump(tester, phase: const CheckInSpeechIdle());
    expect(
      tester
          .widget<DesignSystemButton>(
            find.byKey(const ValueKey('check-in-dictate')),
          )
          .variant,
      DesignSystemButtonVariant.outlined,
    );
  });

  testWidgets("where a take's words are is announced from the take itself, "
      'not the sheet header', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      phase: const CheckInSpeechIdle(),
      takes: [
        const CheckInTake(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
        ),
      ],
    );
    expect(
      tester.getSemantics(find.text('Transcribing…')),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets("a take's header is the recording — the waveform and its "
      'length in every state — and its words speak the shared vocabulary', (
    tester,
  ) async {
    const take = CheckInTake(
      audioEntryId: 'audio-1',
      length: Duration(seconds: 23),
    );
    for (final (state, expected) in [
      (take, TranscriptStatus.transcribing),
      (take.heard('Words.'), TranscriptStatus.heard),
      (take.missing(null), TranscriptStatus.notTranscribed),
      (take.missing('HTTP 503'), TranscriptStatus.failed),
    ]) {
      await pump(tester, phase: const CheckInSpeechIdle(), takes: [state]);
      final reason = '${state.words} ${state.detail}';
      expect(CheckInTakeRow.statusOf(state), expected, reason: reason);
      expect(
        tester
            .widget<RecordingTranscript>(find.byType(RecordingTranscript))
            .status,
        expected,
        reason: reason,
      );
      final header = find.ancestor(
        of: find.byKey(const ValueKey('check-in-take-meta')),
        matching: find.byType(Row),
      );
      expect(
        tester
            .widgetList<Icon>(
              find.descendant(of: header.first, matching: find.byType(Icon)),
            )
            .first
            .icon,
        LottiIcons.waveform,
        reason: reason,
      );
    }
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
      // The callout stands above the field, not inside its frame: one
      // bordered object at a time.
      final card = find.byKey(const ValueKey('check-in-speech-failure'));
      final frame = find.byKey(const ValueKey('check-in-narrative-field'));
      expect(find.descendant(of: frame, matching: card), findsNothing);
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(tester.getRect(frame).top),
      );
      // The field keeps its own hint, and its Dictate — the retry the
      // card's body names — keeps its resting shape.
      expect(
        find.text('What did you talk about? One line is enough.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('check-in-dictate')),
            )
            .variant,
        DesignSystemButtonVariant.outlined,
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

    testWidgets('under a refused microphone Dictate is the named retry, in '
        'its resting shape even beside a take', (tester) async {
      await pump(
        tester,
        phase: const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
        takes: const [
          CheckInTake(audioEntryId: 'audio-1', length: Duration(seconds: 5)),
        ],
      );
      final dictate = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('check-in-dictate')),
      );
      expect(dictate.variant, DesignSystemButtonVariant.outlined);
      expect(dictate.size, DesignSystemButtonSize.medium);
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
      // The callout owns the retry: the field offers no second Dictate.
      expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
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
      // Recording again would only lead back here: no Dictate either.
      expect(find.byKey(const ValueKey('check-in-dictate')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('check-in-dismiss-failure')));
      expect(calls, ['dismiss']);
    });
  });
}
