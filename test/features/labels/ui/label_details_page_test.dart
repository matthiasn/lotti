import 'dart:async';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/widgets/category_selection_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_color_picker_field.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

/// Finds the glass pill in the sticky action bar by its (localized) label.
Finder pillFinder(String label) => find.byWidgetPredicate(
  (widget) => widget is DsGlassPill && widget.label == label,
);

/// Whether the action bar pill with [label] is enabled. A disabled pill
/// still renders (quieter affordance), so enabled state lives on the
/// widget's [DsGlassPill.enabled] field rather than on an `onPressed`.
bool isPillEnabled(WidgetTester tester, String label) =>
    tester.widget<DsGlassPill>(pillFinder(label)).enabled;

class _FakeLabelEditorController extends LabelEditorController {
  _FakeLabelEditorController(
    super.params, {
    required this._initialState,
    this.onSave,
  });

  final LabelEditorState _initialState;
  final Future<LabelDefinition?> Function()? onSave;

  @override
  LabelEditorState build() {
    return _initialState;
  }

  @override
  Future<LabelDefinition?> save() async {
    if (onSave != null) return onSave!();
    return testLabelDefinition1;
  }
}

class _ColorSpyController extends _FakeLabelEditorController {
  _ColorSpyController(
    super.params, {
    required super.initialState,
    required this.onPick,
  });
  final void Function(Color) onPick;
  @override
  void setColor(Color color) {
    onPick(color);
    super.setColor(color);
  }
}

/// Records the id sets the page forwards — the multi-picker commits the whole
/// edited set via [setCategoryIds] — while still mutating state, so a test can
/// verify the forwarded ids and observe the resulting chips render.
class _AddCategorySpyController extends _FakeLabelEditorController {
  _AddCategorySpyController(
    super.params, {
    required super.initialState,
  });

  final setIdsCalls = <Set<String>>[];

  @override
  void setCategoryIds(Set<String> ids) {
    setIdsCalls.add(ids);
    super.setCategoryIds(ids);
  }
}

void main() {
  setUpAll(() async {
    // Make sliver list build more children so deep widgets are present
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  setUp(() {
    // Tall viewport so the sliver form (header, sections, error row) and
    // the sticky action bar are all built and on-screen together.
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      1024,
      2400,
    );
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio =
        1.0;
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    }
    // Save / delete / cancel now drive navigation through `beamToNamed`,
    // which would crash here because no `NavService` is registered.
    // Install a no-op override; the dedicated cancel-and-save tests
    // below replace this with a capturing closure.
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      800,
      600,
    );
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio =
        1.0;
    if (getIt.isRegistered<EntitiesCacheService>()) {
      await getIt.reset(dispose: false);
    }
    beamToNamedOverride = null;
  });

  /// Builds a kept-alive [ProviderContainer] with [overrides], pumps
  /// [child] inside it, and drains the first frames with bounded pumps.
  /// The trailing 1100 ms pump runs the header back-affordance fade-in
  /// (flutter_animate, 1 s) to completion so its timer never outlives
  /// the test.
  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Widget child = const LabelDetailsPage(),
  }) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidget2(child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    return container;
  }

  group('LabelDetailsPage', () {
    testWidgets('create mode: Create pill disabled when name empty', (
      tester,
    ) async {
      const state = LabelEditorState(
        name: '',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      expect(pillFinder('Create'), findsOneWidget);
      expect(isPillEnabled(tester, 'Create'), isFalse);
    });

    testWidgets('create mode: tapping Create calls controller.save', (
      tester,
    ) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final fakeController = _FakeLabelEditorController(
        const LabelEditorArgs(),
        initialState: state,
        onSave: () async {
          saved = true;
          return testLabelDefinition1;
        },
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWith(() => fakeController),
        ],
      );

      expect(isPillEnabled(tester, 'Create'), isTrue);

      await tester.tap(pillFinder('Create'));
      await tester.pump();

      expect(saved, isTrue);
    });

    testWidgets('edit mode: delete flow calls repository.deleteLabel', (
      tester,
    ) async {
      final repo = MockLabelsRepository();
      when(() => repo.watchLabel('label-1')).thenAnswer(
        (_) => Stream<LabelDefinition?>.value(
          testLabelDefinition1.copyWith(id: 'label-1'),
        ),
      );
      when(() => repo.deleteLabel('label-1')).thenAnswer((_) async {});

      await pumpPage(
        tester,
        overrides: [labelsRepositoryProvider.overrideWithValue(repo)],
        child: const LabelDetailsPage(labelId: 'label-1'),
      );

      // The destructive action is the labeled Delete pill in the sticky
      // action bar.
      await tester.scrollUntilVisible(
        find.widgetWithText(SettingsDeleteRow, 'Delete'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // The sticky glass action bar overlays the viewport bottom; nudge
      // the row above it so the tap hits the row, not the bar.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -120),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(SettingsDeleteRow, 'Delete'));
      await tester.pump();

      // Confirm in the dialog (destructive tertiary button)
      final confirmButton = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(DesignSystemButton),
          )
          .last;
      await tester.tap(confirmButton);
      await tester.pump();

      verify(() => repo.deleteLabel('label-1')).called(1);
    });

    testWidgets('color field shows the matching preset name, never hex', (
      tester,
    ) async {
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#0066CC', // 'Ocean Blue' in labelColorPresets
        isPrivate: false,
        selectedCategoryIds: {},
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      expect(find.text('Ocean Blue'), findsOneWidget);
      // Raw hex stays behind the picker — it never surfaces in the field.
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('color field shows the localized Custom label for a '
        'non-preset hex', (tester) async {
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000', // not in labelColorPresets
        isPrivate: false,
        selectedCategoryIds: {},
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('tapping the color field opens the shared picker modal and '
        'selecting a preset calls controller.setColor', (tester) async {
      Color? picked;
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#0066CC', // preset → the modal opens on the preset tab
        isPrivate: false,
        selectedCategoryIds: {},
      );

      // Create controller with empty args (matching what LabelDetailsPage uses)
      final colorSpyController = _ColorSpyController(
        const LabelEditorArgs(),
        initialState: state,
        onPick: (c) => picked = c,
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWith(() => colorSpyController),
        ],
      );

      // The wheel no longer renders inline — picking happens in the
      // shared modal opened from the field.
      expect(find.byType(ColorPicker), findsNothing);

      final colorField = find.descendant(
        of: find.byType(SettingsColorPickerField),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(colorField);
      await tester.tap(colorField);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // The shared modal hosts the full flex picker.
      expect(find.byType(ColorPicker), findsOneWidget);

      // Select the 'Crimson' preset (#E63946) — applied live through
      // controller.setColor, no confirm step.
      final crimsonIndicator = find.byWidgetPredicate(
        (widget) =>
            widget is ColorIndicator &&
            colorToCssHex(widget.color) == '#E63946',
      );
      expect(crimsonIndicator, findsOneWidget);
      await tester.tap(crimsonIndicator, warnIfMissed: false);
      await tester.pump();

      expect(picked, isNotNull);
      expect(colorToCssHex(picked!), '#E63946');
    });

    testWidgets('tapping Add category opens selection modal', (tester) async {
      const state = LabelEditorState(
        name: 'Urgent',
        colorHex: '#FF0000',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      // Stub sortedCategories for the modal
      final cacheService = getIt<EntitiesCacheService>();
      when(
        () => (cacheService as MockEntitiesCacheService).sortedCategories,
      ).thenReturn(<CategoryDefinition>[]);

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      // Tap the Add category button (label is localized).
      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The category selection modal is mounted.
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
    });

    testWidgets('keyboard shortcut Cmd+S triggers save', (tester) async {
      var saved = false;
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );

      final fakeController = _FakeLabelEditorController(
        const LabelEditorArgs(),
        initialState: state,
        onSave: () async {
          saved = true;
          return testLabelDefinition1;
        },
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWith(() => fakeController),
        ],
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

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

      final fakeController = _FakeLabelEditorController(
        const LabelEditorArgs(),
        initialState: state,
        onSave: () async {
          saved = true;
          return testLabelDefinition1;
        },
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWith(() => fakeController),
        ],
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(saved, isTrue);
    });

    testWidgets(
      'header back affordance beams to the labels list (V2 desktop has no '
      'Navigator.canPop fallback to auto-render the leading)',
      (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;
        const state = LabelEditorState(
          name: 'Alpha',
          colorHex: '#00FF00',
          isPrivate: false,
          selectedCategoryIds: {},
        );

        await pumpPage(
          tester,
          overrides: [
            labelEditorControllerProvider.overrideWithBuild(
              (ref, args) => state,
            ),
          ],
        );

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(beamedTo, '/settings/labels');
      },
    );

    testWidgets(
      'Cancel pill does not call save and beams back to the labels list',
      (tester) async {
        var saved = false;
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;
        const state = LabelEditorState(
          name: 'Alpha',
          colorHex: '#00FF00',
          isPrivate: false,
          selectedCategoryIds: {},
        );

        final fakeController = _FakeLabelEditorController(
          const LabelEditorArgs(),
          initialState: state,
          onSave: () async {
            saved = true;
            return testLabelDefinition1;
          },
        );

        await pumpPage(
          tester,
          overrides: [
            labelEditorControllerProvider.overrideWith(() => fakeController),
          ],
        );

        final cancel = pillFinder('Cancel');
        expect(cancel, findsOneWidget);
        await tester.tap(cancel);
        await tester.pump();

        expect(saved, isFalse);
        // Cancel beams back to the labels list (V2's detail surface
        // mounts inline, so this is the only return path on desktop).
        expect(beamedTo, '/settings/labels');
      },
    );

    testWidgets('error message renders when present in state', (tester) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
        errorMessage: 'boom error',
      );

      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      // Ensure the error row is built and visible within sliver list
      final errorText = find.text('boom error');
      await tester.ensureVisible(errorText);
      expect(errorText, findsOneWidget);
    });

    testWidgets(
      'Options section card hosts the Private toggle with the unified copy, '
      'leaving Basic settings switch-free',
      (tester) async {
        const state = LabelEditorState(
          name: 'Alpha',
          colorHex: '#00FF00',
          isPrivate: false,
          selectedCategoryIds: {},
        );
        await pumpPage(
          tester,
          overrides: [
            labelEditorControllerProvider.overrideWithBuild(
              (ref, args) => state,
            ),
          ],
        );

        final optionsSection = find.ancestor(
          of: find.text('Options'),
          matching: find.byType(SettingsFormSection),
        );
        expect(optionsSection, findsOneWidget);

        final row = tester.widget<SettingsSwitchRow>(
          find.descendant(
            of: optionsSection,
            matching: find.byType(SettingsSwitchRow),
          ),
        );
        expect(row.title, 'Private');
        expect(
          row.subtitle,
          'Only visible when private entries are shown',
        );
        expect(row.icon, Icons.lock_outline);

        // The toggle moved out of Basic settings entirely.
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Basic settings'),
              matching: find.byType(SettingsFormSection),
            ),
            matching: find.byType(SettingsSwitchRow),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'edit mode: pristine editor shows a disabled Save; flipping the '
      'Private toggle marks it dirty and enables Save',
      (tester) async {
        final repo = MockLabelsRepository();
        when(() => repo.watchLabel('label-1')).thenAnswer(
          (_) => Stream<LabelDefinition?>.value(
            testLabelDefinition1.copyWith(id: 'label-1'),
          ),
        );

        await pumpPage(
          tester,
          overrides: [labelsRepositoryProvider.overrideWithValue(repo)],
          child: const LabelDetailsPage(labelId: 'label-1'),
        );

        // Nothing touched yet → the quiet disabled Save, like every
        // sibling definitions editor.
        expect(pillFinder('Save'), findsOneWidget);
        expect(isPillEnabled(tester, 'Save'), isFalse);

        final toggleFinder = find.byType(DesignSystemToggle);
        await tester.ensureVisible(toggleFinder);
        await tester.tap(toggleFinder);
        await tester.pump();

        expect(isPillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets('privacy toggle flips value via controller', (tester) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
      );
      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      // The privacy row hosts the page's only design-system toggle.
      final toggleFinder = find.byType(DesignSystemToggle);
      await tester.ensureVisible(toggleFinder);
      expect(toggleFinder, findsOneWidget);
      expect(tester.widget<DesignSystemToggle>(toggleFinder).value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pump();

      expect(tester.widget<DesignSystemToggle>(toggleFinder).value, isTrue);
    });

    testWidgets('category chip delete removes it via controller', (
      tester,
    ) async {
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
      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      // Ensure both chips are present
      expect(find.text('Work'), findsWidgets);
      expect(find.text('Life'), findsWidgets);

      // Tap delete icon on the 'Work' chip
      final workChip = find.widgetWithText(CategorySelectionChip, 'Work');
      await tester.ensureVisible(workChip);
      final deleteIcon = find.descendant(
        of: find.widgetWithText(CategorySelectionChip, 'Work'),
        matching: find.byIcon(Icons.close_rounded),
      );
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pump();

      // 'Work' chip should be gone; 'Life' remains
      expect(find.text('Work'), findsNothing);
      expect(find.text('Life'), findsWidgets);
    });

    testWidgets('controllers seed once and do not reseed on rebuild', (
      tester,
    ) async {
      const state = LabelEditorState(
        name: 'Alpha',
        colorHex: '#00FF00',
        isPrivate: false,
        selectedCategoryIds: {},
        description: 'Hello world',
      );
      await pumpPage(
        tester,
        overrides: [
          labelEditorControllerProvider.overrideWithBuild(
            (ref, args) => state,
          ),
        ],
      );

      // Exactly two text fields: name (DesignSystemTextInput) and
      // description (DesignSystemTextarea), both seeded from state.
      expect(find.byType(TextField), findsNWidgets(2));
      final nameField = find.byType(TextField).first;
      expect(tester.widget<TextField>(nameField).controller?.text, 'Alpha');
      final descField = find.byType(TextField).at(1);
      expect(
        tester.widget<TextField>(descField).controller?.text,
        'Hello world',
      );

      // User edits
      await tester.enterText(nameField, 'AlphaX');
      await tester.enterText(descField, 'HelloX');
      await tester.pump();

      // Trigger a rebuild via flipping the privacy toggle
      final toggleFinder = find.byType(DesignSystemToggle);
      await tester.tap(toggleFinder);
      await tester.pump();

      // Controllers keep user-edited text (no reseed)
      expect(
        tester.widget<TextField>(nameField).controller?.text,
        'AlphaX',
      );
      expect(
        tester.widget<TextField>(descField).controller?.text,
        'HelloX',
      );
    });

    testWidgets(
      'delete dialog Cancel dismisses without deleting or navigating',
      (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        final repo = MockLabelsRepository();
        when(() => repo.watchLabel('label-1')).thenAnswer(
          (_) => Stream<LabelDefinition?>.value(
            testLabelDefinition1.copyWith(id: 'label-1'),
          ),
        );
        when(() => repo.deleteLabel(any())).thenAnswer((_) async {});

        await pumpPage(
          tester,
          overrides: [labelsRepositoryProvider.overrideWithValue(repo)],
          child: const LabelDetailsPage(labelId: 'label-1'),
        );

        // Open the delete confirmation dialog via the labeled Delete pill.
        await tester.scrollUntilVisible(
          find.widgetWithText(SettingsDeleteRow, 'Delete'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // The sticky glass action bar overlays the viewport bottom; nudge
        // the row above it so the tap hits the row, not the bar.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -120),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(SettingsDeleteRow, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AlertDialog), findsOneWidget);

        // The first tertiary button inside the dialog is Cancel.
        final cancelButton = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(DesignSystemButton),
            )
            .first;
        await tester.tap(cancelButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dialog is dismissed, nothing deleted, and no navigation happened.
        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => repo.deleteLabel(any()));
        expect(beamedTo, isNull);
      },
    );

    testWidgets(
      'selecting categories in the modal forwards their ids to the controller',
      (tester) async {
        // Modal needs real categories to show cards and to resolve the
        // selection back to definitions on Done.
        final cache = getIt<EntitiesCacheService>();
        when(
          () => (cache as MockEntitiesCacheService).sortedCategories,
        ).thenReturn(<CategoryDefinition>[categoryMindfulness]);
        when(
          () => cache.getCategoryById(categoryMindfulness.id),
        ).thenReturn(categoryMindfulness);

        const state = LabelEditorState(
          name: 'Urgent',
          colorHex: '#FF0000',
          isPrivate: false,
          selectedCategoryIds: {},
        );
        final controller = _AddCategorySpyController(
          const LabelEditorArgs(),
          initialState: state,
        );

        await pumpPage(
          tester,
          overrides: [
            labelEditorControllerProvider.overrideWith(() => controller),
          ],
        );

        // No chips initially.
        expect(find.byType(CategorySelectionChip), findsNothing);

        // Open the category selection modal.
        final addButton = find.byIcon(Icons.add);
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Toggle the category on, then confirm with Done.
        await tester.tap(find.text('Mindfulness').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The page forwarded the full edited set to the controller...
        expect(controller.setIdsCalls, [
          {categoryMindfulness.id},
        ]);
        // ...and the resulting chip is now rendered.
        expect(
          find.widgetWithText(CategorySelectionChip, 'Mindfulness'),
          findsOneWidget,
        );
      },
    );
  });
}
