import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_sidebar_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemNavigationSidebarWidgetbookComponent', () {
    testWidgets('builds the navigation sidebar overview use case', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1200, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final component = buildDesignSystemNavigationSidebarWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Navigation Sidebar');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Sidebar Variants'), findsOneWidget);
      expect(find.text('Daily Filter'), findsOneWidget);
      expect(find.text('Expanded'), findsAtLeastNWidgets(2));
      expect(find.text('Collapsed'), findsAtLeastNWidgets(2));
      expect(find.text('Light Theme Expanded'), findsNothing);
      expect(find.text('Light Theme Collapsed'), findsNothing);
      expect(find.text('Dark Theme Expanded'), findsNothing);
      expect(find.text('Dark Theme Collapsed'), findsNothing);
      expect(find.text('My Daily'), findsAtLeastNWidgets(1));
      expect(find.text('Tasks'), findsAtLeastNWidgets(1));
      expect(find.text('Projects'), findsAtLeastNWidgets(1));
      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('April 2025'), findsOneWidget);
      expect(find.text('Filter by block'), findsAtLeastNWidgets(2));
      expect(find.text('Holiday'), findsOneWidget);
      expect(find.text('Lotti Tasks'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.byType(DesignSystemBrandLogo), findsOneWidget);
      expect(find.text('Tab Bar Variants'), findsNothing);
      expect(find.text('Sub-components'), findsNothing);

      final newLabel = tester.renderObject<RenderParagraph>(
        find.text('New').first,
      );

      expect(newLabel.didExceedMaxLines, isFalse);
      await tester.tap(find.text('New').first);
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('April 2025'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(DesignSystemButton), findsOneWidget);
      final actionSlot = find.byKey(
        const Key('collapsed-sidebar-action-slot'),
      );
      final actionSlotSize = tester.getSize(actionSlot);
      final collapsedPlusIcon = find.descendant(
        of: actionSlot,
        matching: find.byIcon(Icons.add_rounded),
      );
      final buttonCenter = tester.getCenter(actionSlot);
      final iconCenter = tester.getCenter(collapsedPlusIcon);

      expect(actionSlotSize.height, moreOrLessEquals(44, epsilon: 2));
      expect(actionSlotSize.width, moreOrLessEquals(44, epsilon: 2));
      expect(iconCenter.dx, moreOrLessEquals(buttonCenter.dx, epsilon: 0.01));
      expect(iconCenter.dy, moreOrLessEquals(buttonCenter.dy, epsilon: 0.01));
    });
  });
}
