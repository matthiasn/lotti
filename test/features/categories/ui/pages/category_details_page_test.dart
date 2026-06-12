import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_utils.dart';

/// Finds the glass pill in the action bar by its (localized) label.
Finder pillFinder(String label) => find.byWidgetPredicate(
  (widget) => widget is DsGlassPill && widget.label == label,
);

/// Whether the action bar's primary pill with [label] is enabled.
bool isPillEnabled(WidgetTester tester, String label) =>
    tester.widget<DsGlassPill>(pillFinder(label)).enabled;

/// The [TextField] inside the design-system name input.
Finder nameFieldFinder() => find.descendant(
  of: find.byType(CategoryNameField),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('CategoryDetailsPage Widget Tests', () {
    late MockCategoryRepository mockRepository;
    late String testCategoryId;

    setUp(() {
      mockRepository = MockCategoryRepository();
      testCategoryId = const Uuid().v4();
      // The page now drives navigation via `beamToNamed` (which
      // delegates through `getIt<NavService>()`). These tests don't
      // register a NavService, so install a no-op override; tests
      // that need to assert the beamed URL replace this with their
      // own capturing closure.
      beamToNamedOverride = (_) {};
    });

    tearDown(() {
      beamToNamedOverride = null;
    });

    /// Pumps the page with the standard repository override.
    ///
    /// [createMode] omits the categoryId (create flow); [settle] follows up
    /// with the standard pump + 350 ms animation pump most tests need.
    /// [viewportSize] defaults to a tall surface so the header, all form
    /// sections, and the sticky action bar are on-screen together.
    Future<void> pumpCategoryDetailsPage(
      WidgetTester tester, {
      List<Override> extraOverrides = const [],
      bool createMode = false,
      bool settle = false,
      Size viewportSize = const Size(1024, 1600),
    }) async {
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(mockRepository),
            ...extraOverrides,
          ],
          child: createMode
              ? const CategoryDetailsPage()
              : CategoryDetailsPage(categoryId: testCategoryId),
        ),
      );
      if (settle) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
    }

    testWidgets(
      'name field does not reseed selection/text on rebuild during edit',
      (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        when(() => mockRepository.watchCategory(any())).thenAnswer(
          (_) => streamController.stream,
        );

        final category = CategoryDefinition(
          id: testCategoryId,
          name: 'Alpha',
          color: '#00AAFF',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          private: false,
          active: true,
        );

        await pumpCategoryDetailsPage(tester);

        // Emit initial category
        streamController.add(category);
        await tester.pump();

        final nameField = nameFieldFinder();
        await tester.tap(nameField);
        await tester.pump();

        // User types a suffix
        await tester.enterText(nameField, 'AlphaX');
        await tester.pump();

        // Trigger a rebuild via controller state change: simulate toggling favorite
        final updated = category.copyWith(favorite: true);
        streamController.add(updated);
        await tester.pump();

        // The text should remain user's edited value (no reseed)
        final tf = tester.widget<TextField>(nameField);
        expect(tf.controller?.text, equals('AlphaX'));

        await streamController.close();
      },
    );

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => const Stream.empty(),
        );

        await pumpCategoryDetailsPage(tester);
        // Drain the header back-affordance fade-in timer (zero-duration
        // timers only fire on an elapsing pump).
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('handles stream errors gracefully', (tester) async {
        // Return a stream that immediately errors
        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await pumpCategoryDetailsPage(tester);

        // Wait for the error to be processed
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The controller's onError handler clears isLoading with a null
        // category, so the page lands on the not-found scaffold instead of
        // hanging on the loading spinner (ErrorStateWidget only renders in
        // the loaded-form path, which an initial-load error never reaches).
        expect(find.textContaining('not found'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('handles null category state correctly', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await pumpCategoryDetailsPage(tester);

        // Emit null (category not found)
        streamController.add(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Should show "Category not found" message - check for partial text since we don't know exact translation
        expect(find.textContaining('not found'), findsOneWidget);

        // Clean up
        await streamController.close();
      });
    });

    group('Form Display and Elements', () {
      testWidgets('displays all form sections when loaded', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        // Sections render via the shared kit, headed by Basic Settings.
        expect(find.text('Basic Settings'), findsOneWidget);
        expect(find.byType(SettingsFormSection), findsWidgets);
      });

      testWidgets('displays all basic form fields', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        // Name field plus the four switch rows of the basic section.
        expect(nameFieldFinder(), findsOneWidget);
        expect(find.text('Private'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Favorite'), findsOneWidget);
        expect(find.text('Day planning'), findsOneWidget);
        expect(find.byType(SettingsSwitchRow), findsNWidgets(4));
      });

      testWidgets('displays action bar with delete, cancel, and save', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        expect(find.byType(SettingsFormActionBar), findsOneWidget);
        // Destructive delete renders as the icon-only round glass button.
        expect(find.byType(DsGlassRoundButton), findsOneWidget);
        expect(pillFinder('Cancel'), findsOneWidget);
        expect(pillFinder('Save'), findsOneWidget);
      });

      testWidgets('displays category name in form', (tester) async {
        final category = CategoryTestUtils.createTestCategory(
          name: 'My Test Category',
        );

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        final textFieldWidget = tester.widget<TextField>(nameFieldFinder());
        expect(textFieldWidget.controller?.text, equals('My Test Category'));
      });
    });

    group('Form Interactions', () {
      testWidgets('save pill is disabled initially when no changes', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        expect(isPillEnabled(tester, 'Save'), isFalse);
      });

      testWidgets('save pill becomes enabled after changing name', (
        tester,
      ) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Original');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category.copyWith(name: 'Updated'),
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.enterText(nameFieldFinder(), 'Updated Name');
        await tester.pump();

        expect(isPillEnabled(tester, 'Save'), isTrue);

        await streamController.close();
      });

      testWidgets('toggle switches trigger state changes', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Private, Active, Favorite, Day planning
        final toggles = find.byType(DesignSystemToggle);
        expect(toggles, findsNWidgets(4));

        // Scroll to ensure the toggle is visible before tapping
        await tester.ensureVisible(toggles.first);
        await tester.pump();

        // Tap the first toggle (Private)
        await tester.tap(toggles.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Save pill should now be enabled
        expect(isPillEnabled(tester, 'Save'), isTrue);

        await streamController.close();
      });

      testWidgets(
        'header back arrow beams to the categories list — works in V2 '
        'desktop where the auto-leading would never appear',
        (tester) async {
          final category = CategoryTestUtils.createTestCategory();
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await pumpCategoryDetailsPage(tester, settle: true);

          await tester.tap(find.byIcon(Icons.chevron_left));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
        },
      );

      testWidgets('cancel pill navigates back', (tester) async {
        final category = CategoryTestUtils.createTestCategory();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        await tester.tap(pillFinder('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Cancel beams back to the categories list — V2's detail
        // surface mounts inline, so this is the only way the user
        // returns to the list pane on desktop.
        expect(beamedTo, '/settings/categories');
      });
    });

    group('Delete Functionality', () {
      testWidgets('delete button opens confirmation dialog', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        // The destructive action is the round glass button in the bar.
        await tester.tap(find.byType(DsGlassRoundButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Check dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Delete'), findsAtLeastNWidgets(1));
      });

      testWidgets(
        'confirm delete invokes repository.deleteCategory and beams to '
        'the categories list',
        (tester) async {
          final category = CategoryTestUtils.createTestCategory();
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );
          when(() => mockRepository.deleteCategory(testCategoryId)).thenAnswer(
            (_) async {},
          );

          await pumpCategoryDetailsPage(tester, settle: true);

          // Open delete dialog
          await tester.tap(find.byType(DsGlassRoundButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Confirm delete — destructive button is the second tertiary
          // button inside the dialog (the first is the cancel button).
          final confirmButton = find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(LottiTertiaryButton),
              )
              .last;
          await tester.tap(confirmButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          verify(() => mockRepository.deleteCategory(testCategoryId)).called(1);
          // Beams to the list so the now-deleted detail isn't left
          // mounted in V2's inline panel.
          expect(beamedTo, '/settings/categories');
        },
      );

      testWidgets('cancel delete dismisses dialog without deleting', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester, settle: true);

        // Open delete dialog
        await tester.tap(find.byType(DsGlassRoundButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The first tertiary button inside the dialog is Cancel.
        final cancelInDialog = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(LottiTertiaryButton),
            )
            .first;
        await tester.tap(cancelInDialog);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Dialog should be dismissed and nothing deleted
        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => mockRepository.deleteCategory(any()));
      });
    });

    group('State Management', () {
      testWidgets('state changes are reflected in UI', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(
          name: 'Initial Name',
        );

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await pumpCategoryDetailsPage(tester);

        // Initially shows loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Emit the category
        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Category name should be displayed
        expect(find.text('Initial Name'), findsAtLeastNWidgets(1));

        // Clean up
        await streamController.close();
      });

      testWidgets('renders the streamed category name and live updates', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory(
          name: 'Initial Name',
        );
        final updated = category.copyWith(name: 'Renamed Category');
        final controller = StreamController<CategoryDefinition?>();
        addTearDown(controller.close);

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => controller.stream,
        );

        await pumpCategoryDetailsPage(tester);

        controller.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Initial Name'), findsOneWidget);

        // A later stream emission rebuilds the page with the new name.
        controller.add(updated);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Renamed Category'), findsOneWidget);
        expect(find.text('Initial Name'), findsNothing);
      });

      testWidgets('disposal cancels the watch without surfacing errors', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory();
        final controller = StreamController<CategoryDefinition?>();
        addTearDown(controller.close);

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => controller.stream,
        );

        await pumpCategoryDetailsPage(tester);
        controller.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Navigate away to trigger disposal.
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const Scaffold(body: Text('Different Page')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Events after disposal are ignored (subscription cancelled) and
        // surface no errors.
        controller.add(category.copyWith(name: 'Post Dispose'));
        await tester.pump();
        expect(find.text('Post Dispose'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('Form Validation', () {
      testWidgets('shows error for empty name on save', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Test');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Clear the name field
        await tester.enterText(nameFieldFinder(), '   '); // Only spaces
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Whitespace-only differs from the original name → save enabled.
        expect(isPillEnabled(tester, 'Save'), isTrue);
        await tester.tap(pillFinder('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Should show error
        expect(find.text('Category name cannot be empty'), findsOneWidget);

        await streamController.close();
      });

      testWidgets('create mode renders without null errors', (tester) async {
        await pumpCategoryDetailsPage(tester, createMode: true);

        // Should display create mode UI without errors
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
        expect(
          find.byType(SettingsFormSection),
          findsOneWidget,
        ); // Basic Settings section
        expect(find.byType(TextField), findsOneWidget); // Name field
        expect(
          find.byIcon(Icons.palette_outlined),
          findsOneWidget,
        ); // Color picker icon

        // Should be able to enter name
        await tester.enterText(find.byType(TextField), 'New Category');
        expect(find.text('New Category'), findsOneWidget);

        // Should be able to open color picker
        await tester.tap(find.byIcon(Icons.palette_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Color picker dialog should open
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('saves category with updated values', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Test');

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
          (_) async => category,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.enterText(nameFieldFinder(), 'New Name');
        await tester.pump();

        expect(isPillEnabled(tester, 'Save'), isTrue);
        await tester.tap(pillFinder('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Verify the saved category has the new name
        final capturedCategory =
            verify(
                  () => mockRepository.updateCategory(captureAny()),
                ).captured.single
                as CategoryDefinition;
        expect(capturedCategory.name, equals('New Name'));

        await streamController.close();
      });
    });

    group('Navigation Behavior', () {
      testWidgets(
        "beams to the new category's editor after creation — creation "
        'only captures name/color/icon, the rest is configured there',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(
            () => mockRepository.createCategory(
              name: any(named: 'name'),
              color: any(named: 'color'),
              icon: any(named: 'icon'),
            ),
          ).thenAnswer(
            (_) async => CategoryTestUtils.createTestCategory(id: 'cat-new'),
          );

          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          // Enter category name
          await tester.enterText(find.byType(TextField), 'New Category');
          await tester.pump();

          // Tap create pill
          await tester.tap(pillFinder('Create'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // After a successful create the page lands in the editor of
          // the category that was just created.
          expect(beamedTo, '/settings/categories/cat-new');
          verify(
            () => mockRepository.createCategory(
              name: 'New Category',
              color: any(named: 'color'),
              icon: any(named: 'icon'),
            ),
          ).called(1);
        },
      );

      testWidgets('navigates back after successful save', (tester) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Original');
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
          (_) async => category,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Change name to enable save
        await tester.enterText(nameFieldFinder(), 'Updated');
        await tester.pump();

        await tester.tap(pillFinder('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Success path shows the toast and beams back to the list.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(beamedTo, '/settings/categories');

        await streamController.close();
      });

      testWidgets('create mode shows an error toast for an empty name', (
        tester,
      ) async {
        await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

        // Leave the name field empty and tap Create.
        await tester.tap(pillFinder('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Repository must not be called when the name is empty.
        verifyNever(
          () => mockRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        );

        // An error toast explains that the name is required.
        expect(
          find.textContaining('Category name is required'),
          findsOneWidget,
        );
      });

      testWidgets('does not navigate back when creation fails', (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(
          () => mockRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        ).thenThrow(Exception('Creation failed'));

        await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

        await tester.enterText(find.byType(TextField), 'New Category');
        await tester.pump();

        await tester.tap(pillFinder('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Error toast shown and the page stays put — no beam fired.
        expect(
          find.textContaining('Failed to create category'),
          findsOneWidget,
        );
        expect(beamedTo, isNull);
      });
    });

    group('Keyboard Shortcuts', () {
      testWidgets('Ctrl+S with pending changes saves and beams back', (
        tester,
      ) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Original');
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );
        when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
          (_) async => category,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Make a change (also moves focus inside the page).
        await tester.enterText(nameFieldFinder(), 'Updated');
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verify(() => mockRepository.updateCategory(any())).called(1);
        expect(beamedTo, '/settings/categories');

        await streamController.close();
      });

      testWidgets('Ctrl+S without changes neither saves nor navigates', (
        tester,
      ) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();
        final category = CategoryTestUtils.createTestCategory(name: 'Original');
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await pumpCategoryDetailsPage(tester);

        streamController.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Focus the name field without changing the text.
        await tester.tap(nameFieldFinder());
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        verifyNever(() => mockRepository.updateCategory(any()));
        expect(beamedTo, isNull);

        await streamController.close();
      });
    });

    group('Create Mode Navigation', () {
      testWidgets('back arrow in create mode beams to categories list', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(beamedTo, '/settings/categories');
      });

      testWidgets(
        'cancel pill in create mode beams back to categories list',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          await tester.tap(pillFinder('Cancel'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
        },
      );

      testWidgets(
        'create mode asks only for name, color, and icon — no disabled '
        'placeholder switches (privacy/active are configured in the '
        'editor after creation)',
        (tester) async {
          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          expect(find.byType(SettingsSwitchRow), findsNothing);
          expect(find.byType(CategoryNameField), findsOneWidget);
          // Color and icon pickers are present.
          expect(find.text(CategoryIconStrings.iconLabel), findsOneWidget);
        },
      );
    });

    group('Category-Not-Found State', () {
      testWidgets(
        'back arrow when category not found beams to categories list',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          // Emit null → category not found
          streamController.add(null);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          await tester.tap(find.byIcon(Icons.chevron_left));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
          await streamController.close();
        },
      );
    });

    group('Color Picker in Edit Mode', () {
      testWidgets(
        'edit mode color picker opens dialog and can be cancelled',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            color: '#FF0000',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Tap palette icon to open color picker
          final paletteIcon = find.byIcon(Icons.palette_outlined);
          await tester.ensureVisible(paletteIcon);
          await tester.tap(paletteIcon);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Color picker dialog should open with the select/cancel actions
          expect(find.byType(AlertDialog), findsOneWidget);

          // Cancel — no color change, dialog dismissed
          final cancelButton = find.text('Cancel').last;
          await tester.tap(cancelButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(AlertDialog), findsNothing);

          await streamController.close();
        },
      );

      testWidgets(
        'edit mode color picker shows current category color in dialog',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            color: '#FF0000',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Open color picker in edit mode
          final paletteIcon = find.byIcon(Icons.palette_outlined);
          await tester.ensureVisible(paletteIcon);
          await tester.tap(paletteIcon);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // AlertDialog with Select and Cancel actions is shown
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Select'), findsOneWidget);

          // Selecting a color calls onColorChanged → marks form dirty.
          // The picker starts at the category color (#FF0000 = red), so we
          // just confirm Select dismisses the dialog (onColorChanged is
          // invoked with the current picker value regardless).
          final selectButton = find.text('Select');
          await tester.tap(selectButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(AlertDialog), findsNothing);

          await streamController.close();
        },
      );
    });

    group('Switch Tiles — active, favorite, and day-plan branches', () {
      // The Private branch is already covered by the existing "toggle switches
      // trigger state changes" test (which taps toggles.first). Here we cover
      // Active (1), Favorite (2), and Day planning (3) via one parameterised
      // loop instead of three copy-pasted test bodies.
      for (final (index, label) in const [
        (1, 'Active'),
        (2, 'Favorite'),
        (3, 'Day planning'),
      ]) {
        testWidgets(
          'toggling $label switch enables save pill',
          (tester) async {
            final streamController =
                StreamController<CategoryDefinition?>.broadcast();
            final category = CategoryTestUtils.createTestCategory(
              favorite: false,
            );

            when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
              (_) => streamController.stream,
            );

            await pumpCategoryDetailsPage(tester);

            streamController.add(category);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            // Four toggles: Private(0), Active(1), Favorite(2),
            // Day planning(3).
            final toggles = find.byType(DesignSystemToggle);
            expect(toggles, findsNWidgets(4));
            await tester.ensureVisible(toggles.at(index));
            await tester.pump();
            await tester.tap(toggles.at(index));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(
              isPillEnabled(tester, 'Save'),
              isTrue,
              reason: '$label toggle should enable save',
            );

            await streamController.close();
          },
        );
      }
    });

    group('Icon Picker', () {
      testWidgets(
        'icon picker in create mode updates selected icon display',
        (tester) async {
          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          // Initially shows "Choose an icon" hint text
          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsOneWidget,
          );

          // Tap the icon picker row
          final inkWellFinder = find
              .ancestor(
                of: find.text(CategoryIconStrings.chooseIconText),
                matching: find.byType(InkWell),
              )
              .first;
          await tester.ensureVisible(inkWellFinder);
          await tester.tap(inkWellFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Icon picker dialog should open
          expect(find.byType(CategoryIconPicker), findsOneWidget);

          // Tap the first icon by its known display name in the grid
          final firstIconName = CategoryIcon.values.first.displayName;
          final firstIconText = find.text(firstIconName);
          await tester.ensureVisible(firstIconText);
          await tester.tap(firstIconText);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The "Choose an icon" text should be replaced by the icon's display name
          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsNothing,
          );
          expect(find.text(firstIconName), findsOneWidget);
        },
      );

      testWidgets(
        'icon picker in create mode — dismissed with no selection keeps '
        'the existing display name',
        (tester) async {
          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsOneWidget,
          );

          // Open the icon picker dialog
          final inkWellFinder = find
              .ancestor(
                of: find.text(CategoryIconStrings.chooseIconText),
                matching: find.byType(InkWell),
              )
              .first;
          await tester.tap(inkWellFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(CategoryIconPicker), findsOneWidget);

          // Dismiss without picking (tap close button in dialog header)
          final closeBtn = find.widgetWithIcon(IconButton, Icons.close);
          await tester.tap(closeBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Display name should remain the default
          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'icon picker in edit mode updates controller when icon selected',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory();

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Open the icon picker
          final iconSection = find.text(CategoryIconStrings.iconSelectionHint);
          final inkWell = find
              .ancestor(
                of: iconSection,
                matching: find.byType(InkWell),
              )
              .first;
          await tester.ensureVisible(inkWell);
          await tester.tap(inkWell);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(CategoryIconPicker), findsOneWidget);

          // Tap the first icon by its display name in the grid
          final firstIconName = CategoryIcon.values.first.displayName;
          final firstIconText = find.text(firstIconName);
          await tester.ensureVisible(firstIconText);
          await tester.tap(firstIconText);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // After picking, the icon change should mark the form dirty
          expect(isPillEnabled(tester, 'Save'), isTrue);

          await streamController.close();
        },
      );

      testWidgets(
        'edit mode icon picker shows hint text when no icon set',
        (tester) async {
          final category =
              CategoryTestUtils.createTestCategory(); // icon defaults to null

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await pumpCategoryDetailsPage(tester, settle: true);

          // With no icon on the category, "Choose an icon" is shown
          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsOneWidget,
          );
          // And the hint says tap to change
          expect(
            find.text(CategoryIconStrings.iconSelectionHint),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'edit mode icon picker shows icon display name when icon is set',
        (tester) async {
          final category = CategoryTestUtils.createTestCategory(
            icon: CategoryIcon.fitness,
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await pumpCategoryDetailsPage(tester, settle: true);

          // Shows the icon's display name instead of the fallback
          expect(
            find.text(CategoryIcon.fitness.displayName),
            findsOneWidget,
          );
          expect(
            find.text(CategoryIconStrings.chooseIconText),
            findsNothing,
          );
        },
      );
    });

    group('Language Selector', () {
      testWidgets(
        'language dropdown is rendered and tapping it opens a language modal',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            defaultLanguageCode: 'en',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          // Use a tall viewport so all sections fit without scrolling.
          await pumpCategoryDetailsPage(
            tester,
            viewportSize: const Size(1024, 2400),
          );

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // With a tall viewport the language dropdown is on-screen.
          final langDropdown = find.byType(CategoryLanguageDropdown);
          expect(langDropdown, findsOneWidget);

          // Tap to open the language selector modal
          await tester.tap(langDropdown);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The modal content (LanguageSelectionModalContent) appears
          // inside the WoltModalSheet route. We detect it via its key widget
          // type rather than finding the WoltModalSheet wrapper directly.
          expect(
            find.byType(LanguageSelectionModalContent),
            findsOneWidget,
          );

          // Dismiss the modal
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          await streamController.close();
        },
      );
    });

    group('Save Error Display', () {
      testWidgets(
        'save failure shows error message inline via ErrorStateWidget',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(name: 'Test');

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );
          when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
            (_) async => category,
          );
          when(() => mockRepository.updateCategory(any())).thenThrow(
            Exception('Save failed'),
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Make a change to enable save
          await tester.enterText(nameFieldFinder(), 'Updated');
          await tester.pump();

          // Tap save
          await tester.tap(pillFinder('Save'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Error message should be shown
          expect(
            find.textContaining('Failed to update category'),
            findsOneWidget,
          );
          // No beam should occur (stayed on the page)

          await streamController.close();
        },
      );
    });

    group('Create Mode Color Selection', () {
      testWidgets(
        'selecting a color then creating passes the selected color hex to '
        'the repository',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(
            () => mockRepository.createCategory(
              name: any(named: 'name'),
              color: any(named: 'color'),
              icon: any(named: 'icon'),
            ),
          ).thenAnswer(
            (_) async => CategoryTestUtils.createTestCategory(),
          );

          await pumpCategoryDetailsPage(tester, createMode: true, settle: true);

          // Open the color picker (default selected color is null → the
          // picker seeds at Colors.red).
          await tester.tap(find.byIcon(Icons.palette_outlined));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(AlertDialog), findsOneWidget);

          // Tap "Select" → CategoryColorPicker.onColorChanged fires with the
          // seeded red, which runs setState(_selectedColor = color) on the
          // page. The dialog dismisses.
          await tester.tap(find.text('Select'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(AlertDialog), findsNothing);

          // The color row now shows the selected hex (the picker seeds at
          // Colors.red, the Material swatch #F44336) instead of the
          // "select color" hint — proving _selectedColor was assigned via
          // setState in the page's onColorChanged callback.
          expect(find.text('#F44336'), findsOneWidget);

          // Enter a name and create. Because _selectedColor is now non-null,
          // _handleCreate takes the colorToCssHex(_selectedColor!) branch.
          await tester.enterText(find.byType(TextField), 'Red Category');
          await tester.pump();

          await tester.tap(pillFinder('Create'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Repository received the selected color (red swatch), not the blue
          // default — confirming the non-null color branch executed.
          final captured =
              verify(
                    () => mockRepository.createCategory(
                      name: 'Red Category',
                      color: captureAny(named: 'color'),
                      // ignore: avoid_redundant_argument_values
                      icon: null,
                    ),
                  ).captured.single
                  as String;
          expect(captured, '#F44336');
          // Creation lands in the new category's editor.
          expect(beamedTo, startsWith('/settings/categories/'));
        },
      );
    });

    group('Edit Mode Language Selection', () {
      testWidgets(
        'picking a different language updates the form and dismisses the modal',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            defaultLanguageCode: 'en',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          // Tall viewport so the language dropdown is on-screen without
          // scrolling.
          await pumpCategoryDetailsPage(
            tester,
            viewportSize: const Size(1024, 2400),
          );

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Save starts disabled (no changes yet).
          expect(isPillEnabled(tester, 'Save'), isFalse);

          // Open the language selector modal.
          await tester.tap(find.byType(CategoryLanguageDropdown));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(LanguageSelectionModalContent), findsOneWidget);

          // The current language ('en' → "English") renders as the selected
          // card; pick a different one ("German") from the remaining list.
          // Tapping it invokes onLanguageSelected(SupportedLanguage.de),
          // which calls controller.updateFormField(defaultLanguageCode: 'de')
          // and pops the modal.
          final germanCard = find.text('German');
          expect(germanCard, findsOneWidget);
          await tester.tap(germanCard, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Modal dismissed (Navigator.pop ran).
          expect(find.byType(LanguageSelectionModalContent), findsNothing);

          // Form is now dirty ('de' != original 'en') → save is enabled,
          // proving updateFormField was invoked with the new code.
          expect(isPillEnabled(tester, 'Save'), isTrue);

          await streamController.close();
        },
      );
    });
  });
}
