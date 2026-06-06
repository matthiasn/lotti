import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(widget));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassIconContainer', () {
    testWidgets('renders child widget', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.arrow_back),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('uses default size of 40', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.close),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassIconContainer),
          matching: find.byType(Container),
        ),
      );

      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });

    testWidgets('uses custom size when provided', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          size: 60,
          child: Icon(Icons.menu),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassIconContainer),
          matching: find.byType(Container),
        ),
      );

      expect(container.constraints?.maxWidth, 60);
      expect(container.constraints?.maxHeight, 60);
    });

    testWidgets('contains BackdropFilter for blur effect', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.settings),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);

      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );

      // Verify blur filter is applied
      expect(backdropFilter.filter, isA<ImageFilter>());
    });

    testWidgets('contains ClipRRect for rounded corners', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.home),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('uses custom borderRadius when provided', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          borderRadius: 8,
          child: Icon(Icons.star),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));

      expect(
        clipRRect.borderRadius,
        equals(BorderRadius.circular(8)),
      );
    });

    testWidgets('centers the child widget', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.favorite),
        ),
      );

      // Find the Center widget that is a descendant of GlassIconContainer
      // (there may be multiple due to Icon also having a center)
      expect(
        find.descendant(
          of: find.byType(GlassIconContainer),
          matching: find.byType(Center),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('has semi-transparent black background', (tester) async {
      await _pump(
        tester,
        const GlassIconContainer(
          child: Icon(Icons.check),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassIconContainer),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(Colors.black.withValues(alpha: 0.3)));
    });

    testWidgets('can be used inside IconButton', (tester) async {
      var tapped = false;

      await _pump(
        tester,
        IconButton(
          onPressed: () => tapped = true,
          icon: const GlassIconContainer(
            child: Icon(Icons.chevron_left),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(tapped, isTrue);
    });
  });
}
