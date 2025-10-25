import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  late _MockLabelsRepository repository;
  final labels = [
    testLabelDefinition1,
    testLabelDefinition2.copyWith(description: 'Backlog tasks'),
  ];

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() {
    repository = _MockLabelsRepository();
  });

  ProviderScope buildSheet({
    List<String> initial = const [],
  }) {
    return ProviderScope(
      overrides: [
        labelsRepositoryProvider.overrideWithValue(repository),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(labels),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 1200),
          ),
          child: TaskLabelsSheet(
            taskId: 'task-123',
            initialLabelIds: initial,
          ),
        ),
      ),
    );
  }

  testWidgets('applies selected labels via repository', (tester) async {
    when(
      () => repository.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(buildSheet(initial: const ['label-1']));
    await tester.pumpAndSettle();

    final backlogFinder = find.text('Backlog');
    expect(backlogFinder, findsOneWidget);

    await tester.ensureVisible(backlogFinder);
    await tester.tap(backlogFinder);
    await tester.pump();

    final applyButton = find.widgetWithText(FilledButton, 'Apply');
    await tester.ensureVisible(applyButton);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    verify(
      () => repository.setLabels(
        journalEntityId: 'task-123',
        labelIds: ['label-1', 'label-2'],
      ),
    ).called(1);
  });

  testWidgets('shows create CTA when no search results', (tester) async {
    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    expect(find.text('Create "newtag" label'), findsOneWidget);
  });

  testWidgets('launches label editor when hitting create CTA', (tester) async {
    when(() => repository.getAllLabels()).thenAnswer((_) async => labels);
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        groupId: any(named: 'groupId'),
        sortOrder: any(named: 'sortOrder'),
      ),
    ).thenAnswer((_) async => testLabelDefinition1);

    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    final createFinder = find.text('Create "newtag" label');
    expect(createFinder, findsOneWidget);

    await tester.ensureVisible(createFinder);
    await tester.tap(createFinder);
    await tester.pumpAndSettle();

    expect(find.byType(LabelEditorSheet), findsOneWidget);
  });
}
