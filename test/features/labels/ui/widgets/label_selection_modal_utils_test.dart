import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
    required bool setLabelsResult,
    List<String> initialLabelIds = const [],
  }) async {
    when(
      () => repo.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => setLabelsResult);

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

  testWidgets('Apply commits the staged labels via setLabels and closes', (
    tester,
  ) async {
    await openSelector(tester, setLabelsResult: true);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pumpAndSettle();

    verify(
      () => repo.setLabels(journalEntityId: 'e1', labelIds: ['la']),
    ).called(1);
    // The modal popped on success: the launcher is visible, the sheet gone.
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Search labels…'), findsNothing);
  });

  testWidgets('a failed commit keeps the sheet open and shows a toast', (
    tester,
  ) async {
    await openSelector(tester, setLabelsResult: false);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('label-picker-apply')));
    await tester.pump(); // resolve setLabels
    await tester.pump(const Duration(milliseconds: 50)); // toast animates in

    verify(
      () => repo.setLabels(journalEntityId: 'e1', labelIds: ['la']),
    ).called(1);
    // The error toast is shown and the sheet stays open (no pop).
    expect(find.text('Failed to update labels'), findsWidgets);
    expect(find.text('Search labels…'), findsWidgets);
  });

  testWidgets('create-from-search offers create and opens the label editor', (
    tester,
  ) async {
    await openSelector(tester, setLabelsResult: true);

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

    // Dismiss the editor (returns no label); create-from-search resolves.
    Navigator.of(
      tester.element(find.byType(LabelEditorSheet)),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LabelEditorSheet), findsNothing);
  });
}
