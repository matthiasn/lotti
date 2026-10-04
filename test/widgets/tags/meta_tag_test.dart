import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/tags/meta_tag.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) => makeTestableWidget2(
    Theme(
      data: DesignSystemTheme.dark(),
      child: Scaffold(body: child),
    ),
  );

  group('CategoryTag', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Work',
            icon: LottiIcons.work,
            color: Colors.blue,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.byIcon(LottiIcons.work), findsOneWidget);
    });

    testWidgets('uses white text on a near-black background', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Ollama',
            icon: LottiIcons.computer,
            // Seeded "Ollama Charcoal" (#0F172A) — the case that prompted
            // the contrast-aware foreground flip.
            color: Color(0xFF0F172A),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Ollama'));
      expect(label.style?.color, equals(Colors.white));
      final iconWidget = tester.widget<Icon>(find.byIcon(LottiIcons.computer));
      expect(iconWidget.color, equals(Colors.white));
    });

    testWidgets('uses black text on a near-white background', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Pale',
            icon: LottiIcons.label,
            color: Color(0xFFF8FAFC),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Pale'));
      expect(label.style?.color, equals(Colors.black));
    });
  });

  group('CategoryTag with onTap', () {
    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          CategoryTag(
            label: 'Tappable',
            icon: LottiIcons.label,
            color: Colors.green,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('Tappable'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not wrap in InkWell when onTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Static',
            icon: LottiIcons.label,
            color: Colors.green,
          ),
        ),
      );
      await tester.pump();

      // No InkWell from CategoryTag (Material/InkWell not added)
      expect(
        find.ancestor(
          of: find.text('Static'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });
  });
}
