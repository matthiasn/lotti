import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input_mentions.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late TextEditingController controller;
  late int sends;
  late int recordings;
  late int cancels;
  late int dones;
  late int retries;

  setUp(() {
    controller = TextEditingController();
    sends = recordings = cancels = dones = retries = 0;
  });

  const categories = [
    DesignSystemChatInputMention(label: 'Work', color: Color(0xFF4AB6E8)),
    DesignSystemChatInputMention(label: 'Workshop prep'),
    DesignSystemChatInputMention(label: 'Woodworking'),
    DesignSystemChatInputMention(label: 'Lotti'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String text = '',
    double width = 720,
    DesignSystemChatInputPhase phase = DesignSystemChatInputPhase.compose,
    List<double> levels = const [],
    String? partial,
    String? helper = 'Type @ to name a category',
    bool? keyboardHint,
    String? busy,
    String? error,
    bool retry = false,
    bool canSend = true,
    bool canRecord = true,
    bool enabled = true,
    List<DesignSystemChatInputMention> mentions = const [],
  }) async {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: SizedBox(
            width: width,
            child: DesignSystemChatInput(
              controller: controller,
              hintText: 'Ask anything…',
              helperText: helper,
              showKeyboardHint: keyboardHint,
              phase: phase,
              levels: levels,
              elapsed: const Duration(minutes: 1, seconds: 7),
              partialTranscript: partial,
              busyText: busy,
              errorText: error,
              onRetry: retry ? () => retries++ : null,
              enabled: enabled,
              mentionOptions: mentions,
              onSend: canSend ? () => sends++ : null,
              onStartRecording: canRecord ? () => recordings++ : null,
              onCancelRecording: () => cancels++,
              onFinishRecording: () => dones++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  IconButton disc(WidgetTester tester, Key key) => tester.widget<IconButton>(
    find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
  );

  Color? fill(WidgetTester tester, Key key) => disc(
    tester,
    key,
  ).style!.backgroundColor!.resolve(const {});

  group('composing', () {
    testWidgets('empty: the mic is the teal control and there is no send', (
      tester,
    ) async {
      await pump(tester);
      final tokens = tester.element(find.byType(TextField)).designTokens;

      expect(find.byKey(DesignSystemChatInputKeys.send), findsNothing);
      expect(
        fill(tester, DesignSystemChatInputKeys.mic),
        tokens.colors.interactive.enabled,
      );
      await tester.tap(find.byKey(DesignSystemChatInputKeys.mic));
      expect(recordings, 1);
    });

    testWidgets('with words, send turns teal and the mic stays, quiet — '
        'voice is never taken away', (tester) async {
      await pump(tester, text: 'What is due today?');
      final tokens = tester.element(find.byType(TextField)).designTokens;

      expect(
        fill(tester, DesignSystemChatInputKeys.send),
        tokens.colors.interactive.enabled,
      );
      expect(
        fill(tester, DesignSystemChatInputKeys.mic),
        tokens.colors.surface.enabled,
      );
      await tester.tap(find.byKey(DesignSystemChatInputKeys.send));
      await tester.tap(find.byKey(DesignSystemChatInputKeys.mic));
      expect((sends, recordings), (1, 1));
    });

    testWidgets('a long dictation wraps over the full width, never under a '
        'button, up to six lines', (tester) async {
      await pump(tester, text: List.filled(60, 'Berlin').join(' '));

      final field = tester.getRect(find.byType(TextField));
      final send = tester.getRect(find.byKey(DesignSystemChatInputKeys.send));
      expect(field.bottom, lessThanOrEqualTo(send.top));
      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 6);
      expect(field.height, greaterThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a phone, every control still fits beside the helper', (
      tester,
    ) async {
      await pump(tester, text: 'Hello', width: 320, keyboardHint: true);

      expect(tester.takeException(), isNull);
      expect(find.byKey(DesignSystemChatInputKeys.mic), findsOne);
      expect(find.byKey(DesignSystemChatInputKeys.send), findsOne);
    });

    testWidgets('Enter sends; Shift+Enter does not', (tester) async {
      await pump(tester, text: 'Hello');
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sends, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 1);
    });

    testWidgets("Enter while an IME composes is the IME's, not a send", (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      controller.value = const TextEditingValue(
        text: 'にほん',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 0);
    });

    testWidgets('Enter on an empty field sends nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 0);
    });

    testWidgets('the helper says what the host supports, then the keyboard '
        'where there is one', (tester) async {
      await pump(tester, keyboardHint: true);
      expect(
        tester.widget<Text>(find.byKey(DesignSystemChatInputKeys.helper)).data,
        'Type @ to name a category · Enter sends · Shift+Enter for a new line',
      );

      await pump(tester, helper: null, keyboardHint: false);
      expect(
        tester.widget<Text>(find.byKey(DesignSystemChatInputKeys.helper)).data,
        isEmpty,
      );
    });

    testWidgets('by default the keyboard is mentioned on a desktop only', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await pump(tester);
      expect(find.textContaining('Shift+Enter'), findsOne);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pump(tester);
      expect(find.textContaining('Shift+Enter'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a host that cannot send or record leaves the controls off', (
      tester,
    ) async {
      await pump(tester, text: 'Hi', canSend: false, canRecord: false);
      expect(disc(tester, DesignSystemChatInputKeys.send).onPressed, isNull);
      expect(disc(tester, DesignSystemChatInputKeys.mic).onPressed, isNull);

      await pump(tester, text: 'Hi', enabled: false);
      expect(disc(tester, DesignSystemChatInputKeys.mic).onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    });

    testWidgets('the field takes focus, and its edge says so', (tester) async {
      await pump(tester);
      final tokens = tester.element(find.byType(TextField)).designTokens;
      Color edge() =>
          ((tester
                              .widget<AnimatedContainer>(
                                find.byKey(DesignSystemChatInputKeys.card),
                              )
                              .decoration!
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      expect(edge(), isNot(tokens.colors.interactive.enabled));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(edge(), tokens.colors.interactive.enabled);
    });
  });

  group('recording', () {
    testWidgets('one row: cancel, the time, the voice across all the width '
        'left, and Done', (tester) async {
      await pump(
        tester,
        phase: DesignSystemChatInputPhase.recording,
        levels: List.filled(50, 0.5),
      );
      await tester.pumpAndSettle();

      expect(find.text('1:07'), findsOne);
      final cancel = tester.getRect(
        find.byKey(DesignSystemChatInputKeys.cancel),
      );
      final wave = tester.getRect(
        find.byKey(DesignSystemChatInputKeys.waveform),
      );
      final done = tester.getRect(find.byKey(DesignSystemChatInputKeys.done));
      expect(wave.left, greaterThan(cancel.right));
      expect(done.left, greaterThanOrEqualTo(wave.right));
      // The bars take everything the row does not need for its controls.
      expect(wave.width, greaterThan(720 * 0.6));
      expect(
        tester
            .widget<DesignSystemVoiceWaveform>(
              find.byKey(DesignSystemChatInputKeys.waveform),
            )
            .levels,
        hasLength(50),
      );
      expect(find.byKey(DesignSystemChatInputKeys.mic), findsNothing);
      expect(find.text('Listening...'), findsOne);

      await tester.tap(find.byKey(DesignSystemChatInputKeys.done));
      await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
      expect((dones, cancels), (1, 1));
    });

    testWidgets('Escape cancels the take', (tester) async {
      await pump(tester, phase: DesignSystemChatInputPhase.recording);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(cancels, 1);
    });

    testWidgets('Escape still cancels once the field gives way to the '
        'transcript', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // A take that hits its limit goes straight to transcribing, from
      // focus in the field.
      await pump(tester, phase: DesignSystemChatInputPhase.transcribing);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(cancels, 1);
    });

    testWidgets('the words already written stay in view while talking', (
      tester,
    ) async {
      await pump(
        tester,
        text: 'And also',
        phase: DesignSystemChatInputPhase.recording,
      );
      expect(find.text('And also'), findsOne);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);
    });
  });

  group('transcribing', () {
    testWidgets('what has arrived shows where it will land, after the words '
        'already there; cancel and a spinner hold the controls', (
      tester,
    ) async {
      await pump(
        tester,
        text: 'First,',
        phase: DesignSystemChatInputPhase.transcribing,
        partial: 'then Berlin',
      );
      // The spinner never settles: let the switch between rows finish.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('First, then Berlin'), findsOne);
      expect(find.byType(DesignSystemSpinner), findsOne);
      expect(find.byKey(DesignSystemChatInputKeys.mic), findsNothing);
      await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
      expect(cancels, 1);
    });

    testWidgets('before any words, it says it is transcribing', (tester) async {
      await pump(tester, phase: DesignSystemChatInputPhase.transcribing);
      expect(find.text('Transcribing…'), findsWidgets);
    });
  });

  testWidgets('busy: says what is happening in the field and nothing can be '
      'sent or said', (tester) async {
    await pump(tester, text: 'Hi', busy: 'Answering…');

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(disc(tester, DesignSystemChatInputKeys.mic).onPressed, isNull);
    expect(disc(tester, DesignSystemChatInputKeys.send).onPressed, isNull);
  });

  testWidgets('an error stands above the card, the words kept, with Try '
      'again when the host offers it', (tester) async {
    await pump(tester, text: 'What is due?', error: 'Did not go', retry: true);

    final error = tester.getRect(find.byKey(DesignSystemChatInputKeys.error));
    final card = tester.getRect(find.byKey(DesignSystemChatInputKeys.card));
    expect(error.bottom, lessThanOrEqualTo(card.top));
    expect(find.text('What is due?'), findsOne);
    await tester.tap(find.byKey(DesignSystemChatInputKeys.retry));
    expect(retries, 1);

    await pump(tester, error: 'Did not go');
    expect(find.byKey(DesignSystemChatInputKeys.retry), findsNothing);
  });

  group('@', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.pump();
    }

    List<String> shown(WidgetTester tester) => [
      for (final element
          in find
              .descendant(
                of: find.byKey(DesignSystemChatInputMentionKeys.list),
                matching: find.byType(InkWell),
              )
              .evaluate())
        ((element.widget as InkWell).key! as ValueKey<String>).value
            .replaceFirst(
              'ds-chat-input-mention-',
              '',
            ),
    ];

    testWidgets('offers what matches the word after it — starting with it '
        'first — above the card', (tester) async {
      await pump(tester, mentions: categories);
      await type(tester, 'Overdue in @wo');

      expect(shown(tester), ['Work', 'Workshop prep', 'Woodworking']);
      final list = tester.getRect(
        find.byKey(DesignSystemChatInputMentionKeys.list),
      );
      final card = tester.getRect(find.byKey(DesignSystemChatInputKeys.card));
      expect(list.bottom, lessThanOrEqualTo(card.top));
    });

    testWidgets('a tap puts @Label in the text and closes the list', (
      tester,
    ) async {
      await pump(tester, mentions: categories);
      await type(tester, 'Overdue in @wo');

      await tester.tap(
        find.byKey(DesignSystemChatInputMentionKeys.option('Woodworking')),
      );
      await tester.pump();

      expect(controller.text, 'Overdue in @Woodworking ');
      expect(controller.selection.baseOffset, controller.text.length);
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);
    });

    testWidgets('the arrows move through it and Enter picks — it does not '
        'send', (tester) async {
      await pump(tester, mentions: categories);
      await type(tester, '@wo');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, '@Workshop prep ');
      expect(sends, 0);
    });

    testWidgets('Escape closes it and keeps what was typed; Tab picks', (
      tester,
    ) async {
      await pump(tester, mentions: categories);
      await type(tester, 'In @lo');
      expect(shown(tester), ['Lotti']);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);
      expect(controller.text, 'In @lo');

      // A host rebuild does not bring back what Escape closed.
      await pump(tester, text: 'In @lo', mentions: categories);
      await tester.pump();
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);

      await type(tester, 'In @L');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.text, 'In @Lotti ');
    });

    testWidgets('no options, no list; an @ inside a word is not one', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, '@wo');
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);

      await pump(tester, mentions: categories);
      await type(tester, 'mail me@wo');
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);

      await type(tester, '@zzz');
      expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsNothing);
    });
  });

  test('mention options compare by what they hold', () {
    expect(
      categories.first,
      const DesignSystemChatInputMention(
        label: 'Work',
        color: Color(0xFF4AB6E8),
      ),
    );
    expect(
      categories.first.hashCode,
      const DesignSystemChatInputMention(
        label: 'Work',
        color: Color(0xFF4AB6E8),
      ).hashCode,
    );
  });

  test('the mention controller moves round, and its moves and dismissals '
      'are no-ops while closed', () {
    final mentions = DesignSystemChatInputMentionController()
      ..move(1)
      ..dismiss();
    expect(mentions.isOpen, isFalse);
    mentions.update(
      const TextEditingValue(
        text: '@w',
        selection: TextSelection.collapsed(offset: 2),
      ),
      options: categories,
    );
    expect(mentions.shown, hasLength(3));
    mentions.move(-1);
    expect(mentions.highlighted?.label, 'Woodworking');
    // A selection, not a caret, completes nothing.
    expect(
      mentions.query(
        const TextEditingValue(
          text: '@w',
          selection: TextSelection(baseOffset: 0, extentOffset: 2),
        ),
      ),
      isNull,
    );
    // An insert with nothing to replace leaves the text as it is.
    const plain = TextEditingValue(
      text: 'Hi',
      selection: TextSelection.collapsed(offset: 0),
    );
    expect(
      DesignSystemChatInputMentionController().insert(plain, categories.first),
      plain,
    );
    mentions.dispose();
  });

  testWidgets('a host swapping its controller and focus node keeps the '
      'input following the new ones, @ list included', (tester) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final focusA = FocusNode();
    final focusB = FocusNode();
    addTearDown(() {
      first.dispose();
      second.dispose();
      focusA.dispose();
      focusB.dispose();
    });
    Widget input(TextEditingController c, FocusNode f) =>
        makeTestableWidgetWithScaffold(
          DesignSystemChatInput(
            controller: c,
            focusNode: f,
            hintText: 'Ask',
            mentionOptions: categories,
            onSend: () {},
            onStartRecording: () {},
          ),
        );
    await tester.pumpWidget(input(first, focusA));
    await tester.pumpWidget(input(second, focusB));
    focusB.requestFocus();
    second.value = const TextEditingValue(
      text: '@shop',
      selection: TextSelection.collapsed(offset: 5),
    );
    await tester.pump();
    await tester.pump();

    // A word inside a label matches too, after those starting with it.
    expect(
      find.byKey(DesignSystemChatInputMentionKeys.option('Workshop prep')),
      findsOne,
    );
    expect(find.byKey(DesignSystemChatInputKeys.send), findsOne);
  });
}
