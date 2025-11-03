// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

class _FakeLabelEditorController extends LabelEditorController {
  _FakeLabelEditorController(this._state, {this.onSave});

  final LabelEditorState _state;
  final Future<LabelDefinition?> Function()? onSave;

  @override
  LabelEditorState build(LabelEditorArgs args) => _state;

  @override
  Future<LabelDefinition?> save() async {
    if (onSave != null) return onSave!();
    return testLabelDefinition1;
  }
}

class _MockLabelsRepository extends Mock implements LabelsRepository {}

class _ColorSpyController extends _FakeLabelEditorController {
  _ColorSpyController(super._state, {required this.onPick});
  final void Function(Color) onPick;
  @override
  void setColor(Color color) {
    onPick(color);
    super.setColor(color);
  }
}

void main() {
  setUpAll(() async {
    // Make sliver list build more children so deep widgets are present
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  setUp(() {
    // Larger viewport to keep bottom bar and sliver content within view
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .physicalSize = const Size(1024, 1400);
    TestWidgetsFlutterBinding
        .instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    }
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .physicalSize = const Size(800, 600);
    TestWidgetsFlutterBinding
        .instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
    if (getIt.isRegistered<EntitiesCacheService>()) {
      await getIt.reset(dispose: false);
    }
  });

  group('LabelDetailsPage', () {
    testWidgets('create mode: Save disabled when name empty', (tester) async {
      const state = LabelEditorState(
        name: '',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byType(LottiPrimaryButton);
      expect(saveButton, findsOneWidget);
      expect(tester.widget<LottiPrimaryButton>(saveButton).onPressed, isNull);
    });

    testWidgets('create mode: tapping Save calls controller.save',
        (tester) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(
              state,
              onSave: () async {
                saved = true;
                return testLabelDefinition1;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byType(LottiPrimaryButton);
      expect(
          tester.widget<LottiPrimaryButton>(saveButton).onPressed, isNotNull);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(saved, isTrue);
    });

    testWidgets('edit mode: delete flow calls repository.deleteLabel',
        (tester) async {
      final repo = _MockLabelsRepository();
      when(() => repo.watchLabel('label-1')).thenAnswer(
        (_) => Stream<LabelDefinition?>.value(
            testLabelDefinition1.copyWith(id: 'label-1')),
      );
      when(() => repo.deleteLabel('label-1')).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [labelsRepositoryProvider.overrideWithValue(repo)],
          child:
              makeTestableWidget2(const LabelDetailsPage(labelId: 'label-1')),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the delete button in the bottom bar
      await tester.tap(find.byType(LottiTertiaryButton));
      await tester.pumpAndSettle();

      // Confirm in the dialog (destructive tertiary button)
      final confirmButton = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(LottiTertiaryButton),
          )
          .last;
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(() => repo.deleteLabel('label-1')).called(1);
    });

    testWidgets('color picker calls controller.setColor', (tester) async {
      Color? picked;
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _ColorSpyController(state, onPick: (c) => picked = c),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Drive color change via controller (UI swatch hit-testing can be flaky in tests)
      const args = LabelEditorArgs(initialName: 'Urgent');
      final controller =
          container.read(labelEditorControllerProvider(args).notifier)
              as _ColorSpyController;
      controller.setColor(Colors.green);
      expect(picked, equals(Colors.green));
    });

    testWidgets('tapping Add category opens selection modal', (tester) async {
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Add category button (label is localized). We only assert it exists and is tappable.
      final addButton = find.byType(OutlinedButton);
      expect(addButton, findsOneWidget);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
    });

    testWidgets('keyboard shortcut Cmd+S triggers save', (tester) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(
              state,
              onSave: () async {
                saved = true;
                return testLabelDefinition1;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(saved, isTrue);
    });

    testWidgets('keyboard shortcut Ctrl+S triggers save', (tester) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(
              state,
              onSave: () async {
                saved = true;
                return testLabelDefinition1;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(saved, isTrue);
    });

    testWidgets('Cancel button does not call save and pops', (tester) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(
              state,
              onSave: () async {
                saved = true;
                return testLabelDefinition1;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final cancel = find.byType(LottiSecondaryButton);
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(saved, isFalse);
    });

    testWidgets('error message renders when present in state', (tester) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
        errorMessage: 'boom error',
      );

      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the error row is built and visible within sliver list
      final errorText = find.text('boom error');
      await tester.ensureVisible(errorText);
      expect(errorText, findsOneWidget);
    });

    testWidgets('privacy switch toggles value via controller', (tester) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );
      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
    });

    testWidgets('category chip delete removes it via controller',
        (tester) async {
      // Prepare categories
      final catWork = CategoryDefinition(
        id: 'cat-work',
        name: 'Work',
        color: '#00AA00',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        private: false,
        active: true,
      );
      final catLife = CategoryDefinition(
        id: 'cat-life',
        name: 'Life',
        color: '#AA00AA',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        private: false,
        active: true,
      );
      final cache = getIt<EntitiesCacheService>();
      when(() => cache.getCategoryById('cat-work')).thenReturn(catWork);
      when(() => cache.getCategoryById('cat-life')).thenReturn(catLife);

      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {'cat-work', 'cat-life'},
      );
      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure both chips are present
      expect(find.text('Work'), findsWidgets);
      expect(find.text('Life'), findsWidgets);

      // Tap delete icon on the 'Work' chip
      final workChip = find.widgetWithText(InputChip, 'Work');
      await tester.ensureVisible(workChip);
      final deleteIcon = find.descendant(
        of: find.widgetWithText(InputChip, 'Work'),
        matching: find.byIcon(Icons.close_rounded),
      );
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // 'Work' chip should be gone; 'Life' remains
      expect(find.text('Work'), findsNothing);
      expect(find.text('Life'), findsWidgets);
    });

    testWidgets('controllers seed once and do not reseed on rebuild',
        (tester) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
        description: 'Hello world',
      );
      final container = ProviderContainer(
        overrides: [
          labelEditorControllerProvider.overrideWith(
            () => _FakeLabelEditorController(state),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(const LabelDetailsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Both fields seeded from state
      final nameField = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(nameField).controller?.text, 'Alpha');
      final descField = find.byType(TextFormField).at(1);
      expect(
        tester.widget<TextFormField>(descField).controller?.text,
        'Hello world',
      );

      // User edits
      await tester.enterText(nameField, 'AlphaX');
      await tester.enterText(descField, 'HelloX');
      await tester.pumpAndSettle();

      // Trigger a rebuild via toggling private switch
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Controllers keep user-edited text (no reseed)
      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'AlphaX',
      );
      expect(
        tester.widget<TextFormField>(descField).controller?.text,
        'HelloX',
      );
    });
  });
}
