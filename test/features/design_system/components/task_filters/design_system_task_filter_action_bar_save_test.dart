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
}
