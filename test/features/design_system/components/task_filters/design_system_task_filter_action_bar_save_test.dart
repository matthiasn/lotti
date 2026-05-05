import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  ValueChanged<String>? onSavePressed,
  bool canSave = false,
  String? initialSaveName,
}) async {
  final state = _state();
  await tester.pumpWidget(
    makeTestableWidget(
      Material(
        child: DesignSystemTaskFilterActionBar(
          state: state,
          onChanged: (_) {},
          onApplyPressed: (_) {},
          onSavePressed: onSavePressed,
          canSave: canSave,
          initialSaveName: initialSaveName,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  testWidgets('Save button is hidden when onSavePressed is not supplied', (
    tester,
  ) async {
    await _pumpBar(tester);

    expect(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      findsNothing,
    );
  });

  testWidgets('Save button is rendered when onSavePressed is supplied', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      onSavePressed: (_) {},
    );

    expect(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      findsOneWidget,
    );
  });

  testWidgets('tapping Save when canSave=false does not open the popup', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      onSavePressed: (_) {},
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
      findsNothing,
    );
  });

  testWidgets('tapping Save when canSave=true opens the popup with the field', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      onSavePressed: (_) {},
      canSave: true,
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
      findsOneWidget,
    );
  });

  testWidgets('popup commits trimmed name and invokes onSavePressed', (
    tester,
  ) async {
    String? saved;
    await _pumpBar(
      tester,
      onSavePressed: (name) => saved = name,
      canSave: true,
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(
      DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
    );
    await tester.enterText(field, '  My filter  ');
    // Pump so the controller listener flips _canCommit to true and the
    // FilledButton re-enables before we tap it.
    await tester.pump();
    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
    );
    await tester.pumpAndSettle();

    expect(saved, 'My filter');
  });

  testWidgets('popup does not invoke onSavePressed when name is empty', (
    tester,
  ) async {
    var saveCount = 0;
    await _pumpBar(
      tester,
      onSavePressed: (_) => saveCount++,
      canSave: true,
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(
      DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
    );
    await tester.enterText(field, '   ');
    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
    );
    await tester.pumpAndSettle();

    expect(saveCount, 0);
  });

  testWidgets('popup pre-fills with initialSaveName when supplied', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      onSavePressed: (_) {},
      canSave: true,
      initialSaveName: 'In progress · P0',
    );

    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
    );
    await tester.pumpAndSettle();

    expect(find.text('In progress · P0'), findsOneWidget);
  });

  testWidgets(
    'commit button disables when the field is cleared after typing',
    (tester) async {
      await _pumpBar(
        tester,
        onSavePressed: (_) {},
        canSave: true,
      );

      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(
        DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
      );
      // Type a name → enabled.
      await tester.enterText(field, 'Filter');
      await tester.pump();
      var commit = tester.widget<FilledButton>(
        find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
      );
      expect(commit.onPressed, isNotNull);

      // Clear the field → listener flips _canCommit back to false.
      await tester.enterText(field, '');
      await tester.pump();
      commit = tester.widget<FilledButton>(
        find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
      );
      expect(commit.onPressed, isNull);
    },
  );

  testWidgets(
    'closing the popup disposes the inner controller / focus node cleanly',
    (tester) async {
      await _pumpBar(
        tester,
        onSavePressed: (_) {},
        canSave: true,
      );

      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pumpAndSettle();

      // Tap the action button again to toggle the menu closed; this routes
      // through the popup's State.dispose which removes the controller
      // listener and disposes the controller + focus node.
      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
        findsNothing,
      );
    },
  );

  // Glass footer structure — Figma "Apply filter" footer (node 3341:53641):
  // hairline divider, backdrop blur, top→bottom gradient overlay,
  // right-aligned button row, button slot widths from the frame.
  testWidgets(
    'action bar paints the glass footer treatment over a backdrop blur',
    (tester) async {
      await _pumpBar(tester);

      // Blur is present and at-or-near the codebase's max glass-surface
      // sigma (existing surfaces use 10–20). A regression to 0 must fail.
      final backdrop = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      final blur = backdrop.filter;
      expect(blur, isA<ui.ImageFilter>());
      // ImageFilter has no public sigma getter, but its toString embeds
      // the values: "ImageFilter.blur(20.0, 20.0, ...)". Pin both axes.
      final blurDescription = blur.toString();
      expect(
        blurDescription,
        contains('20.0, 20.0'),
        reason:
            'glass footer blur must remain at sigma 20 on both axes; '
            'got $blurDescription',
      );

      // Gradient is a top→bottom LinearGradient with two stops, the
      // bottom stop more opaque than the top — that's the "lift" effect.
      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(DecoratedBox),
            ),
          )
          .where((d) => (d.decoration as BoxDecoration).gradient != null);
      expect(
        decorated,
        isNotEmpty,
        reason: 'expected a gradient-bearing DecoratedBox under the blur',
      );
      final gradient =
          (decorated.first.decoration as BoxDecoration).gradient!
              as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors.length, 2);
      expect(
        gradient.colors.last.a,
        greaterThan(gradient.colors.first.a),
        reason: 'bottom stop must be more opaque than the top stop',
      );

      // Right-aligned single-row layout, per Figma. A LayoutBuilder
      // around the Row drops slot minimums on viewports too narrow to
      // fit them, so the footer never overflows or wraps.
      expect(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(LayoutBuilder),
        ),
        findsOneWidget,
      );
      final row = tester.widget<Row>(
        find
            .descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(row.mainAxisAlignment, MainAxisAlignment.end);

      // Button slots match the Figma frame minimums (Clear all / Apply
      // filter; Save is omitted in this case because canSave is false).
      final slots = tester
          .widgetList<ConstrainedBox>(
            find.descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(ConstrainedBox),
            ),
          )
          .where(
            (c) =>
                c.constraints.minHeight == 56 &&
                (c.constraints.minWidth == 115 ||
                    c.constraints.minWidth == 159),
          )
          .toList();
      expect(
        slots.map((c) => c.constraints.minWidth).toSet(),
        {115.0, 159.0},
        reason: 'expected Clear (115) and Apply (159) slots at min height 56',
      );
    },
  );
}
