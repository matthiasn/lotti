import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('PersonCardHeader', () {
    testWidgets('lays out title, caption and trailing action', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const PersonCardHeader(
            title: 'Tasks',
            caption: Text('2 linked'),
            trailing: Text('Link task'),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('2 linked'), findsOneWidget);
      expect(find.text('Link task'), findsOneWidget);
      // The action is pushed to the far edge; the caption stays by the title.
      expect(
        tester.getTopLeft(find.text('Link task')).dx,
        greaterThan(tester.getTopRight(find.text('2 linked')).dx),
      );
    });

    testWidgets('a count reads as text after the title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const PersonCardHeader(
            title: 'About Pip',
            count: 2,
            countKey: ValueKey('count'),
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('count'))).data,
        '· 2',
      );
    });
  });

  group('personDisclosure', () {
    testWidgets('a quiet line led by a chevron that turns when open', (
      tester,
    ) async {
      var pressed = 0;
      Widget build({required bool open}) => makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => personDisclosure(
            context,
            key: const ValueKey('fold'),
            label: 'Show all (2)',
            open: open,
            onPressed: () => pressed++,
          ),
        ),
      );

      await tester.pumpWidget(build(open: false));
      final closed = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('fold')),
      );
      expect(closed.variant, DesignSystemButtonVariant.quiet);
      expect(closed.leadingIcon, LottiIcons.expand);
      await tester.tap(find.text('Show all (2)'));
      expect(pressed, 1);

      await tester.pumpWidget(build(open: true));
      expect(
        tester
            .widget<DesignSystemButton>(find.byKey(const ValueKey('fold')))
            .leadingIcon,
        LottiIcons.chevronUp,
      );
    });
  });
}
