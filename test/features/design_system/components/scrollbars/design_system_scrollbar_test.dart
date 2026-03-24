import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemScrollbar', () {
    testWidgets('wraps child with Scrollbar widget', (tester) async {
      const scrollbarKey = Key('basic-scrollbar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(Scrollbar),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies ScrollbarTheme to child', (tester) async {
      const scrollbarKey = Key('themed-scrollbar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(ScrollbarTheme),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies default size theme data', (tester) async {
      const scrollbarKey = Key('default-scrollbar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final scrollbarTheme = tester.widget<ScrollbarTheme>(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(ScrollbarTheme),
        ),
      );

      expect(
        scrollbarTheme.data.thickness?.resolve({}),
        8,
      );
      expect(scrollbarTheme.data.radius, const Radius.circular(10));
    });

    testWidgets('applies small size theme data', (tester) async {
      const scrollbarKey = Key('small-scrollbar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              size: DesignSystemScrollbarSize.small,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final scrollbarTheme = tester.widget<ScrollbarTheme>(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(ScrollbarTheme),
        ),
      );

      expect(
        scrollbarTheme.data.thickness?.resolve({}),
        4,
      );
    });

    testWidgets('uses token-driven thumb color', (tester) async {
      const scrollbarKey = Key('color-scrollbar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final scrollbarTheme = tester.widget<ScrollbarTheme>(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(ScrollbarTheme),
        ),
      );

      final thumbColor = scrollbarTheme.data.thumbColor?.resolve({});
      expect(thumbColor, isNotNull);
      expect(thumbColor!.a, closeTo(0.64, 0.01));
    });

    testWidgets('passes thumbVisibility to Scrollbar', (tester) async {
      const scrollbarKey = Key('visible-scrollbar');
      final controller = ScrollController();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            height: 200,
            child: DesignSystemScrollbar(
              key: scrollbarKey,
              controller: controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      addTearDown(controller.dispose);

      final scrollbar = tester.widget<Scrollbar>(
        find.descendant(
          of: find.byKey(scrollbarKey),
          matching: find.byType(Scrollbar),
        ),
      );

      expect(scrollbar.thumbVisibility, isTrue);
    });
  });
}
