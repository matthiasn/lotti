import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

/// Drives [LabelSelectionModalUtils.openLabelSelector] end-to-end so the modal's
/// Apply footer (commit success and failure) and the create-from-search
/// affordance are exercised directly.
void main() {
  late MockEntitiesCacheService cache;
  late MockLabelsRepository repo;

  final labelA = testLabelDefinition1.copyWith(id: 'la', name: 'Alpha');
  final labelB = testLabelDefinition1.copyWith(id: 'lb', name: 'Beta');

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    cache = MockEntitiesCacheService();
    repo = MockLabelsRepository();
    when(() => cache.getLabelById('la')).thenReturn(labelA);
    when(() => cache.getLabelById('lb')).thenReturn(labelB);
    when(() => cache.sortedCategories).thenReturn(<CategoryDefinition>[]);
    getIt.registerSingleton<EntitiesCacheService>(cache);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  Future<void> openSelector(
    WidgetTester tester, {
    required bool updateResult,
    List<String> initialLabelIds = const [],
  }) async {
    when(
      () => repo.updateLabels(
        journalEntityId: any(named: 'journalEntityId'),
        added: any(named: 'added'),
        removed: any(named: 'removed'),
      ),
    ).thenAnswer((_) async => updateResult);

    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => LabelSelectionModalUtils.openLabelSelector(
                context: context,
                entryId: 'e1',
                initialLabelIds: initialLabelIds,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([labelA, labelB]),
          ),
          availableLabelsForCategoryProvider(null).overrideWithValue(
            [labelA, labelB],
          ),
          labelsRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Apply commits the labels the user added and closes', (
    tester,
  ) async {
    await openSelector(tester, updateResult: true);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateLabels(
        journalEntityId: 'e1',
        added: {'la'},
        removed: <String>{},
      ),
    ).called(1);
    // The modal popped on success: the launcher is visible, the sheet gone.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Search labels…'), findsNothing);
  });

  testWidgets('a failed commit keeps the sheet open and shows a toast', (
    tester,
  ) async {
    await openSelector(tester, updateResult: false);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pump(); // resolve updateLabels
    await tester.pump(const Duration(milliseconds: 50)); // toast animates in

    verify(
      () => repo.updateLabels(
        journalEntityId: 'e1',
        added: {'la'},
        removed: <String>{},
      ),
    ).called(1);
    // The error toast is shown and the sheet stays open (no pop).
    expect(find.text('Failed to update labels'), findsWidgets);
    expect(find.text('Search labels…'), findsWidgets);
  });

  testWidgets('create-from-search offers create and opens the label editor', (
    tester,
  ) async {
    await openSelector(tester, updateResult: true);

    // An existing exact name does not offer create.
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    expect(find.byKey(const ValueKey('label-picker-create')), findsNothing);

    // A new name offers create, which opens the label editor.
    await tester.enterText(find.byType(TextField), 'Gamma');
    await tester.pump();
    final createRow = find.byKey(const ValueKey('label-picker-create'));
    expect(createRow, findsOneWidget);

    await tester.tap(createRow);
    await tester.pumpAndSettle();
    expect(find.byType(LabelEditorSheet), findsOneWidget);

    // The editor seeds its name from the trimmed query.
    expect(
      tester
          .widget<LabelEditorSheet>(find.byType(LabelEditorSheet))
          .initialName,
      'Gamma',
    );

    // Dismiss the editor (returns no label); create-from-search resolves.
    Navigator.of(tester.element(find.byType(LabelEditorSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LabelEditorSheet), findsNothing);

    // Nothing was created, so nothing changed: Apply commits an empty edit.
    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateLabels(
        journalEntityId: 'e1',
        added: <String>{},
        removed: <String>{},
      ),
    ).called(1);
  });

  testWidgets('a label created from search is staged and applied', (
    tester,
  ) async {
    await openSelector(tester, updateResult: true);

    await tester.enterText(find.byType(TextField), 'Gamma');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('label-picker-create')));
    await tester.pumpAndSettle();

    // The editor saves and returns the new definition.
    Navigator.of(
      tester.element(find.byType(LabelEditorSheet)),
    ).pop(testLabelDefinition1.copyWith(id: 'lc', name: 'Gamma'));
    await tester.pumpAndSettle();
    expect(find.byType(LabelEditorSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateLabels(
        journalEntityId: 'e1',
        added: {'lc'},
        removed: <String>{},
      ),
    ).called(1);
  });

  // The edit is the difference to what the picker opened with: a label it
  // showed and the user left alone is not sent, so one another writer took
  // off meanwhile is not put back, and one put on is not taken off
  // (`specs/tla/TaskLabels.tla`, PickerDelta).
  for (final (name, untickBeta, removed) in [
    ('adding one label sends only that one', false, <String>{}),
    ('swapping labels sends what was added and what was removed', true, {'lb'}),
  ]) {
    testWidgets(name, (tester) async {
      await openSelector(
        tester,
        updateResult: true,
        initialLabelIds: const ['lb'],
      );

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      if (untickBeta) {
        await tester.tap(find.text('Beta'));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
      await tester.pumpAndSettle();

      verify(
        () => repo.updateLabels(
          journalEntityId: 'e1',
          added: {'la'},
          removed: removed,
        ),
      ).called(1);
    });
  }
}
