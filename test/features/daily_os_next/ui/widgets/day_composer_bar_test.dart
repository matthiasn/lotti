import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/chat/chat_composer_field.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_composer_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final voices = <int>[];
  final texts = <String>[];

  setUp(() {
    voices.clear();
    texts.clear();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        Material(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: DayComposerBar(
              hintText: 'Talk or type a check-in',
              onStartVoice: () => voices.add(1),
              onSubmitText: texts.add,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(size: size),
      ),
    );
    await tester.pump();
  }

  String tooltip(WidgetTester tester, {required bool send}) {
    final messages = tester.element(find.byType(DayComposerBar)).messages;
    return send ? messages.chatInputSendTooltip : messages.chatInputRecordVoice;
  }

  testWidgets('shows the hint in the shared chat field', (tester) async {
    await pump(tester);

    expect(find.byType(ChatComposerField), findsOneWidget);
    expect(find.text('Talk or type a check-in'), findsOneWidget);
  });

  testWidgets('the mic starts a spoken check-in and sends no text', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(findMaterialTooltip(tooltip(tester, send: false)));
    await tester.pump();

    expect(voices, [1]);
    expect(texts, isEmpty);
  });

  testWidgets('sent words arrive trimmed and stay in the field', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '  Finish the deck  ');
    await tester.pump();
    await tester.tap(findMaterialTooltip(tooltip(tester, send: true)));
    await tester.pump();

    expect(texts, ['Finish the deck']);
    expect(voices, isEmpty);
    // Backing out of the check-in it opened must not lose the words.
    expect(find.text('  Finish the deck  '), findsOneWidget);
  });

  testWidgets('keeps to the reading column on a wide window', (tester) async {
    await pump(tester, size: const Size(1600, 900));

    final width = tester.getSize(find.byType(ChatComposerField)).width;
    expect(width, lessThanOrEqualTo(DayComposerBar.maxWidth));
  });

  testWidgets('spans a phone, inside the strip padding', (tester) async {
    const phone = Size(390, 844);
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, size: phone);

    final field = tester.getRect(find.byType(ChatComposerField));
    expect(field.width, lessThan(phone.width));
    expect(field.width, greaterThan(phone.width * 0.8));
  });

  testWidgets('text a host sets turns the mic into send', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      makeTestableWidget2(
        Material(
          child: DayComposerBar(
            hintText: 'Talk or type a check-in',
            controller: controller,
            onStartVoice: () => voices.add(1),
            onSubmitText: texts.add,
          ),
        ),
      ),
    );
    await tester.pump();

    controller.text = 'Finished transcript';
    await tester.pump();
    await tester.tap(findMaterialTooltip(tooltip(tester, send: true)));
    await tester.pump();

    expect(texts, ['Finished transcript']);
  });

  testWidgets("a replacement takes the field's place; errors read below", (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        Material(
          child: DayComposerBar(
            hintText: 'Talk or type a check-in',
            replacement: const Text('Recording…'),
            errorText: 'The microphone is off',
            onStartVoice: () => voices.add(1),
            onSubmitText: texts.add,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recording…'), findsOneWidget);
    expect(find.byType(ChatComposerField), findsNothing);
    expect(find.text('The microphone is off'), findsOneWidget);
  });

  testWidgets('a host swapping its controller keeps the field following it', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget bar(TextEditingController controller) => makeTestableWidget2(
      Material(
        child: DayComposerBar(
          hintText: 'Talk or type a check-in',
          controller: controller,
          onStartVoice: () => voices.add(1),
          onSubmitText: texts.add,
        ),
      ),
    );

    await tester.pumpWidget(bar(first));
    await tester.pumpWidget(bar(second));
    await tester.pump();

    // The old controller no longer drives the bar; the new one does.
    first.text = 'Stale words';
    second.text = 'Fresh words';
    await tester.pump();
    await tester.tap(findMaterialTooltip(tooltip(tester, send: true)));
    await tester.pump();

    expect(texts, ['Fresh words']);
  });

  group('trailing', () {
    const stageKey = Key('stage');

    Future<void> pumpWithTrailing(WidgetTester tester, double width) async {
      final size = Size(width, 800);
      setTestSurfaceSize(tester, size);
      await tester.pumpWidget(
        makeTestableWidget2(
          Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: DayComposerBar(
                hintText: 'What should change?',
                onStartVoice: () {},
                onSubmitText: texts.add,
                trailing: const SizedBox(key: stageKey, width: 120, height: 48),
              ),
            ),
          ),
          mediaQueryData: MediaQueryData(size: size),
        ),
      );
      await tester.pump();
    }

    testWidgets('sits beside the field, on its centre line, while it leaves '
        'the field half the bar', (tester) async {
      await pumpWithTrailing(tester, 402);

      final field = tester.getRect(find.byType(ChatComposerField));
      final stage = tester.getRect(find.byKey(stageKey));
      expect(stage.left, greaterThan(field.right));
      expect(stage.center.dy, closeTo(field.center.dy, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('moves under the field, full width, once it needs more', (
      tester,
    ) async {
      // 200 wide less the bar's padding leaves the field under half.
      await pumpWithTrailing(tester, 240);

      final field = tester.getRect(find.byType(ChatComposerField));
      final stage = tester.getRect(find.byKey(stageKey));
      expect(stage.top, greaterThan(field.bottom));
      expect(stage.width, field.width);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gives the field the whole width once there are words', (
      tester,
    ) async {
      await pumpWithTrailing(tester, 402);

      await tester.enterText(find.byType(TextField), 'less meetings');
      await tester.pump();

      expect(find.byKey(stageKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
