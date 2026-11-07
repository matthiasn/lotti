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
}
