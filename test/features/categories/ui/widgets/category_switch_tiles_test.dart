import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

import '../../../../test_helper.dart';

/// Per-field display expectations, in tile render order — the shared
/// Options order (Favorite, Private, Active, Day planning) with the
/// unified copy used by every definition editor.
const _expectedTiles = <SwitchFieldType, (String, String?, IconData)>{
  SwitchFieldType.favorite: (
    'Favorite',
    null,
    Icons.star_outline_rounded,
  ),
  SwitchFieldType.private: (
    'Private',
    'Only visible when private entries are shown',
    Icons.lock_outline,
  ),
  SwitchFieldType.active: (
    'Active',
    'Can be chosen for new entries when on',
    Icons.visibility_outlined,
  ),
  SwitchFieldType.availableForDayPlan: (
    'Day planning',
    'Make this category available for selection in the day plan',
    Icons.today_outlined,
  ),
};

/// Tile render order — must match [_expectedTiles] key order.
const _renderOrder = <SwitchFieldType>[
  SwitchFieldType.favorite,
  SwitchFieldType.private,
  SwitchFieldType.active,
  SwitchFieldType.availableForDayPlan,
];

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
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    WidgetTestBench(
      theme: theme,
      child: CategorySwitchTiles(
        settings: settings,
        onChanged: onChanged ?? (field, {required value}) {},
      ),
    ),
  );
}

void main() {
  group('CategorySwitchTiles', () {
    testWidgets(
      'renders the unified Options order (Favorite, Private, Active, '
      'Day planning) with the shared titles, subtitles, and icons',
      (tester) async {
        await _pumpTiles(tester, settings: _settings());

        final switchRows = tester
            .widgetList<SettingsSwitchRow>(find.byType(SettingsSwitchRow))
            .toList();
        expect(switchRows, hasLength(SwitchFieldType.values.length));

        for (var i = 0; i < _renderOrder.length; i++) {
          final (title, subtitle, icon) = _expectedTiles[_renderOrder[i]]!;
          expect(
            switchRows[i].title,
            title,
            reason: 'tile $i should be $title',
          );
          expect(
            switchRows[i].subtitle,
            subtitle,
            reason: '$title should carry the shared subtitle copy',
          );
          expect(switchRows[i].icon, icon);
        }
      },
    );

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

      final switchRows = tester
          .widgetList<SettingsSwitchRow>(find.byType(SettingsSwitchRow))
          .toList();

      expect(switchRows[0].value, isTrue); // Favorite
      expect(switchRows[1].value, isTrue); // Private
      expect(switchRows[2].value, isFalse); // Active
      expect(switchRows[3].value, isTrue); // Day planning
    });

    testWidgets(
      'tapping each toggle emits its field with the toggled value',
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

        final toggles = find.byType(DesignSystemToggle);
        for (var i = 0; i < _renderOrder.length; i++) {
          await tester.tap(toggles.at(i));
        }
        await tester.pump();

        expect(changes, hasLength(_renderOrder.length));
        for (var i = 0; i < _renderOrder.length; i++) {
          final field = _renderOrder[i];
          expect(
            changes[i],
            (field, expectedToggleValue[field]),
            reason: 'toggling tile $i should emit $field',
          );
        }
      },
    );

    testWidgets(
      'tapping the row (not the toggle) also emits the toggled value',
      (tester) async {
        final changes = <(SwitchFieldType, bool)>[];
        await _pumpTiles(
          tester,
          settings: _settings(),
          onChanged: (field, {required value}) => changes.add((field, value)),
        );

        // The whole SettingsSwitchRow is tappable; tap the Private title.
        await tester.tap(find.text('Private'));
        await tester.pump();

        expect(changes, [(SwitchFieldType.private, true)]);
      },
    );

    testWidgets('renders all rows in dark theme', (tester) async {
      await _pumpTiles(
        tester,
        settings: _settings(),
        theme: ThemeData.dark(),
      );

      expect(
        find.byType(SettingsSwitchRow),
        findsNWidgets(SwitchFieldType.values.length),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
