import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemWidgetbookFolder', () {
    testWidgets('builds the button overview use case and includes components', (
      tester,
    ) async {
      final folder = buildDesignSystemWidgetbookFolder();
      final components = folder.children!
          .whereType<WidgetbookComponent>()
          .toList();
      final typographyComponent = components.singleWhere(
        (component) => component.name == 'Typography',
      );
      final buttonComponent = components.singleWhere(
        (component) => component.name == 'Buttons',
      );
      final avatarComponent = components.singleWhere(
        (component) => component.name == 'Avatars',
      );
      final brandingComponent = components.singleWhere(
        (component) => component.name == 'Branding',
      );
      final badgeComponent = components.singleWhere(
        (component) => component.name == 'Badges',
      );
      final chipComponent = components.singleWhere(
        (component) => component.name == 'Chips',
      );
      final breadcrumbsComponent = components.singleWhere(
        (component) => component.name == 'Breadcrumbs',
      );
      final headerComponent = components.singleWhere(
        (component) => component.name == 'Header',
      );
      final searchComponent = components.singleWhere(
        (component) => component.name == 'Search',
      );
      final toastComponent = components.singleWhere(
        (component) => component.name == 'Toast',
      );
      final dividerComponent = components.singleWhere(
        (component) => component.name == 'Divider',
      );
      final dropdownComponent = components.singleWhere(
        (component) => component.name == 'Dropdowns',
      );
      final splitButtonComponent = components.singleWhere(
        (component) => component.name == 'Split Buttons',
      );
      final tabsComponent = components.singleWhere(
        (component) => component.name == 'Tabs',
      );
      final navigationSidebarComponent = components.singleWhere(
        (component) => component.name == 'Navigation Sidebar',
      );
      final navigationTabBarComponent = components.singleWhere(
        (component) => component.name == 'Tab bar',
      );
      final calendarPickerComponent = components.singleWhere(
        (component) => component.name == 'Calendar picker',
      );
      final progressBarComponent = components.singleWhere(
        (component) => component.name == 'Progress bar',
      );
      final toggleComponent = components.singleWhere(
        (component) => component.name == 'Toggle',
      );
      final radioButtonComponent = components.singleWhere(
        (component) => component.name == 'Radio buttons',
      );
      final checkboxComponent = components.singleWhere(
        (component) => component.name == 'Checkbox',
      );
      final spinnerComponent = components.singleWhere(
        (component) => component.name == 'Spinner & loaders',
      );
      final timePickerComponent = components.singleWhere(
        (component) => component.name == 'Time picker',
      );
      final listComponent = components.singleWhere(
        (component) => component.name == 'List',
      );
      final useCase = buttonComponent.useCases.single;

      expect(folder.name, 'Design System');
      expect(components.map((component) => component.name), [
        'Typography',
        'Buttons',
        'Avatars',
        'Branding',
        'Badges',
        'Chips',
        'Breadcrumbs',
        'Header',
        'Search',
        'Toast',
        'Divider',
        'Dropdowns',
        'Split Buttons',
        'Tabs',
        'Navigation Sidebar',
        'Tab bar',
        'Calendar picker',
        'Progress bar',
        'Toggle',
        'Radio buttons',
        'Checkbox',
        'Spinner & loaders',
        'List',
        'Time picker',
      ]);
      expect(typographyComponent.useCases.single.name, 'Overview');
      expect(avatarComponent.useCases.single.name, 'Overview');
      expect(brandingComponent.useCases.single.name, 'Overview');
      expect(badgeComponent.useCases.single.name, 'Overview');
      expect(chipComponent.useCases.single.name, 'Overview');
      expect(breadcrumbsComponent.useCases.single.name, 'Overview');
      expect(headerComponent.useCases.single.name, 'Overview');
      expect(searchComponent.useCases.single.name, 'Overview');
      expect(toastComponent.useCases.single.name, 'Overview');
      expect(dividerComponent.useCases.single.name, 'Overview');
      expect(dropdownComponent.useCases.single.name, 'Overview');
      expect(splitButtonComponent.useCases.single.name, 'Overview');
      expect(tabsComponent.useCases.single.name, 'Overview');
      expect(navigationSidebarComponent.useCases.single.name, 'Overview');
      expect(navigationTabBarComponent.useCases.single.name, 'Overview');
      expect(calendarPickerComponent.useCases.single.name, 'Overview');
      expect(progressBarComponent.useCases.single.name, 'Overview');
      expect(toggleComponent.useCases.single.name, 'Overview');
      expect(radioButtonComponent.useCases.single.name, 'Overview');
      expect(checkboxComponent.useCases.single.name, 'Overview');
      expect(spinnerComponent.useCases.single.name, 'Overview');
      expect(timePickerComponent.useCases.single.name, 'Overview');
      expect(listComponent.useCases.single.name, 'Overview');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);

      await tester.tap(find.byType(DesignSystemButton).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
