import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

import '../../../../test_helper.dart';

/// Per-field display expectations, in tile render order.
const _expectedTiles = <SwitchFieldType, (String, String, IconData)>{
  SwitchFieldType.private: (
    'Private',
    'Hide this category when private mode is enabled',
    Icons.lock_outline,
  ),
  SwitchFieldType.active: (
    'Active',
    "Inactive categories won't appear in selection lists",
    Icons.visibility_outlined,
  ),
  SwitchFieldType.favorite: (
    'Favorite',
    'Mark this category as a favorite',
    Icons.star_outline,
  ),
  SwitchFieldType.availableForDayPlan: (
    'Day planning',
    'Make this category available for selection in the day plan',
    Icons.today_outlined,
  ),
};

CategorySwitchSettings _settings({
  bool isPrivate = false,
  bool isActive = true,
  bool isFavorite = false,
  bool isAvailableForDayPlan = false,
}) {
  return CategorySwitchSettings(
    isPrivate: isPrivate,
    isActive: isActive,
    isFavorite: isFavorite,
    isAvailableForDayPlan: isAvailableForDayPlan,
  );
}

Future<void> _pumpTiles(
  WidgetTester tester, {
  required CategorySwitchSettings settings,
  SwitchFieldChanged? onChanged,
}) {
  return tester.pumpWidget(
    WidgetTestBench(
      child: CategorySwitchTiles(
        settings: settings,
        onChanged: onChanged ?? (field, {required value}) {},
      ),
    ),
  );
}

void main() {
  group('CategorySwitchTiles', () {
    testWidgets('displays every switch tile with title, subtitle, and icon', (
      tester,
    ) async {
      await _pumpTiles(tester, settings: _settings());

      expect(
        find.byType(LottiSwitchField),
        findsNWidgets(SwitchFieldType.values.length),
      );

      for (final (title, subtitle, icon) in _expectedTiles.values) {
        expect(find.text(title), findsOneWidget);
        expect(find.text(subtitle), findsOneWidget);
        expect(find.byIcon(icon), findsOneWidget);
      }
    });

    testWidgets('reflects the initial value of every switch', (tester) async {
      await _pumpTiles(
        tester,
        settings: _settings(
          isPrivate: true,
          isActive: false,
          isFavorite: true,
          isAvailableForDayPlan: true,
        ),
      );

      final switchFields = tester
          .widgetList<LottiSwitchField>(find.byType(LottiSwitchField))
          .toList();

      expect(switchFields[0].value, isTrue); // Private
      expect(switchFields[1].value, isFalse); // Active
      expect(switchFields[2].value, isTrue); // Favorite
      expect(switchFields[3].value, isTrue); // Day planning
    });

    testWidgets(
      'tapping each switch emits its field with the toggled value',
      (tester) async {
        // Initial values: private=false, active=true, favorite=false,
        // availableForDayPlan=false — so toggling yields the inverse.
        const expectedToggleValue = {
          SwitchFieldType.private: true,
          SwitchFieldType.active: false,
          SwitchFieldType.favorite: true,
          SwitchFieldType.availableForDayPlan: true,
        };

        final changes = <(SwitchFieldType, bool)>[];
        await _pumpTiles(
          tester,
          settings: _settings(),
          onChanged: (field, {required value}) => changes.add((field, value)),
        );

        final switches = find.byType(Switch);
        for (var i = 0; i < SwitchFieldType.values.length; i++) {
          await tester.tap(switches.at(i));
        }
        await tester.pump();

        expect(changes, hasLength(SwitchFieldType.values.length));
        for (var i = 0; i < SwitchFieldType.values.length; i++) {
          final field = SwitchFieldType.values[i];
          expect(
            changes[i],
            (field, expectedToggleValue[field]),
            reason: 'toggling tile $i should emit $field',
          );
        }
      },
    );

    testWidgets('has spacing between consecutive switches', (tester) async {
      await _pumpTiles(tester, settings: _settings());

      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(CategorySwitchTiles),
          matching: find.byType(SizedBox),
        ),
      );

      // N switches need N-1 spacers.
      final spacingSizedBoxes = sizedBoxes.where((box) => box.height == 8);
      expect(
        spacingSizedBoxes.length,
        SwitchFieldType.values.length - 1,
      );
    });

    testWidgets('renders without errors in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WidgetTestBench(
            child: CategorySwitchTiles(
              settings: _settings(),
              onChanged: (field, {required value}) {},
            ),
          ),
        ),
      );

      expect(
        find.byType(LottiSwitchField),
        findsNWidgets(SwitchFieldType.values.length),
      );
    });
  });
}
