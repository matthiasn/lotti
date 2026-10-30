import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_radio_row.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool selected,
    VoidCallback? onTap,
    List<InlineSpan>? caption,
    Widget? tag,
    Widget? trailing,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      TtsVoiceRadioRow(
        title: 'Ada',
        selected: selected,
        onTap: onTap ?? () {},
        caption: caption,
        tag: tag,
        trailing: trailing,
      ),
    ),
  );

  testWidgets('the selected voice is marked by shape, weight and semantics', (
    tester,
  ) async {
    await pump(tester, selected: true);
    expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    final selectedWeight = tester
        .widget<Text>(find.text('Ada'))
        .style!
        .fontWeight;
    expect(
      tester.getSemantics(find.text('Ada')),
      isSemantics(
        label: 'Ada',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await pump(tester, selected: false);
    expect(find.byIcon(LottiIcons.radioUnselected), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
    expect(
      tester.widget<Text>(find.text('Ada')).style!.fontWeight!.value,
      lessThan(selectedWeight!.value),
    );
  });

  testWidgets('the whole row is the target and at least a compact target '
      'tall', (tester) async {
    var taps = 0;
    await pump(tester, selected: false, onTap: () => taps++);
    await tester.tap(find.text('Ada'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(TtsVoiceRadioRow)).height,
      greaterThanOrEqualTo(TapTargets.compact),
    );
  });

  testWidgets('shows the caption, tag and trailing control it is given, and '
      'no empty caption line', (tester) async {
    await pump(
      tester,
      selected: false,
      caption: const [TextSpan(text: 'sunny, easygoing')],
      tag: const Text('Default'),
      trailing: const Icon(Icons.volume_up),
    );
    expect(find.text('sunny, easygoing', findRichText: true), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    // The tag sits on the name's line, after it.
    expect(
      tester.getCenter(find.text('Default')).dy,
      closeTo(tester.getCenter(find.text('Ada')).dy, 4),
    );

    await pump(tester, selected: false, caption: const []);
    expect(find.byType(Text), findsOneWidget);
  });
}
