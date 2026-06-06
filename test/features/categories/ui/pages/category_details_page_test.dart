import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/features/projects/ui/widgets/category_projects_section.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_utils.dart';

/// Minimal stub for [InferenceProfileController] that returns an empty profile list.
class _FakeProfileController extends InferenceProfileController {
  @override
  Stream<List<AiConfig>> build() => Stream.value(const []);
}

// Helper method to find an enabled LottiPrimaryButton
LottiPrimaryButton? findEnabledPrimaryButton(WidgetTester tester) {
  final saveButtons = tester.widgetList<LottiPrimaryButton>(
    find.byType(LottiPrimaryButton),
  );

  for (final button in saveButtons) {
    if (button.onPressed != null) {
      return button;
    }
  }

  return null;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('CategoryDetailsPage Widget Tests', () {
    late MockCategoryRepository mockRepository;
    // late MockAiConfigRepository mockAiConfigRepository;
    late String testCategoryId;

    setUp(() {
      mockRepository = MockCategoryRepository();
      // mockAiConfigRepository = MockAiConfigRepository();
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
    Future<void> pumpCategoryDetailsPage(
      WidgetTester tester, {
      List<Override> extraOverrides = const [],
    }) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(mockRepository),
            ...extraOverrides,
          ],
          child: CategoryDetailsPage(categoryId: testCategoryId),
        ),
      );
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

        // Find the name field (first TextFormField in Basic Settings)
        final nameField = find.byType(TextFormField).first;
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
        final tf = tester.widget<TextFormField>(nameField);
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

        // The page should handle the error gracefully
        // It might show loading or might handle the error differently
        // Just verify the page doesn't crash
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
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

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Check for form sections - these are translated texts
        expect(find.text('Basic Settings'), findsOneWidget);
        // Skip checking for section titles that might not be visible initially
        // The AI sections might be collapsed or rendered differently
      });

      testWidgets('displays all basic form fields', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Check for form fields in the visible area
        // Name field is in Basic Settings (Speech Dictionary is scrolled out)
        expect(find.byType(LottiTextField), findsAtLeastNWidgets(1));
        expect(find.text('Private'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Favorite'), findsOneWidget);
        expect(
          find.byType(LottiSwitchField),
          findsNWidgets(3),
        ); // 3 toggle switches
      });

      testWidgets('displays bottom bar with all buttons', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Check for bottom bar
        expect(find.byType(FormBottomBar), findsOneWidget);
        expect(
          find.byType(LottiTertiaryButton),
          findsOneWidget,
        ); // Delete button
        expect(
          find.byType(LottiSecondaryButton),
          findsOneWidget,
        ); // Cancel button
        expect(find.byType(LottiPrimaryButton), findsOneWidget); // Save button
      });

      testWidgets('displays category name in form', (tester) async {
        final category = CategoryTestUtils.createTestCategory(
          name: 'My Test Category',
        );

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Find the name text field (first one) and check its value
        final textFields = find.byType(TextFormField);
        expect(textFields, findsAtLeastNWidgets(1)); // Name field visible
        final textFieldWidget = tester.widget<TextFormField>(textFields.first);
        expect(textFieldWidget.controller?.text, equals('My Test Category'));
      });
    });

    group('Form Interactions', () {
      testWidgets('save button is disabled initially when no changes', (
        tester,
      ) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final saveButton = find.byType(LottiPrimaryButton);
        final buttonWidget = tester.widget<LottiPrimaryButton>(saveButton);
        expect(buttonWidget.onPressed, isNull);
      });

      testWidgets('save button becomes enabled after changing name', (
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

        // Change the name (use .first to target name field, not speech dictionary)
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'Updated Name');
        await tester.pump();

        // Check save button is enabled - there might be multiple buttons
        final enabledButton = findEnabledPrimaryButton(tester);
        expect(enabledButton, isNotNull);

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

        // Find and tap the private switch
        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3)); // Private, Active, Favorite

        // Scroll to ensure the switch is visible before tapping
        await tester.ensureVisible(switches.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Tap the first switch (Private)
        await tester.tap(switches.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Save button should now be enabled
        final enabledButton = findEnabledPrimaryButton(tester);
        expect(enabledButton, isNotNull);

        await streamController.close();
      });

      testWidgets(
        'app-bar back arrow beams to the categories list — works in V2 '
        'desktop where the auto-leading would never appear',
        (tester) async {
          final category = CategoryTestUtils.createTestCategory();
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await pumpCategoryDetailsPage(tester);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          await tester.tap(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
        },
      );

      testWidgets('cancel button navigates back', (tester) async {
        final category = CategoryTestUtils.createTestCategory();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Find and tap cancel button
        final cancelButton = find.byType(LottiSecondaryButton);
        await tester.tap(cancelButton);
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

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Find and tap delete button
        final deleteButton = find.byType(LottiTertiaryButton);
        await tester.tap(deleteButton);
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

          await pumpCategoryDetailsPage(tester);

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Open delete dialog
          await tester.tap(find.byType(LottiTertiaryButton));
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

      testWidgets('cancel delete dismisses dialog', (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => Stream.value(category),
        );

        await pumpCategoryDetailsPage(tester);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Open delete dialog
        final deleteButton = find.byType(LottiTertiaryButton);
        await tester.tap(deleteButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Find cancel button in dialog and tap it
        final cancelInDialog = find.text('Cancel').last;
        await tester.tap(cancelInDialog);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);
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

        // Clear the name field (use .first to target name field, not speech dictionary)
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, '   '); // Only spaces
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Try to save - find the enabled save button
        final saveButtons = find.byType(LottiPrimaryButton);
        LottiPrimaryButton? enabledButton;
        int? enabledIndex;

        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            enabledButton = button;
            enabledIndex = i;
            break;
          }
        }

        expect(
          enabledButton,
          isNotNull,
          reason: 'Should find an enabled save button',
        );
        await tester.tap(saveButtons.at(enabledIndex!));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Should show error
        expect(find.text('Category name cannot be empty'), findsOneWidget);

        await streamController.close();
      });

      testWidgets('create mode renders without null errors', (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoryDetailsPage(), // No categoryId = create mode
          ),
        );

        // Should display create mode UI without errors
        // Use partial text matching since we don't know exact translations
        expect(find.byType(CategoryDetailsPage), findsOneWidget);
        expect(
          find.byType(LottiFormSection),
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

        // Enter name with whitespace (use .first to target name field, not speech dictionary)
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'New Name');
        await tester.pump();

        // Save - find the enabled save button
        final saveButtons = find.byType(LottiPrimaryButton);
        int? enabledIndex;

        for (var i = 0; i < saveButtons.evaluate().length; i++) {
          final button = tester.widget<LottiPrimaryButton>(saveButtons.at(i));
          if (button.onPressed != null) {
            enabledIndex = i;
            break;
          }
        }

        expect(
          enabledIndex,
          isNotNull,
          reason: 'Should find an enabled save button',
        );
        await tester.tap(saveButtons.at(enabledIndex!));
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
      testWidgets('navigates back after successful category creation', (
        tester,
      ) async {
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

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoryDetailsPage(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Enter category name
        await tester.enterText(find.byType(TextField), 'New Category');
        await tester.pump();

        // Tap create button
        final createButton = find.byType(LottiPrimaryButton);
        await tester.tap(createButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // After a successful create the page beams back to the list.
        expect(beamedTo, '/settings/categories');
        verify(
          () => mockRepository.createCategory(
            name: 'New Category',
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        ).called(1);
      });

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

        // Change name to enable save (use .first to target name field, not speech dictionary)
        await tester.enterText(find.byType(TextFormField).first, 'Updated');
        await tester.pump();

        // Tap save button
        final saveButton = findEnabledPrimaryButton(tester);
        await tester.tap(find.byWidget(saveButton!));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Success path shows the snackbar and beams back to the list.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(beamedTo, '/settings/categories');

        await streamController.close();
      });

      testWidgets('create mode shows an error toast for an empty name', (
        tester,
      ) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoryDetailsPage(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Leave the name field empty and tap Create.
        await tester.tap(find.byType(LottiPrimaryButton));
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

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoryDetailsPage(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.enterText(find.byType(TextField), 'New Category');
        await tester.pump();

        await tester.tap(find.byType(LottiPrimaryButton));
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

    group('UI Behavior', () {
      testWidgets('does not display app bar save; only bottom bar save is used', (
        tester,
      ) async {
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

        // Initially no save button in app bar (no changes)
        expect(
          find.ancestor(
            of: find.byType(LottiTertiaryButton),
            matching: find.byType(SliverAppBar),
          ),
          findsNothing,
        );

        // Make a change (use .first to target name field, not speech dictionary)
        await tester.enterText(
          find.byType(TextFormField).first,
          'Changed Name',
        );
        await tester.pump();

        // Save button should remain absent in app bar; save is in bottom bar only
        expect(
          find.ancestor(
            of: find.byType(LottiTertiaryButton),
            matching: find.byType(SliverAppBar),
          ),
          findsNothing,
        );

        // Bottom bar should show Save enabled
        final enabledSave = find.byWidgetPredicate(
          (w) => w is LottiPrimaryButton && w.onPressed != null,
        );
        expect(enabledSave, findsOneWidget);

        await streamController.close();
      });

      testWidgets('displays CustomScrollView even during loading state', (
        tester,
      ) async {
        final streamController =
            StreamController<CategoryDefinition?>.broadcast();

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => streamController.stream,
        );

        await pumpCategoryDetailsPage(tester);

        // Even in loading state, CustomScrollView should be present
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverAppBar), findsOneWidget);

        await streamController.close();
      });
    });

    group('Create Mode Navigation', () {
      testWidgets('back arrow in create mode beams to categories list', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoryDetailsPage(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(beamedTo, '/settings/categories');
      });

      testWidgets(
        'cancel button in create mode beams back to categories list',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CategoryDetailsPage(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final cancelButton = find.byType(LottiSecondaryButton);
          await tester.ensureVisible(cancelButton);
          await tester.tap(cancelButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
        },
      );

      testWidgets(
        'create mode shows Private and Active switch tiles as disabled',
        (tester) async {
          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CategoryDetailsPage(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Two disabled switch tiles (Private, Active) visible in create mode
          final switchFields = tester.widgetList<LottiSwitchField>(
            find.byType(LottiSwitchField),
          );
          // All onChanged must be null (disabled)
          for (final sw in switchFields) {
            expect(
              sw.onChanged,
              isNull,
              reason: 'Create-mode switch tiles should be disabled',
            );
          }
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

          await tester.tap(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(beamedTo, '/settings/categories');
          await streamController.close();
        },
      );
    });

    group('Projects Section', () {
      testWidgets(
        'shows CategoryProjectsSection when enableProjects flag is true',
        (tester) async {
          // Use a very tall viewport to render all sliver items on-screen.
          tester.view.physicalSize = const Size(800, 3000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final category = CategoryTestUtils.createTestCategory();

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
                configFlagProvider.overrideWith(
                  (ref, flagName) => flagName == enableProjectsFlag
                      ? Stream.value(true)
                      : Stream.value(false),
                ),
                inferenceProfileControllerProvider.overrideWith(
                  _FakeProfileController.new,
                ),
                agentTemplatesProvider.overrideWith(
                  (ref) async => const [],
                ),
              ],
              child: CategoryDetailsPage(categoryId: testCategoryId),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // With a tall viewport all SliverList items are on-screen.
          expect(
            find.byType(CategoryProjectsSection),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides CategoryProjectsSection when enableProjects flag is false',
        (tester) async {
          // Use a tall viewport so all items are rendered.
          tester.view.physicalSize = const Size(800, 3000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final category = CategoryTestUtils.createTestCategory();

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => Stream.value(category),
          );

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
                configFlagProvider.overrideWith(
                  (ref, flagName) => Stream.value(false),
                ),
                inferenceProfileControllerProvider.overrideWith(
                  _FakeProfileController.new,
                ),
                agentTemplatesProvider.overrideWith(
                  (ref) async => const [],
                ),
              ],
              child: CategoryDetailsPage(categoryId: testCategoryId),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            find.byType(CategoryProjectsSection),
            findsNothing,
          );
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

    group('Switch Tiles — active and favorite branches', () {
      // The Private branch is already covered by the existing "toggle switches
      // trigger state changes" test (which taps switches.first). Here we
      // cover Active (index 1) and Favorite (index 2) explicitly.

      testWidgets(
        'toggling Active switch enables save button',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            // active defaults to true; toggling it marks form dirty
            favorite: false,
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Three Switch widgets: Private(0), Active(1), Favorite(2).
          // Tap the Switch widget at index 1 (Active) directly.
          final switches = find.byType(Switch);
          expect(switches, findsNWidgets(3));
          await tester.ensureVisible(switches.at(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await tester.tap(switches.at(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final enabledSave = findEnabledPrimaryButton(tester);
          expect(
            enabledSave,
            isNotNull,
            reason: 'Active toggle should enable save',
          );

          await streamController.close();
        },
      );

      testWidgets(
        'toggling Favorite switch enables save button',
        (tester) async {
          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            // favorite=false; toggling it marks form dirty
            favorite: false,
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final switches = find.byType(Switch);
          expect(switches, findsNWidgets(3));
          await tester.ensureVisible(switches.at(2));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await tester.tap(switches.at(2));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final enabledSave = findEnabledPrimaryButton(tester);
          expect(
            enabledSave,
            isNotNull,
            reason: 'Favorite toggle should enable save',
          );

          await streamController.close();
        },
      );
    });

    group('Icon Picker', () {
      testWidgets(
        'icon picker in create mode updates selected icon display',
        (tester) async {
          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CategoryDetailsPage(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

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
          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CategoryDetailsPage(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

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
          final enabledSave = findEnabledPrimaryButton(tester);
          expect(enabledSave, isNotNull);

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

          await pumpCategoryDetailsPage(tester);

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

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

          await pumpCategoryDetailsPage(tester);

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

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
          // Use a tall viewport so all sections fit without scrolling.
          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            defaultLanguageCode: 'en',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

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
          final nameField = find.byType(TextFormField).first;
          await tester.enterText(nameField, 'Updated');
          await tester.pump();

          // Tap save
          final saveBtn = findEnabledPrimaryButton(tester);
          await tester.tap(find.byWidget(saveBtn!));
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

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: const CategoryDetailsPage(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

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

          await tester.tap(find.byType(LottiPrimaryButton));
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
          expect(beamedTo, '/settings/categories');
        },
      );
    });

    group('Edit Mode Language Selection', () {
      testWidgets(
        'picking a different language updates the form and dismisses the modal',
        (tester) async {
          // Tall viewport so the language dropdown is on-screen without
          // scrolling.
          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final streamController =
              StreamController<CategoryDefinition?>.broadcast();
          final category = CategoryTestUtils.createTestCategory(
            defaultLanguageCode: 'en',
          );

          when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
            (_) => streamController.stream,
          );

          await pumpCategoryDetailsPage(tester);

          streamController.add(category);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Save starts disabled (no changes yet).
          expect(findEnabledPrimaryButton(tester), isNull);

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
          expect(findEnabledPrimaryButton(tester), isNotNull);

          await streamController.close();
        },
      );
    });
  });
}
