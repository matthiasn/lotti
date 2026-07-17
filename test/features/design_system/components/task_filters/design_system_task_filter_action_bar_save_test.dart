import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

import '../../../../widget_test_utils.dart';

DesignSystemTaskFilterState _state() {
  return DesignSystemTaskFilterState(
    title: 'Apply filter',
    clearAllLabel: 'Clear all',
    applyLabel: 'Apply',
    sortLabel: 'Sort by',
    sortOptions: const <DesignSystemTaskFilterOption>[
      DesignSystemTaskFilterOption(id: 'priority', label: 'Priority'),
    ],
    selectedSortId: 'priority',
  );
}

Future<void> _pumpBar(
  WidgetTester tester, {
  VoidCallback? onSavePressed,
  bool canSave = false,
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      Material(
        child: DesignSystemTaskFilterActionBar(
          state: _state(),
          onChanged: (_) {},
          onApplyPressed: (_) {},
          onSavePressed: onSavePressed,
          canSave: canSave,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  testWidgets('Save button is hidden when no save flow is supplied', (
    tester,
  ) async {
    await _pumpBar(tester);

    expect(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      findsNothing,
    );
  });

  testWidgets('Save button is disabled until the current draft can be saved', (
    tester,
  ) async {
    await _pumpBar(tester, onSavePressed: () {});

    final button = tester.widget<DesignSystemButton>(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    expect(button.label, 'Save filter…');
    expect(button.onPressed, isNull);
  });

  testWidgets('enabled Save button opens the owning modal save flow once', (
    tester,
  ) async {
    var calls = 0;
    await _pumpBar(
      tester,
      onSavePressed: () => calls++,
      canSave: true,
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pump();

    expect(calls, 1);
  });

  // Glass footer structure — Figma "Apply filter" footer (node 3341:53641):
  // hairline divider, backdrop blur, gradient overlay, and responsive actions.
  testWidgets(
    'action bar paints the glass footer treatment over a backdrop blur',
    (tester) async {
      await _pumpBar(tester);

      final backdrop = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      final blur = backdrop.filter;
      expect(blur, isA<ui.ImageFilter>());
      expect(blur.toString(), contains('20.0, 20.0'));

      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((d) => (d.decoration as BoxDecoration).gradient != null);
      expect(decorated, isNotEmpty);
      final gradient =
          (decorated.first.decoration as BoxDecoration).gradient!
              as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors.length, 2);
      expect(gradient.colors.last.a, greaterThan(gradient.colors.first.a));

      expect(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(LayoutBuilder),
        ),
        findsOneWidget,
      );
      final clear = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('design-system-task-filter-clear')),
      );
      final apply = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('design-system-task-filter-apply')),
      );
      expect(clear.size, DesignSystemButtonSize.large);
      expect(clear.variant, DesignSystemButtonVariant.secondary);
      expect(apply.size, DesignSystemButtonSize.large);
      expect(apply.fullWidth, isFalse);
      final clearCenter = tester.getCenter(
        find.byKey(const ValueKey('design-system-task-filter-clear')),
      );
      final applyCenter = tester.getCenter(
        find.byKey(const ValueKey('design-system-task-filter-apply')),
      );
      expect(applyCenter.dy, clearCenter.dy);
      expect(applyCenter.dx, greaterThan(clearCenter.dx));
    },
  );
}
