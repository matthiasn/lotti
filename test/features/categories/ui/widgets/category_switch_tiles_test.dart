import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategorySwitchTiles', () {
    testWidgets('displays all three switch tiles correctly', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {},
          ),
        ),
      );

      // Verify all three switches are displayed
      expect(find.byType(LottiSwitchField), findsNWidgets(3));

      // Verify private switch
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Hide this category when private mode is enabled'),
          findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Verify active switch
      expect(find.text('Active'), findsOneWidget);
      expect(find.text("Inactive categories won't appear in selection lists"),
          findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Verify favorite switch
      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Mark this category as a favorite'), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
    });

    testWidgets('reflects correct initial switch states', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: true,
        isActive: false,
        isFavorite: true,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {},
          ),
        ),
      );

      // Get the switch fields
      final switchFields = tester
          .widgetList<LottiSwitchField>(
            find.byType(LottiSwitchField),
          )
          .toList();

      expect(switchFields[0].value, isTrue); // Private
      expect(switchFields[1].value, isFalse); // Active
      expect(switchFields[2].value, isTrue); // Favorite
    });

    testWidgets('calls onChanged with correct field when private toggled',
        (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );
      SwitchFieldType? changedField;
      bool? changedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {
              changedField = field;
              changedValue = value;
            },
          ),
        ),
      );

      // Find and tap the private switch
      final privateSwitch = find.byType(Switch).first;
      await tester.tap(privateSwitch);
      await tester.pump();

      expect(changedField, SwitchFieldType.private);
      expect(changedValue, isTrue);
    });

    testWidgets('calls onChanged with correct field when active toggled',
        (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );
      SwitchFieldType? changedField;
      bool? changedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {
              changedField = field;
              changedValue = value;
            },
          ),
        ),
      );

      // Find and tap the active switch (second one)
      final switches = find.byType(Switch);
      await tester.tap(switches.at(1));
      await tester.pump();

      expect(changedField, SwitchFieldType.active);
      expect(changedValue, isFalse);
    });

    testWidgets('calls onChanged with correct field when favorite toggled',
        (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );
      SwitchFieldType? changedField;
      bool? changedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {
              changedField = field;
              changedValue = value;
            },
          ),
        ),
      );

      // Find and tap the favorite switch (third one)
      final switches = find.byType(Switch);
      await tester.tap(switches.at(2));
      await tester.pump();

      expect(changedField, SwitchFieldType.favorite);
      expect(changedValue, isTrue);
    });

    testWidgets('has correct spacing between switches', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {},
          ),
        ),
      );

      // Verify spacing
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(CategorySwitchTiles),
          matching: find.byType(SizedBox),
        ),
      );

      // Should have 2 SizedBox widgets for spacing between 3 switches
      final spacingSizedBoxes = sizedBoxes.where((box) => box.height == 8);
      expect(spacingSizedBoxes.length, 2);
    });

    testWidgets('CategorySwitchSettings correctly stores values',
        (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: true,
        isActive: false,
        isFavorite: true,
      );

      expect(settings.isPrivate, isTrue);
      expect(settings.isActive, isFalse);
      expect(settings.isFavorite, isTrue);
    });

    testWidgets('responds to theme changes', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WidgetTestBench(
            child: CategorySwitchTiles(
              settings: settings,
              onChanged: (field, {required value}) {},
            ),
          ),
        ),
      );

      // Widget should render without errors in dark theme
      expect(find.byType(CategorySwitchTiles), findsOneWidget);
      expect(find.byType(LottiSwitchField), findsNWidgets(3));
    });

    testWidgets('handles rapid toggle changes', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );
      final changes = <(SwitchFieldType, bool)>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {
              changes.add((field, value));
            },
          ),
        ),
      );

      // Rapidly toggle all switches
      final switches = find.byType(Switch);
      await tester.tap(switches.at(0));
      await tester.tap(switches.at(1));
      await tester.tap(switches.at(2));
      await tester.pump();

      expect(changes.length, 3);
      expect(changes[0], (SwitchFieldType.private, true));
      expect(changes[1], (SwitchFieldType.active, false));
      expect(changes[2], (SwitchFieldType.favorite, true));
    });

    testWidgets('maintains correct layout structure', (tester) async {
      const settings = CategorySwitchSettings(
        isPrivate: false,
        isActive: true,
        isFavorite: false,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySwitchTiles(
            settings: settings,
            onChanged: (field, {required value}) {},
          ),
        ),
      );

      // Verify structure
      expect(find.byType(Column), findsWidgets);

      // Verify each switch has the correct components
      final switchFields = tester
          .widgetList<LottiSwitchField>(
            find.byType(LottiSwitchField),
          )
          .toList();

      for (final field in switchFields) {
        expect(field.title, isNotNull);
        expect(field.subtitle, isNotNull);
        expect(field.icon, isNotNull);
        expect(field.onChanged, isNotNull);
      }
    });

    testWidgets('all enum values are handled', (tester) async {
      // Verify all SwitchFieldType values are defined
      expect(SwitchFieldType.values.length, 3);
      expect(SwitchFieldType.values, contains(SwitchFieldType.private));
      expect(SwitchFieldType.values, contains(SwitchFieldType.active));
      expect(SwitchFieldType.values, contains(SwitchFieldType.favorite));
    });
  });
}
