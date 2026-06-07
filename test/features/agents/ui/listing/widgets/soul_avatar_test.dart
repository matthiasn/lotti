import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';

void main() {
  group('SoulAvatar', () {
    testWidgets(
      'whitespace-only label falls back to "?" rather than a blank glyph',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SoulAvatar(label: '   ', hue: 200)),
          ),
        );
        expect(find.text('?'), findsOneWidget);
      },
    );

    testWidgets('non-empty label uses its first character (uppercased)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SoulAvatar(label: 'laura', hue: 142)),
        ),
      );
      expect(find.text('L'), findsOneWidget);
    });
  });

  testWidgets('derives all three tile tones from the single hue', (
    tester,
  ) async {
    const hue = 200;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SoulAvatar(label: 'x', hue: hue),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(
      decoration.color,
      HSLColor.fromAHSL(1, hue.toDouble(), 0.30, 0.22).toColor(),
    );
    expect(
      (decoration.border! as Border).top.color,
      HSLColor.fromAHSL(0.6, hue.toDouble(), 0.40, 0.42).toColor(),
    );
    final text = tester.widget<Text>(find.text('X'));
    expect(
      text.style!.color,
      HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.85).toColor(),
    );
  });
}
