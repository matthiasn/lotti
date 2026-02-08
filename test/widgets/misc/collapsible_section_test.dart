import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/collapsible_section.dart';

import '../../widget_test_utils.dart';

void main() {
  group('CollapsibleSection', () {
    testWidgets('renders header and child when expanded', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('chevron is not rotated when expanded', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
    });

    testWidgets('tapping chevron collapses and rotates', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(-0.25));
    });

    testWidgets('tapping header text also collapses', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Header'));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(-0.25));
    });

    testWidgets('double tap re-expands', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Re-expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
    });

    testWidgets('collapsed section shows SizedBox.shrink as child',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      final animatedSize =
          tester.widget<AnimatedSize>(find.byType(AnimatedSize));
      expect(animatedSize.child, isA<SizedBox>());
    });

    testWidgets('has AnimatedSize widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CollapsibleSection(
            header: Text('Header'),
            child: Text('Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSize), findsOneWidget);
    });
  });
}
