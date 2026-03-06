import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/features/ai/ui/settings/embedding_backfill_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Test categories used across tests.
final _testCategory1 = CategoryDefinition(
  id: 'cat-1',
  name: 'Work',
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: null,
  private: false,
  active: true,
);

final _testCategory2 = CategoryDefinition(
  id: 'cat-2',
  name: 'Personal',
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: null,
  private: false,
  active: true,
);

/// Pumps a scaffold with a button that triggers [EmbeddingBackfillModal.show].
Widget _buildTestWidget({
  List<Override> overrides = const [],
}) {
  return makeTestableWidgetWithScaffold(
    Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => EmbeddingBackfillModal.show(context),
          child: const Text('Open Modal'),
        );
      },
    ),
    overrides: overrides,
  );
}

/// Sets the test surface to a tall viewport so modal content fits.
void _setTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Opens the modal, selects both test categories, and taps confirm.
Future<void> _openModalSelectAndConfirm(WidgetTester tester) async {
  _setTallSurface(tester);

  await tester.tap(find.text('Open Modal'));
  await tester.pumpAndSettle();

  // Select both categories
  await tester.tap(find.text('Work'));
  await tester.pump();
  await tester.tap(find.text('Personal'));
  await tester.pump();

  // Tap confirm
  await tester.tap(find.text('YES, GENERATE'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockCacheService;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();
        when(
          () => mockCacheService.sortedCategories,
        ).thenReturn([_testCategory1, _testCategory2]);
        getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('EmbeddingBackfillModal', () {
    testWidgets('shows confirmation page with message and category picker', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify the confirmation message is displayed
      expect(
        find.text('Select categories to generate embeddings for.'),
        findsOneWidget,
      );

      // Verify the confirm button label is displayed (uppercased)
      expect(find.text('YES, GENERATE'), findsOneWidget);

      // Verify cancel button is present
      expect(find.text('Cancel'), findsOneWidget);

      // Verify no destructive warning icon (isDestructive: false)
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      // Verify categories are shown
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      // Verify Select All button is shown
      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('confirm button is disabled until a category is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final confirmFinder = find.widgetWithText(
        LottiPrimaryButton,
        'YES, GENERATE',
      );

      // Before selecting a category, confirm button should be disabled
      var confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
      expect(confirmButton.onPressed, isNull);

      // Tap a category to select it
      await tester.tap(find.text('Work'));
      await tester.pump();

      // Now the confirm button should be enabled
      confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
      expect(confirmButton.onPressed, isNotNull);
    });

    testWidgets('select all toggles all categories', (tester) async {
      _setTallSurface(tester);
      await tester.pumpWidget(_buildTestWidget());

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Initially disabled
      final confirmFinder = find.widgetWithText(
        LottiPrimaryButton,
        'YES, GENERATE',
      );
      var confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
      expect(confirmButton.onPressed, isNull);

      // Tap "Select All"
      await tester.tap(find.text('Select All'));
      await tester.pump();

      // Confirm should now be enabled
      confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
      expect(confirmButton.onPressed, isNotNull);

      // Button should now say "Deselect All"
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap "Deselect All"
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      // Confirm should be disabled again
      confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
      expect(confirmButton.onPressed, isNull);

      // Button should say "Select All" again
      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('shows progress view with in-progress state after confirming', (
      tester,
    ) async {
      const inProgressState = EmbeddingBackfillState(
        progress: 0.5,
        isRunning: true,
        processedCount: 5,
        totalCount: 10,
        embeddedCount: 3,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            embeddingBackfillControllerProvider.overrideWith(
              () => _FakeBackfillController(inProgressState),
            ),
          ],
        ),
      );

      await _openModalSelectAndConfirm(tester);

      // Verify progress indicator is shown
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Verify percentage text
      expect(find.text('50%'), findsOneWidget);

      // Verify progress text with counts
      expect(
        find.text('5 / 10 entries (3 embedded)'),
        findsOneWidget,
      );
    });

    testWidgets('shows error state with error icon and message', (
      tester,
    ) async {
      const errorState = EmbeddingBackfillState(
        progress: 0.3,
        error: 'Embeddings are disabled',
        processedCount: 3,
        totalCount: 10,
        embeddedCount: 1,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            embeddingBackfillControllerProvider.overrideWith(
              () => _FakeBackfillController(errorState),
            ),
          ],
        ),
      );

      await _openModalSelectAndConfirm(tester);

      // Verify error icon is shown
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Verify error message text
      expect(find.text('Embeddings are disabled'), findsOneWidget);

      // Verify no progress indicator in error state
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows complete state with check icon and 100%', (
      tester,
    ) async {
      const completeState = EmbeddingBackfillState(
        progress: 1,
        processedCount: 10,
        totalCount: 10,
        embeddedCount: 8,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            embeddingBackfillControllerProvider.overrideWith(
              () => _FakeBackfillController(completeState),
            ),
          ],
        ),
      );

      await _openModalSelectAndConfirm(tester);

      // Verify check icon is shown
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Verify 100% text
      expect(find.text('100%'), findsOneWidget);

      // Verify no progress indicator in complete state
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Verify progress text with counts
      expect(
        find.text('10 / 10 entries (8 embedded)'),
        findsOneWidget,
      );
    });

    testWidgets('shows 0% progress at start of operation', (tester) async {
      const initialRunningState = EmbeddingBackfillState(
        isRunning: true,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            embeddingBackfillControllerProvider.overrideWith(
              () => _FakeBackfillController(initialRunningState),
            ),
          ],
        ),
      );

      await _openModalSelectAndConfirm(tester);

      // Verify 0% progress indicator and text
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('cancel dismisses the modal without confirming', (
      tester,
    ) async {
      _setTallSurface(tester);
      await tester.pumpWidget(_buildTestWidget());

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(
        find.text('Select categories to generate embeddings for.'),
        findsOneWidget,
      );

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify modal is dismissed
      expect(find.text('Open Modal'), findsOneWidget);
    });
  });
}

/// A fake [EmbeddingBackfillController] that returns a fixed state
/// and does nothing when [backfillCategories] is called.
class _FakeBackfillController extends EmbeddingBackfillController {
  _FakeBackfillController(this._state);

  final EmbeddingBackfillState _state;

  @override
  EmbeddingBackfillState build() => _state;

  @override
  Future<void> backfillCategories(Set<String> categoryIds) async {
    // No-op for testing — the state is already set via constructor.
  }
}
