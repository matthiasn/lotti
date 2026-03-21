import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemCalendarDateCard', () {
    testWidgets('renders default, hover, and selected token treatments', (
      tester,
    ) async {
      const defaultKey = Key('default-card');
      const hoverKey = Key('hover-card');
      const selectedKey = Key('selected-card');

      await _pumpDesignSystem(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemCalendarDateCard(
              key: defaultKey,
              weekdayLabel: 'Sun',
              dayLabel: '15',
              selected: false,
              onPressed: _noop,
            ),
            SizedBox(width: 12),
            DesignSystemCalendarDateCard(
              key: hoverKey,
              weekdayLabel: 'Sun',
              dayLabel: '15',
              selected: false,
              forcedState: DesignSystemCalendarDateCardVisualState.hover,
              onPressed: _noop,
            ),
            SizedBox(width: 12),
            DesignSystemCalendarDateCard(
              key: selectedKey,
              weekdayLabel: 'Sun',
              dayLabel: '15',
              selected: true,
              onPressed: _noop,
            ),
          ],
        ),
      );

      final defaultWeekday = _findTextNode(tester, defaultKey, 'Sun');
      final defaultDay = _findTextNode(tester, defaultKey, '15');
      final hoverDecoration = _firstDecoration(tester, hoverKey);
      final selectedDecoration = _firstDecoration(tester, selectedKey);
      final selectedWeekday = _findTextNode(tester, selectedKey, 'Sun');
      final selectedDay = _findTextNode(tester, selectedKey, '15');

      expect(tester.getSize(find.byKey(defaultKey)), const Size(50, 56));
      expect(_firstDecoration(tester, defaultKey).color, isNull);
      expectTextStyle(
        defaultWeekday.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.lowEmphasis,
      );
      expectTextStyle(
        defaultDay.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.mediumEmphasis,
      );

      expect(hoverDecoration.color, dsTokensLight.colors.background.level02);

      expect(selectedDecoration.color, dsTokensLight.colors.surface.selected);
      final border = selectedDecoration.border! as Border;
      expect(border.top.color, dsTokensLight.colors.interactive.enabled);
      expectTextStyle(
        selectedWeekday.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.interactive.enabled,
      );
      expectTextStyle(
        selectedDay.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.interactive.enabled,
      );
    });
  });

  group('DesignSystemCalendarPicker', () {
    testWidgets('renders the picker shell, selected month, and range cells', (
      tester,
    ) async {
      const pickerKey = Key('calendar-picker');
      const janKey = Key('month-jan');
      const selectedStartKey = Key('cell-1');
      const selectedMiddleKey = Key('cell-2');
      const activeDayKey = Key('cell-5');

      await _pumpDesignSystem(
        tester,
        DesignSystemCalendarPicker(
          key: pickerKey,
          monthSections: _monthSections(selectedMonthKey: janKey),
          visibleMonthLabel: 'January 2026',
          weekdayLabels: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
          weeks: _pickerWeeks(
            selectedStartKey: selectedStartKey,
            selectedMiddleKey: selectedMiddleKey,
            activeDayKey: activeDayKey,
          ),
          todayLabel: 'Today',
          onTodayPressed: _noop,
        ),
      );

      final pickerDecoration = _firstDecoration(tester, pickerKey);
      final selectedMonthDecoration = _firstDecoration(tester, janKey);
      final selectedStartDecoration = _firstDecoration(
        tester,
        selectedStartKey,
      );
      final selectedMiddleConnection = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byKey(selectedMiddleKey),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final monthTitle = _findTextNode(tester, pickerKey, 'January 2026');
      final todayButton = _findTextNode(tester, pickerKey, 'Today');
      final activeDay = _findTextNode(tester, activeDayKey, '5');
      final border = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(pickerKey),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).border != null,
              ),
            )
            .first,
      );

      expect(tester.getSize(find.byKey(pickerKey)), const Size(440, 320));
      expect(pickerDecoration.color, dsTokensLight.colors.background.level01);
      expect(selectedMonthDecoration.color, dsTokensLight.colors.surface.hover);
      expect(
        selectedStartDecoration.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        selectedMiddleConnection.color,
        dsTokensLight.colors.background.level03,
      );
      expectTextStyle(
        monthTitle.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.highEmphasis,
      );
      expectTextStyle(
        todayButton.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.interactive.enabled,
      );
      expectTextStyle(
        activeDay.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.highEmphasis,
      );
      final monthRailBorder =
          (border.decoration as BoxDecoration).border! as Border;
      expect(
        monthRailBorder.right.color,
        dsTokensLight.colors.decorative.level01,
      );
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
    });

    testWidgets('renders today and disabled cells with token-driven opacity', (
      tester,
    ) async {
      const pickerKey = Key('calendar-picker-disabled');
      const todayKey = Key('today-cell');
      const disabledActiveKey = Key('disabled-active-cell');
      const disabledSelectedKey = Key('disabled-selected-cell');

      await _pumpDesignSystem(
        tester,
        DesignSystemCalendarPicker(
          key: pickerKey,
          monthSections: _monthSections(),
          visibleMonthLabel: 'January 2026',
          weekdayLabels: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
          weeks: const [
            [
              DesignSystemCalendarDayCellData(
                key: todayKey,
                label: '1',
                type: DesignSystemCalendarDayCellType.today,
                onPressed: _noop,
              ),
              DesignSystemCalendarDayCellData(
                key: disabledActiveKey,
                label: '2',
                type: DesignSystemCalendarDayCellType.activeMonth,
              ),
              DesignSystemCalendarDayCellData(
                key: disabledSelectedKey,
                label: '3',
                type: DesignSystemCalendarDayCellType.selected,
              ),
              null,
              null,
              null,
              null,
            ],
          ],
          todayLabel: 'Today',
          onTodayPressed: _noop,
        ),
      );

      final todayDecoration = _firstDecoration(tester, todayKey);
      final disabledActiveText = _findTextNode(tester, disabledActiveKey, '2');
      final disabledSelectedText = _findTextNode(
        tester,
        disabledSelectedKey,
        '3',
      );
      final opacities = tester.widgetList<Opacity>(
        find.descendant(
          of: find.byKey(pickerKey),
          matching: find.byType(Opacity),
        ),
      );

      expect(todayDecoration.color, dsTokensLight.colors.background.level02);
      expectTextStyle(
        disabledActiveText.style!,
        dsTokensLight.typography.styles.body.bodySmall,
        dsTokensLight.colors.text.highEmphasis,
      );
      expectTextStyle(
        disabledSelectedText.style!,
        dsTokensLight.typography.styles.subtitle.subtitle2,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
      expect(
        opacities.map((opacity) => opacity.opacity),
        contains(dsTokensLight.colors.text.lowEmphasis.a),
      );
    });
  });
}

Future<void> _pumpDesignSystem(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: DesignSystemTheme.light(),
    ),
  );
}

List<DesignSystemCalendarMonthRailSection> _monthSections({
  Key? selectedMonthKey,
}) {
  DesignSystemCalendarMonthRailItem item(
    String label, {
    bool selected = false,
    Key? key,
  }) {
    return DesignSystemCalendarMonthRailItem(
      key: key,
      label: label,
      selected: selected,
      onPressed: _noop,
    );
  }

  return [
    DesignSystemCalendarMonthRailSection(
      yearLabel: '2025',
      items: [
        item('Aug'),
        item('Sep'),
        item('Oct'),
        item('Nov'),
        item('Dec'),
      ],
    ),
    DesignSystemCalendarMonthRailSection(
      yearLabel: '2026',
      items: [
        item('Jan', selected: true, key: selectedMonthKey),
        item('Feb'),
      ],
    ),
  ];
}

List<List<DesignSystemCalendarDayCellData?>> _pickerWeeks({
  Key? selectedStartKey,
  Key? selectedMiddleKey,
  Key? activeDayKey,
}) {
  DesignSystemCalendarDayCellData active(String label, {Key? key}) {
    return DesignSystemCalendarDayCellData(
      key: key,
      label: label,
      type: DesignSystemCalendarDayCellType.activeMonth,
      onPressed: _noop,
    );
  }

  DesignSystemCalendarDayCellData selected(
    String label,
    DesignSystemCalendarDayCellSelectionPosition position, {
    Key? key,
  }) {
    return DesignSystemCalendarDayCellData(
      key: key,
      label: label,
      type: DesignSystemCalendarDayCellType.selected,
      selectionPosition: position,
      onPressed: _noop,
    );
  }

  return [
    [
      null,
      null,
      null,
      selected(
        '1',
        DesignSystemCalendarDayCellSelectionPosition.start,
        key: selectedStartKey,
      ),
      selected(
        '2',
        DesignSystemCalendarDayCellSelectionPosition.middle,
        key: selectedMiddleKey,
      ),
      selected('3', DesignSystemCalendarDayCellSelectionPosition.middle),
      selected('4', DesignSystemCalendarDayCellSelectionPosition.end),
    ],
    [
      active('5', key: activeDayKey),
      active('6'),
      active('7'),
      active('8'),
      active('9'),
      active('10'),
      active('11'),
    ],
    [
      active('12'),
      active('13'),
      active('14'),
      active('15'),
      active('16'),
      active('17'),
      active('18'),
    ],
    [
      active('19'),
      active('20'),
      active('21'),
      active('22'),
      active('23'),
      active('24'),
      active('25'),
    ],
    [
      active('26'),
      active('27'),
      active('28'),
      active('29'),
      active('30'),
      active('31'),
      null,
    ],
  ];
}

BoxDecoration _firstDecoration(WidgetTester tester, Key key) {
  final keyedWidget = tester.widget(find.byKey(key));
  if (keyedWidget is DecoratedBox) {
    return keyedWidget.decoration as BoxDecoration;
  }

  final decoratedBox = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(key),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );

  return decoratedBox.decoration as BoxDecoration;
}

Text _findTextNode(WidgetTester tester, Key key, String text) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byKey(key),
      matching: find.text(text),
    ),
  );
}

void _noop() {}
