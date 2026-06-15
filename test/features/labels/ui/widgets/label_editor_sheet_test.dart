import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

/// A [LabelEditorController] subclass that publishes the live instance the
/// widget actually watches, so tests can drive it programmatically (simulating
/// an external state change that the in-tree `ref.listen` must react to).
///
/// [LabelEditorArgs] has no value equality, so the widget's family key is the
/// exact `_args` instance it created in `initState`. Overriding the whole
/// family with this subclass sidesteps the need to reconstruct an equal key.
class _RecordingLabelEditorController extends LabelEditorController {
  _RecordingLabelEditorController() : super(const LabelEditorArgs());

  static _RecordingLabelEditorController? last;

  @override
  LabelEditorState build() {
    last = this;
    return super.build();
  }
}

LabelDefinition _label({
  String id = 'label-1',
  String name = 'Existing label',
  String color = '#FF0000',
  String? description,
  List<String>? applicableCategoryIds,
  bool private = false,
}) {
  final ts = DateTime(2024, 3, 15);
  return LabelDefinition(
    id: id,
    name: name,
    color: color,
    description: description,
    applicableCategoryIds: applicableCategoryIds,
    createdAt: ts,
    updatedAt: ts,
    vectorClock: null,
    private: private,
  );
}

void main() {
  late MockEntitiesCacheService cache;
  late MockLabelsRepository repository;

  setUp(() async {
    cache = MockEntitiesCacheService();
    repository = MockLabelsRepository();
    when(() => cache.sortedCategories).thenReturn(<CategoryDefinition>[]);
    when(() => cache.getCategoryById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(() async {
    _RecordingLabelEditorController.last = null;
    await tearDownTestGetIt();
  });

  List<Override> overrides({bool recordController = false}) => [
    labelsRepositoryProvider.overrideWithValue(repository),
    if (recordController)
      labelEditorControllerProvider.overrideWith(
        _RecordingLabelEditorController.new,
      ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    LabelDefinition? label,
    String? initialName,
    void Function(LabelDefinition label)? onSaved,
    bool recordController = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        LabelEditorSheet(
          label: label,
          initialName: initialName,
          onSaved: onSaved,
        ),
        overrides: overrides(recordController: recordController),
      ),
    );
    await tester.pump();
  }

  group('title and primary button labels', () {
    testWidgets('shows create title and Create button when label is null', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('Create label'), findsOneWidget);
      expect(find.text('Edit label'), findsNothing);
      // line 326: createButton label on the FilledButton.
      expect(find.text('Create'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('shows edit title and Save button when editing a label', (
      tester,
    ) async {
      // line 101 (edit title) + line 327 (saveButton label).
      await pumpSheet(tester, label: _label(name: 'Urgent'));

      expect(find.text('Edit label'), findsOneWidget);
      expect(find.text('Create label'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      // Name field is seeded from the label.
      expect(find.widgetWithText(TextField, 'Urgent'), findsOneWidget);
    });
  });

  group('external controller state mirrored into text controllers', () {
    testWidgets('name set on controller is pushed into the name field', (
      tester,
    ) async {
      await pumpSheet(tester, recordController: true);

      final nameField = find.byType(TextField).first;
      expect(tester.widget<TextField>(nameField).controller!.text, '');

      // External change (not via the field) -> ref.listen must run line 67.
      _RecordingLabelEditorController.last!.setName('Renamed');
      await tester.pump();

      expect(
        tester.widget<TextField>(nameField).controller!.text,
        'Renamed',
      );
    });

    testWidgets(
      'description set on controller is pushed into the description field',
      (tester) async {
        await pumpSheet(tester, recordController: true);

        final descField = find.byType(TextField).at(1);
        expect(tester.widget<TextField>(descField).controller!.text, '');

        // ref.listen lines 69-71: description differs from field text.
        _RecordingLabelEditorController.last!.setDescription('Some notes');
        await tester.pump();

        expect(
          tester.widget<TextField>(descField).controller!.text,
          'Some notes',
        );
      },
    );

    testWidgets(
      'typing in the field does not re-trigger a controller text write',
      (tester) async {
        await pumpSheet(tester, recordController: true);

        await tester.enterText(find.byType(TextField).first, 'Typed');
        await tester.pump();

        // State reflects the typed value and the field keeps it (the listener
        // guard `next.name != _nameController.text` skips the redundant write).
        expect(_RecordingLabelEditorController.last!.state.name, 'Typed');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Typed',
        );
      },
    );
  });

  group('add categories button', () {
    testWidgets('opens the multi-select category modal (line 257 closure)', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        name: 'Health',
      );
      when(() => cache.sortedCategories).thenReturn([category]);

      await pumpSheet(tester);

      final addButton = find.text('Add category');
      await tester.ensureVisible(addButton);
      await tester.pump();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // The real CategoryPickerSheet is shown with the stubbed
      // category, proving the OutlinedButton.onPressed (which constructs the
      // modal incl. the line-257 onCategorySelected closure) executed.
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
    });
  });

  group('cancel button', () {
    testWidgets('pops the sheet without saving (line 300)', (tester) async {
      LabelDefinition? saved;
      // Push the sheet as a route so Navigator.pop has something to remove.
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: LabelEditorSheet(
                        onSaved: (l) => saved = l,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          overrides: overrides(),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(LabelEditorSheet), findsOneWidget);

      final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel');
      await tester.ensureVisible(cancelButton);
      await tester.pump();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditorSheet), findsNothing);
      expect(saved, isNull);
      verifyNever(() => repository.getAllLabels());
    });
  });

  group('save button', () {
    testWidgets(
      'create flow persists via repository and reports the new label',
      (tester) async {
        final created = _label(id: 'new-id', name: 'Focus');
        when(() => repository.getAllLabels()).thenAnswer(
          (_) async => <LabelDefinition>[],
        );
        when(
          () => repository.createLabel(
            name: any(named: 'name'),
            color: any(named: 'color'),
            description: any(named: 'description'),
            private: any(named: 'private'),
            applicableCategoryIds: any(named: 'applicableCategoryIds'),
          ),
        ).thenAnswer((_) async => created);

        LabelDefinition? saved;
        await pumpSheet(tester, onSaved: (l) => saved = l);

        await tester.enterText(find.byType(TextField).first, 'Focus');
        await tester.pump();

        // 'Create label' is the title; the FilledButton label is just 'Create'.
        final createButton = find.widgetWithText(FilledButton, 'Create');
        await tester.ensureVisible(createButton);
        await tester.pump();
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        verify(
          () => repository.createLabel(
            name: 'Focus',
            color: any(named: 'color'),
            description: any(named: 'description'),
            private: any(named: 'private'),
            applicableCategoryIds: any(named: 'applicableCategoryIds'),
          ),
        ).called(1);
        expect(saved, created);
      },
    );

    testWidgets('is disabled while the name is empty', (tester) async {
      await pumpSheet(tester);

      final createButton = find.widgetWithText(FilledButton, 'Create');
      expect(createButton, findsOneWidget);
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    });

    testWidgets('becomes enabled once a name is entered', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField).first, 'Release blocker');
      await tester.pump();

      final createButton = find.widgetWithText(FilledButton, 'Create');
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    });

    testWidgets('renders the duplicate-name error from save()', (
      tester,
    ) async {
      // An existing label with the same name makes save() set the
      // duplicate error message, which the sheet must render.
      when(() => repository.getAllLabels()).thenAnswer(
        (_) async => [_label(name: 'Release blocker')],
      );

      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'Release blocker');
      await tester.pump();

      final createButton = find.widgetWithText(FilledButton, 'Create');
      await tester.ensureVisible(createButton);
      await tester.pump();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(
        find.text('A label with this name already exists.'),
        findsOneWidget,
      );
      verifyNever(
        () => repository.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
          private: any(named: 'private'),
          applicableCategoryIds: any(named: 'applicableCategoryIds'),
        ),
      );
    });
  });

  group('private toggle', () {
    testWidgets('tapping the switch flips isPrivate on the controller', (
      tester,
    ) async {
      await pumpSheet(tester, recordController: true);

      expect(
        _RecordingLabelEditorController.last!.state.isPrivate,
        isFalse,
      );

      final toggleFinder = find.byType(SwitchListTile);
      expect(toggleFinder, findsOneWidget);
      await tester.ensureVisible(toggleFinder);
      await tester.pump();
      await tester.tap(toggleFinder);
      await tester.pump();

      expect(
        _RecordingLabelEditorController.last!.state.isPrivate,
        isTrue,
      );
    });
  });
}
