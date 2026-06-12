import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  late MockCategoryRepository mockRepository;

  setUp(() {
    mockRepository = MockCategoryRepository();
    registerFallbackValue(FakeCategoryDefinition());
  });

  Widget createTestWidget({
    required void Function(CategoryDefinition) onCategoryCreated,
    String initialName = 'Test Category',
    String? initialColor,
    CategoryIcon? initialIcon,
  }) {
    return ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: WidgetTestBench(
        child: CategoryCreateModal(
          onCategoryCreated: onCategoryCreated,
          initialName: initialName,
          initialColor: initialColor,
          initialIcon: initialIcon,
        ),
      ),
    );
  }

  // Stubs createCategory to echo back its name/color/icon arguments so a
  // test can assert exactly what the modal forwarded to the repository.
  void stubCreateCategory({void Function(CategoryIcon?)? onIcon}) {
    when(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
        icon: any(named: 'icon'),
      ),
    ).thenAnswer((invocation) async {
      final icon =
          invocation.namedArguments[const Symbol('icon')] as CategoryIcon?;
      onIcon?.call(icon);
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
        icon: icon,
      );
    });
  }

  testWidgets('displays initial category name', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        onCategoryCreated: (_) {},
      ),
    );

    expect(find.text('Test Category'), findsOneWidget);
  });

  testWidgets('calls repository and callback when saving', (tester) async {
    final createdCategories = <CategoryDefinition>[];

    when(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    ).thenAnswer((invocation) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final category = CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );
      return category;
    });

    await tester.pumpWidget(
      createTestWidget(
        initialName: 'New Category',
        onCategoryCreated: createdCategories.add,
      ),
    );

    // Find and tap the save button
    final saveButton = find.text('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify repository was called with correct parameters
    verify(
      () => mockRepository.createCategory(
        name: 'New Category',
        color: any(named: 'color'),
      ),
    ).called(1);

    // Verify callback was called
    expect(createdCategories.length, 1);
    expect(createdCategories.first.name, 'New Category');
  });

  testWidgets('can modify category name', (tester) async {
    when(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    ).thenAnswer((invocation) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      return CategoryDefinition(
        id: 'test-id',
        name: invocation.namedArguments[const Symbol('name')] as String,
        color: invocation.namedArguments[const Symbol('color')] as String,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );
    });

    await tester.pumpWidget(
      createTestWidget(
        initialName: 'Initial Name',
        onCategoryCreated: (_) {},
      ),
    );

    // Find and modify the text field
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Modified Name');

    // Find and tap the save button
    final saveButton = find.text('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify repository was called with modified name
    verify(
      () => mockRepository.createCategory(
        name: 'Modified Name',
        color: any(named: 'color'),
      ),
    ).called(1);
  });

  testWidgets('closes modal when tapping cancel', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        onCategoryCreated: (_) {},
      ),
    );

    // Find and tap the cancel button
    final cancelButton = find.text('Cancel');
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    // Verify repository was not called
    verifyNever(
      () => mockRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
      ),
    );
  });

  testWidgets(
    'shows an error toast when saving with an empty name and does not '
    'call the repository',
    (tester) async {
      final createdCategories = <CategoryDefinition>[];

      await tester.pumpWidget(
        createTestWidget(
          initialName: '   ',
          onCategoryCreated: createdCategories.add,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      );
      expect(createdCategories, isEmpty);
      expect(find.textContaining('Category name is required'), findsOneWidget);
    },
  );

  // Regression: at the narrow widths WoltModalSheet uses on desktop,
  // `flutter_colorpicker.ColorPicker` picked its landscape Row branch
  // (square + 260-px hard-coded slider) and overflowed the modal.
  // `portraitOnly: true` + a LayoutBuilder in CategoryCreateModal
  // forces the portrait branch and sizes `colorPickerWidth` to fit.
  //
  // Built on the shared `WidgetTestBench` (with the new
  // `surfaceConstraints` knob) instead of a bespoke MaterialApp +
  // ProviderScope wrapper — per AGENTS.md, tests should not duplicate
  // the standard testable wrapper.
  Widget createModalAtWidth(double width) {
    return WidgetTestBench(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockRepository),
      ],
      surfaceConstraints: BoxConstraints.tightFor(width: width),
      child: CategoryCreateModal(
        initialName: 'Narrow',
        onCategoryCreated: (_) {},
      ),
    );
  }

  testWidgets(
    'color picker does not overflow when the modal width is 360 px '
    '(regression for the create-category modal)',
    (tester) async {
      await tester.pumpWidget(createModalAtWidth(360));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'flutter_colorpicker.ColorPicker overflowed its parent at 360 '
            'px. CategoryCreateModal must keep `portraitOnly: true` AND '
            'wrap the picker in a LayoutBuilder that clamps '
            '`colorPickerWidth`. Reverting either re-introduces the bug.',
      );

      // The saturation square (ColorPickerArea) is the load-bearing
      // dimension: in the portrait branch the slider derives its
      // width from it. Asserting on the area's actual width — rather
      // than on the outer ColorPicker, which always inherits parent
      // constraints — is what proves the LayoutBuilder did its job.
      final areaSize = tester.getSize(find.byType(ColorPickerArea));
      expect(
        areaSize.width,
        lessThanOrEqualTo(CategoryIconConstants.colorPickerMaxSquareWidth),
      );
      // And it must fit inside the modal interior (modal padding eats
      // 16 px each side).
      expect(areaSize.width, lessThanOrEqualTo(360 - 32));
    },
  );

  testWidgets(
    'color picker clamps to the design-system max on a wide modal',
    (tester) async {
      await tester.pumpWidget(createModalAtWidth(720));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // On a wide modal the clamp ceiling should kick in: the
      // saturation square stays at `colorPickerMaxSquareWidth` rather
      // than growing to fill the available width and looking
      // disproportionately large.
      final areaSize = tester.getSize(find.byType(ColorPickerArea));
      expect(
        areaSize.width,
        equals(CategoryIconConstants.colorPickerMaxSquareWidth),
      );
    },
  );

  // The clamp math behind colorPickerWidth lives in
  // `pickerSquareWidthFor` and is unit-tested below — exercising the
  // ultra-narrow case (the gap gemini-code-assist flagged on PR
  // #3215) through the full modal isn't reliable because at modal
  // widths < ~230 px the Cancel/Save Row overflows for unrelated
  // reasons and masks the picker behaviour we actually care about.
  group('pickerSquareWidthFor', () {
    test('clamps to the design-system max on wide surfaces', () {
      expect(
        pickerSquareWidthFor(720),
        equals(CategoryIconConstants.colorPickerMaxSquareWidth),
      );
      // Exactly at the ceiling stays at the ceiling.
      expect(
        pickerSquareWidthFor(
          CategoryIconConstants.colorPickerMaxSquareWidth,
        ),
        equals(CategoryIconConstants.colorPickerMaxSquareWidth),
      );
    });

    test('passes the available width through on tight surfaces', () {
      // A value below the ceiling is returned unchanged — no preferred
      // minimum is enforced. This is the property that prevents the
      // picker from overflowing on extremely narrow surfaces (the
      // case the PR-review bot flagged).
      expect(pickerSquareWidthFor(180), equals(180));
      expect(pickerSquareWidthFor(50), equals(50));
      expect(pickerSquareWidthFor(0), equals(0));
    });
  });

  testWidgets(
    'dragging the saturation square flows the new color into the save call',
    (tester) async {
      // Capture whatever colour the modal hands to the repository when
      // Save is tapped. The default _pickerColor is Colors.red; a drag
      // on the saturation square fires `onColorChanged` (the closure
      // patched into the ColorPicker by CategoryCreateModal), which
      // calls setState with the new colour. If the closure never
      // executes — e.g. someone removes the LayoutBuilder + ColorPicker
      // setup or drops `setState` — the saved colour would still be
      // red and this test would fail.
      String? capturedColor;
      when(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          icon: any(named: 'icon'),
        ),
      ).thenAnswer((invocation) async {
        final color =
            invocation.namedArguments[const Symbol('color')] as String;
        capturedColor = color;
        final testDate = DateTime(2024, 3, 15, 10, 30);
        return CategoryDefinition(
          id: 'test-id',
          name: invocation.namedArguments[const Symbol('name')] as String,
          color: color,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: false,
          active: true,
        );
      });

      await tester.pumpWidget(createTestWidget(onCategoryCreated: (_) {}));
      await tester.pumpAndSettle();

      // Drag inside the saturation square. The package wires this up
      // through a RawGestureDetector with a pan recognizer, so a
      // synthesized drag fires `onPanDown` → `onPanUpdate` → the
      // package's `onColorChanging` → our `onColorChanged`.
      final area = find.byType(ColorPickerArea);
      final rect = tester.getRect(area);
      await tester.dragFrom(
        rect.center,
        Offset(rect.width / 4, -rect.height / 4),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The saved colour must differ from the default red because the
      // drag perturbed both saturation and value. Comparing against
      // `colorToCssHex(Colors.red)` rather than a hard-coded string
      // keeps the test in sync with whichever format the util emits.
      expect(capturedColor, isNotNull);
      expect(capturedColor, isNot(equals(colorToCssHex(Colors.red))));
    },
  );

  testWidgets(
    'shows an error toast when the repository throws and keeps the modal open',
    (tester) async {
      when(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenThrow(Exception('DB offline'));

      final createdCategories = <CategoryDefinition>[];

      await tester.pumpWidget(
        createTestWidget(
          initialName: 'Broken',
          onCategoryCreated: createdCategories.add,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(createdCategories, isEmpty);
      expect(
        find.textContaining('Failed to create category'),
        findsOneWidget,
      );
      // Modal stays mounted so the user can fix and retry.
      expect(find.byType(CategoryCreateModal), findsOneWidget);
    },
  );

  testWidgets(
    'seeds the picker colour from initialColor and forwards it on save',
    (tester) async {
      // initialColor is non-null, so initState parses it via
      // colorFromCssHex instead of falling back to Colors.red. Tapping
      // Save without touching the picker should hand that exact colour
      // to the repository.
      const initialHex = '#00FF00';
      String? capturedColor;
      when(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          icon: any(named: 'icon'),
        ),
      ).thenAnswer((invocation) async {
        final color =
            invocation.namedArguments[const Symbol('color')] as String;
        capturedColor = color;
        final testDate = DateTime(2024, 3, 15, 10, 30);
        return CategoryDefinition(
          id: 'test-id',
          name: invocation.namedArguments[const Symbol('name')] as String,
          color: color,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: false,
          active: true,
        );
      });

      await tester.pumpWidget(
        createTestWidget(
          initialName: 'Seeded',
          initialColor: initialHex,
          onCategoryCreated: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The save closure round-trips _pickerColor through colorToCssHex,
      // so the captured value must equal the canonical encoding of the
      // colour we seeded — proving initState used colorFromCssHex.
      expect(
        capturedColor,
        equals(colorToCssHex(colorFromCssHex(initialHex))),
      );
    },
  );

  testWidgets(
    'renders the initial icon using the picker colour',
    (tester) async {
      // With both initialColor and initialIcon set, the icon preview in
      // _buildIconPicker tints the chosen icon with _pickerColor (the
      // `_selectedIcon != null` branch) rather than the muted
      // onSurfaceVariant used for the placeholder.
      const initialHex = '#123456';

      await tester.pumpWidget(
        createTestWidget(
          initialName: 'Has Icon',
          initialColor: initialHex,
          initialIcon: CategoryIcon.fitness,
          onCategoryCreated: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // The display name of the seeded icon is shown.
      expect(find.text(CategoryIcon.fitness.displayName), findsOneWidget);

      // The preview Icon uses the seeded colour, not a fallback.
      final iconWidget = tester.widget<Icon>(
        find.byIcon(CategoryIcon.fitness.iconData),
      );
      expect(iconWidget.color, equals(colorFromCssHex(initialHex)));
    },
  );

  testWidgets(
    'opens the icon picker, applies the chosen icon, and saves it',
    (tester) async {
      CategoryIcon? savedIcon;
      stubCreateCategory(onIcon: (icon) => savedIcon = icon);

      await tester.pumpWidget(
        createTestWidget(
          initialName: 'Pick Icon',
          onCategoryCreated: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // No icon selected yet: the placeholder text is shown.
      final placeholder = find.text('Choose an icon');
      expect(placeholder, findsOneWidget);

      // Tap the icon picker tile to open the CategoryIconPicker dialog.
      // The tile sits below the colour picker inside a scroll view, so
      // bring it on-screen before tapping.
      await tester.ensureVisible(placeholder);
      await tester.pumpAndSettle();
      await tester.tap(placeholder);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryIconPicker), findsOneWidget);

      // Select an icon from the grid; the picker pops with that value
      // and the modal's _showIconPicker applies it via setState. The
      // first enum value renders in the initial viewport of the lazily
      // built GridView, so no scrolling inside the dialog is needed.
      const chosen = CategoryIcon.fitness;
      final chosenTile = find.text(chosen.displayName);
      expect(chosenTile, findsOneWidget);
      await tester.tap(chosenTile);
      await tester.pumpAndSettle();

      // Dialog closed and the modal now shows the chosen icon's name.
      expect(find.byType(CategoryIconPicker), findsNothing);
      expect(find.text(chosen.displayName), findsOneWidget);

      // Saving forwards the newly selected icon to the repository.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => mockRepository.createCategory(
          name: 'Pick Icon',
          color: any(named: 'color'),
          icon: chosen,
        ),
      ).called(1);
      expect(savedIcon, equals(chosen));
    },
  );

  testWidgets(
    'dismissing the icon picker without a selection keeps the placeholder',
    (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialName: 'No Pick',
          onCategoryCreated: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final placeholder = find.text('Choose an icon');
      await tester.ensureVisible(placeholder);
      await tester.pumpAndSettle();
      await tester.tap(placeholder);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryIconPicker), findsOneWidget);

      // Close the dialog via its close button -> showDialog resolves to
      // null, so _showIconPicker takes the `result == null` path and
      // leaves _selectedIcon untouched (no setState).
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryIconPicker), findsNothing);
      // Still the placeholder; no icon was applied.
      expect(find.text('Choose an icon'), findsOneWidget);
    },
  );
}
