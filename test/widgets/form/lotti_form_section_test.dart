import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/form/lotti_form_section.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, LottiFormSection section) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(section));

void main() {
  group('LottiFormSection', () {
    testWidgets('renders title and children, no icon or description '
        'by default', (tester) async {
      await _pump(
        tester,
        const LottiFormSection(
          title: 'General',
          children: [Text('child a'), Text('child b')],
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('child a'), findsOneWidget);
      expect(find.text('child b'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders icon and description when provided', (tester) async {
      await _pump(
        tester,
        const LottiFormSection(
          title: 'Sync',
          icon: Icons.sync,
          description: 'Configure synchronization',
          children: [SizedBox.shrink()],
        ),
      );

      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.text('Configure synchronization'), findsOneWidget);
    });

    testWidgets('header uses gradient decoration with rounded border', (
      tester,
    ) async {
      await _pump(
        tester,
        const LottiFormSection(
          title: 'Styled',
          children: [SizedBox.shrink()],
        ),
      );

      final headerContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Styled'),
          matching: find.byType(Container),
        ),
      );
      final decoration = headerContainer.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNotNull);
    });

    testWidgets('custom padding overrides the header default', (tester) async {
      const customPadding = EdgeInsets.all(30);
      await _pump(
        tester,
        const LottiFormSection(
          title: 'Padded',
          padding: customPadding,
          children: [SizedBox.shrink()],
        ),
      );

      final headerContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Padded'),
          matching: find.byType(Container),
        ),
      );
      expect(headerContainer.padding, customPadding);
    });
  });
}
