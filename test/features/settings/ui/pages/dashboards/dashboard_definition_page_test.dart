import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/chart_multi_select.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_item_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

/// Stubs the measurable lookups every dashboard-definition test needs:
/// chocolate and water by id, with water as the any() fallback.
void _stubMeasurableDb(MockJournalDb mockJournalDb) {
  when(
    () => mockJournalDb.getMeasurableDataTypeById(
      'f8f55c10-e30b-4bf5-990d-d569ce4867fb',
    ),
  ).thenAnswer((_) async => measurableChocolate);

  when(
    () => mockJournalDb.getMeasurableDataTypeById(
      '83ebf58d-9cea-4c15-a034-89c84a8b8178',
    ),
  ).thenAnswer((_) async => measurableWater);

  when(
    () => mockJournalDb.getMeasurableDataTypeById(any()),
  ).thenAnswer((_) async => measurableWater);
}

/// Records the most recent dashboard handed to
/// `upsertDashboardDefinition` so tests can assert on the persisted value.
class _UpsertCapture {
  DashboardDefinition? saved;
}

_UpsertCapture _stubUpsertCapture(MockPersistenceLogic logic) {
  final capture = _UpsertCapture();
  when(() => logic.upsertDashboardDefinition(any())).thenAnswer((
    invocation,
  ) async {
    capture.saved = invocation.positionalArguments.first as DashboardDefinition;
    return 1;
  });
  return capture;
}

/// Pumps [page] on a tall desktop-like surface so the form, the charts
/// section, and the sticky action bar are all laid out without scrolling.
Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(makeTestableWidgetNoScroll(page));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The action-bar pill carrying [label] ('Save', 'Cancel', ...).
Finder _pill(String label) => find.widgetWithText(DsGlassPill, label);

/// Whether the action-bar pill carrying [label] is currently enabled.
bool _pillEnabled(WidgetTester tester, String label) =>
    tester.widget<DsGlassPill>(_pill(label)).enabled;

/// Opens a [ChartMultiSelect] modal deterministically by invoking the
/// button InkWell's onTap directly: coordinate taps on content laid out
/// near the glass action bar proved flaky in the batched suite.
Future<void> _openChartSelect<T>(
  WidgetTester tester,
  String semanticsLabel,
) async {
  final inkWell = tester.widget<InkWell>(
    find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is ChartMultiSelect<T> && w.semanticsLabel == semanticsLabel,
      ),
      matching: find.byType(InkWell),
    ),
  );
  inkWell.onTap!();
  await tester.pumpAndSettle();
}

String _trimmed(Map<String, dynamic>? formData, String k) {
  if (formData == null || formData[k] == null) {
    return '';
  }
  return formData[k].toString().trim();
}

void main() {
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('DashboardDefinitionPage Widget Tests - ', () {
    setUpAll(registerAllFallbackValues);

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      final mockEntitiesCacheService = MockEntitiesCacheService();

      when(mockJournalDb.getAllCategories).thenAnswer(
        (_) async => [categoryMindfulness],
      );

      when(mockJournalDb.getAllHabitDefinitions).thenAnswer(
        (_) async => [habitFlossing],
      );

      mockPersistenceLogic = MockPersistenceLogic();

      final mockUpdateNotifications = MockUpdateNotifications();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();

      // The page beams to `/settings/dashboards` after save / delete
      // (V2's desktop detail surface mounts inline, so Navigator.pop
      // would be a no-op). These tests don't register a NavService, so
      // install a no-op override.
      beamToNamedOverride = (_) {};
    });
    tearDown(() async {
      beamToNamedOverride = null;
      await getIt.reset();
    });

    testWidgets(
      'header shows the edit title and the back button beams to the '
      'dashboards list',
      (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await _pumpPage(
          tester,
          DashboardDefinitionPage(dashboard: testDashboardConfig),
        );

        expect(find.text('Edit dashboard'), findsOneWidget);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
        await tester.pump();

        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'Options section card groups Private then Active with the unified '
      'copy, leaving Basic settings switch-free',
      (tester) async {
        await _pumpPage(
          tester,
          DashboardDefinitionPage(dashboard: testDashboardConfig),
        );

        final optionsSection = find.ancestor(
          of: find.text('Options'),
          matching: find.byType(SettingsFormSection),
        );
        expect(optionsSection, findsOneWidget);

        final rows = tester
            .widgetList<SettingsSwitchRow>(
              find.descendant(
                of: optionsSection,
                matching: find.byType(SettingsSwitchRow),
              ),
            )
            .toList();
        expect(rows.map((row) => row.title), ['Private', 'Active']);
        expect(rows[0].icon, Icons.lock_outline);
        expect(
          rows[0].subtitle,
          'Only visible when private entries are shown',
        );
        expect(rows[1].icon, Icons.visibility_outlined);
        expect(
          rows[1].subtitle,
          'Shown in the dashboards list',
        );

        // The toggles moved out of Basic settings entirely.
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
      'save pill is disabled until the form is edited, then saving '
      'persists the form values and beams back to the list',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        final capture = _stubUpsertCapture(mockPersistenceLogic);
        _stubMeasurableDb(mockJournalDb);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig.copyWith(description: ''),
            formKey: formKey,
          ),
        );

        // No changes yet: the primary action renders disabled.
        expect(_pillEnabled(tester, 'Save'), isFalse);

        formKey.currentState!.save();
        expect(formKey.currentState!.isValid, isTrue);

        // The form is seeded with the dashboard name and empty description.
        expect(
          _trimmed(formKey.currentState!.value, 'name'),
          testDashboardName,
        );
        expect(_trimmed(formKey.currentState!.value, 'description'), '');

        await tester.enterText(
          find.byKey(const Key('dashboard_description_field')),
          'Some test dashboard description',
        );
        await tester.pump();

        // The description is now tracked in the form state and the page
        // is dirty, so the save pill becomes enabled.
        expect(
          _trimmed(formKey.currentState!.value, 'description'),
          testDashboardDescription,
        );
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(capture.saved, isNotNull);
        expect(capture.saved!.name, testDashboardName);
        expect(capture.saved!.description, testDashboardDescription);
        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'Ctrl+S keyboard shortcut saves a dirty form and beams back',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        final capture = _stubUpsertCapture(mockPersistenceLogic);
        _stubMeasurableDb(mockJournalDb);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          'Renamed dashboard',
        );
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(capture.saved, isNotNull);
        expect(capture.saved!.name, 'Renamed dashboard');
        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'cancel pill beams back to the list without persisting changes',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          'Edited but discarded',
        );
        await tester.pump();
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Cancel'));
        await tester.pump();

        verifyNever(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        );
        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'tapping a measurable item opens the aggregation modal; picking a '
      'different type re-renders the card and enables save',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);
        _stubMeasurableDb(mockJournalDb);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

        // No changes yet: the primary action renders disabled.
        expect(_pillEnabled(tester, 'Save'), isFalse);

        // Tap the measurable item card deterministically: a coordinate tap
        // on the text proved flaky in the batched CI run (silent miss
        // behind warnIfMissed: false when fonts/layout drift across the
        // shared isolate). Invoke the card's onTap directly.
        final chocolateCard = tester.widget<ItemCard>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(MeasurableItemCard),
              matching: find.textContaining(measurableChocolate.displayName),
            ),
            matching: find.byType(ItemCard),
          ),
        );
        chocolateCard.onTap!();
        // Modal open is a route transition — settle until fully mounted.
        await tester.pumpAndSettle();

        // Tapping the measurement opens the DashboardItemModal with one
        // ChoiceChip per aggregation type.
        final context = tester.element(
          find.byType(DashboardDefinitionPage),
        );
        expect(
          find.text(context.messages.dashboardAggregationLabel),
          findsOneWidget,
        );

        // Pick a different aggregation type. The modal pops, the item card
        // title re-renders with the localized aggregation suffix, and the
        // dirty flag enables the save pill.
        await tester.tap(find.text('Daily maximum'));
        // Modal close is a route transition as well — settle it.
        await tester.pumpAndSettle();

        expect(
          find.text('${measurableChocolate.displayName} — Daily maximum'),
          findsOneWidget,
        );
        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'action-bar copy button saves the dashboard and copies its '
      'definitions',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);
        _stubMeasurableDb(mockJournalDb);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

        // The copy action is a labeled in-form secondary button — not an
        // unlabeled icon in the action bar and not a header action.
        final copyFinder = find.byKey(const Key('dashboard_copy'));
        final copyButton = tester.widget<DesignSystemButton>(copyFinder);
        expect(copyButton.label, 'Save and copy configuration');
        expect(
          find.ancestor(
            of: copyFinder,
            matching: find.byType(SettingsFormActionBar),
          ),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          '${testDashboardConfig.name} modified',
        );
        await tester.pump();

        await tester.tap(copyFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Copy persists the dashboard before copying it to the clipboard.
        verify(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'destructive delete action opens the confirmation sheet; confirming '
      'deletes the dashboard and beams back',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        when(
          () => mockPersistenceLogic.deleteDashboardDefinition(any()),
        ).thenAnswer((_) async => 1);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

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

        // The confirmation modal must be visible.
        expect(
          find.text('Do you want to delete this dashboard?'),
          findsOneWidget,
        );

        await tester.tap(find.text('YES, DELETE THIS DASHBOARD'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockPersistenceLogic.deleteDashboardDefinition(any()),
        ).called(1);
        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'dismissing the delete confirmation keeps the dashboard',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

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

        expect(
          find.text('Do you want to delete this dashboard?'),
          findsOneWidget,
        );

        // Dismiss without confirming (tap the barrier above the sheet).
        await tester.tapAt(const Offset(500, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verifyNever(
          () => mockPersistenceLogic.deleteDashboardDefinition(any()),
        );
      },
    );

    testWidgets('rendering an existing dashboard seeds the description field', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        DashboardDefinitionPage(
          dashboard: testDashboardConfig,
          formKey: GlobalKey<FormBuilderState>(),
        ),
      );

      expect(find.text(testDashboardDescription), findsOneWidget);
      // The destructive delete pill is present in edit mode.
      expect(find.widgetWithText(SettingsDeleteRow, 'Delete'), findsOneWidget);
    });

    testWidgets('dashboard definition page setCategory logs to DevLogger '
        'and marks the page dirty when clearing the category', (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      // Clear DevLogger captured logs before test
      DevLogger.clear();

      _stubUpsertCapture(mockPersistenceLogic);
      _stubMeasurableDb(mockJournalDb);

      // Use testDashboardConfig which has categoryId set
      await _pumpPage(
        tester,
        DashboardDefinitionPage(
          dashboard: testDashboardConfig,
          formKey: formKey,
        ),
      );

      // Find the category selector field
      final categoryFieldFinder = find.byKey(
        const Key('select_dashboard_category'),
      );
      expect(categoryFieldFinder, findsOneWidget);

      // The close button (clear category) must be visible since categoryId
      // is set.
      final clearCategoryButtonFinder = find.byIcon(Icons.close_rounded);
      expect(
        clearCategoryButtonFinder,
        findsOneWidget,
        reason:
            'Clear category button should be present when categoryId is set',
      );

      await tester.ensureVisible(clearCategoryButtonFinder);
      await tester.pump();

      // Tap the clear button to trigger setCategory(null)
      await tester.tap(clearCategoryButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DevLogger.log was called for setCategory
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('DashboardDefinitionPage') &&
              log.contains('setCategory'),
        ),
        isTrue,
        reason: 'setCategory should log to DevLogger',
      );

      // Clearing the category marks the page dirty.
      expect(_pillEnabled(tester, 'Save'), isTrue);
    });

    testWidgets(
      'adding a habit chart via modal sets dirty and enables save',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);

        // Use an empty dashboard so we can clearly detect the addition.
        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: emptyTestDashboardConfig,
            formKey: formKey,
          ),
        );

        expect(_pillEnabled(tester, 'Save'), isFalse);

        await _openChartSelect<HabitDefinition>(tester, 'Add Habit Chart');

        // Select habitFlossing in the modal list.
        final habitItemFinder = find.widgetWithText(
          CheckboxListTile,
          habitFlossing.name,
        );
        expect(habitItemFinder, findsOneWidget);
        await tester.tap(habitItemFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm the selection.
        final addButtonFinder = find.widgetWithText(FilledButton, 'Add (1)');
        expect(addButtonFinder, findsOneWidget);
        await tester.tap(addButtonFinder);
        await tester.pumpAndSettle();

        // Dirty flag is now set → the save pill is enabled and the item
        // card was appended.
        expect(find.byType(Dismissible), findsOneWidget);
        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'adding a measurable chart via modal sets dirty and enables save',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: emptyTestDashboardConfig,
            formKey: formKey,
          ),
        );

        expect(_pillEnabled(tester, 'Save'), isFalse);

        await _openChartSelect<MeasurableDataType>(
          tester,
          'Add Measurable Data Chart',
        );

        // Select the first measurable (Water).
        final measItemFinder = find.widgetWithText(
          CheckboxListTile,
          measurableWater.displayName,
        );
        expect(measItemFinder, findsOneWidget);
        await tester.tap(measItemFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final addButtonFinder = find.widgetWithText(FilledButton, 'Add (1)');
        expect(addButtonFinder, findsOneWidget);
        await tester.tap(addButtonFinder);
        await tester.pumpAndSettle();

        // Item was added → dirty → save pill enabled.
        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'adding a survey chart via modal sets dirty and enables save',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: emptyTestDashboardConfig,
            formKey: formKey,
          ),
        );

        expect(_pillEnabled(tester, 'Save'), isFalse);

        await _openChartSelect<DashboardSurveyItem>(
          tester,
          'Add Survey Chart',
        );

        // Pick the first survey item in the modal.
        final firstSurveyItem = find.byType(CheckboxListTile).first;
        await tester.tap(firstSurveyItem);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final addButtonFinder = find.widgetWithText(FilledButton, 'Add (1)');
        expect(addButtonFinder, findsOneWidget);
        await tester.tap(addButtonFinder);
        await tester.pumpAndSettle();

        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'dismissing a dashboard item removes it and sets dirty',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);

        // Use a dashboard with exactly one item so we can detect its removal.
        final singleItemDashboard = emptyTestDashboardConfig.copyWith(
          items: [
            const DashboardItem.measurement(
              id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
              aggregationType: AggregationType.dailySum,
            ),
          ],
        );

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: singleItemDashboard,
            formKey: formKey,
          ),
        );
        await tester.pumpAndSettle();

        // Find the Dismissible for the single item.
        final dismissibleFinder = find.byType(Dismissible);
        expect(dismissibleFinder, findsOneWidget);

        // Drag to dismiss.
        await tester.drag(dismissibleFinder, const Offset(-700, 0));
        await tester.pumpAndSettle();

        // After dismiss the item is gone.
        expect(find.byType(Dismissible), findsNothing);

        // dirty → save pill enabled.
        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'save with invalid form (empty name) does not persist or navigate',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        _stubUpsertCapture(mockPersistenceLogic);

        // Start with a dashboard that has a valid name.
        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: testDashboardConfig,
            formKey: formKey,
          ),
        );

        // Clear the name field to make the form invalid.
        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          '',
        );
        await tester.pump();

        // The save pill is enabled because dirty = true.
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Form is invalid → upsert must NOT be called and the page stays.
        verifyNever(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        );
        expect(beamedTo, isNull);
      },
    );

    testWidgets(
      'EditDashboardPage shows EmptyScaffold when dashboard is not found',
      (tester) async {
        when(
          () => mockJournalDb.getDashboardById(any()),
        ).thenAnswer((_) async => null);

        await _pumpPage(
          tester,
          EditDashboardPage(dashboardId: 'nonexistent-id'),
        );

        // Stream fetches null → "Dashboard not found" scaffold.
        expect(find.text('Dashboard not found'), findsOneWidget);
      },
    );

    testWidgets(
      'EditDashboardPage renders DashboardDefinitionPage when dashboard found',
      (tester) async {
        when(
          () => mockJournalDb.getDashboardById(testDashboardConfig.id),
        ).thenAnswer((_) async => testDashboardConfig);

        await _pumpPage(
          tester,
          EditDashboardPage(dashboardId: testDashboardConfig.id),
        );

        // The dashboard name is seeded into the name field.
        expect(find.text(testDashboardName), findsOneWidget);
        expect(find.text('Edit dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'adding a health chart appends a health item, sets dirty, and saving '
      'persists it',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        final capture = _stubUpsertCapture(mockPersistenceLogic);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: emptyTestDashboardConfig,
            formKey: formKey,
          ),
        );

        // No item cards and save disabled before interaction.
        expect(find.byType(Dismissible), findsNothing);
        expect(_pillEnabled(tester, 'Save'), isFalse);

        // Invoke the health ChartMultiSelect's onConfirm directly with the
        // WEIGHT health type. Driving the WoltModalSheet (open → select →
        // Add) is non-deterministic in the batched suite because the modal
        // flow depends on hit-testing/overlay timing; calling onConfirm
        // exercises onConfirmAddHealthType deterministically.
        final healthSelect = tester.widget<ChartMultiSelect<HealthTypeConfig>>(
          find.byWidgetPredicate(
            (w) =>
                w is ChartMultiSelect<HealthTypeConfig> &&
                w.semanticsLabel == 'Add Health Chart',
          ),
        );
        healthSelect.onConfirm([healthTypes['HealthDataType.WEIGHT']]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // onConfirmAddHealthType appended a health item → dirty → save
        // enabled.
        expect(find.byType(Dismissible), findsOneWidget);
        expect(_pillEnabled(tester, 'Save'), isTrue);

        // Saving persists exactly one DashboardHealthItem for WEIGHT.
        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final healthItems = capture.saved!.items
            .whereType<DashboardHealthItem>();
        expect(healthItems, hasLength(1));
        expect(healthItems.first.healthType, 'HealthDataType.WEIGHT');
        expect(healthItems.first.color, 'color');
      },
    );

    testWidgets(
      'adding a workout chart appends a workout item, sets dirty, and '
      'saving persists it',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        final capture = _stubUpsertCapture(mockPersistenceLogic);

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: emptyTestDashboardConfig,
            formKey: formKey,
          ),
        );

        expect(find.byType(Dismissible), findsNothing);
        expect(_pillEnabled(tester, 'Save'), isFalse);

        // Invoke the workout ChartMultiSelect's onConfirm directly with a
        // workout type — same determinism rationale as the health case.
        final workoutType = workoutTypes['walking.duration'];
        final workoutSelect = tester
            .widget<ChartMultiSelect<DashboardWorkoutItem>>(
              find.byWidgetPredicate(
                (w) =>
                    w is ChartMultiSelect<DashboardWorkoutItem> &&
                    w.semanticsLabel == 'Add Workout Chart',
              ),
            );
        workoutSelect.onConfirm([workoutType]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(Dismissible), findsOneWidget);
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Exactly one workout item was persisted, with the chosen type.
        final workoutItems = capture.saved!.items
            .whereType<DashboardWorkoutItem>()
            .toList();
        expect(workoutItems, hasLength(1));
        expect(workoutItems.first.workoutType, workoutType!.workoutType);
      },
    );

    testWidgets(
      'tapping a measurable item card invokes updateItem and marks dirty',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        _stubUpsertCapture(mockPersistenceLogic);

        // A dashboard with a single measurable item whose card renders a
        // tappable ListTile (the measurable type resolves to Water).
        final singleMeasurableDashboard = emptyTestDashboardConfig.copyWith(
          items: const [
            DashboardMeasurementItem(
              id: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
              aggregationType: AggregationType.dailySum,
            ),
          ],
        );

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: singleMeasurableDashboard,
            formKey: formKey,
          ),
        );

        // Initially nothing is dirty.
        expect(_pillEnabled(tester, 'Save'), isFalse);

        // The measurable item card title renders the resolved display name
        // with the localized aggregation suffix — no raw enum names.
        final cardTitleFinder = find.text(
          '${measurableWater.displayName} — Daily sum',
        );
        expect(cardTitleFinder, findsOneWidget);

        // Tapping the card fires updateItemFn (updateItem), which also
        // opens the edit modal. updateItem sets dirty = true.
        await tester.tap(cardTitleFinder);
        await tester.pump();

        // updateItem marked the page dirty → save pill enabled.
        expect(_pillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'copying a dashboard containing a habit item hits the habit copy branch',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        final capture = _stubUpsertCapture(mockPersistenceLogic);

        when(
          () => mockJournalDb.getHabitById(habitFlossing.id),
        ).thenAnswer((_) async => habitFlossing);

        // A dashboard whose only item is a habit chart so copyDashboard's
        // switch reaches the DashboardHabitItem branch.
        final habitDashboard = testDashboardConfig.copyWith(
          items: [
            DashboardItem.habitChart(habitId: habitFlossing.id),
          ],
        );

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: habitDashboard,
            formKey: formKey,
          ),
        );

        // Mark dirty so the copy persists a meaningful, valid dashboard.
        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          'Copied dashboard',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('dashboard_copy')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // copyDashboard saved the dashboard and iterated its items without
        // throwing on the habit branch; the habit item is preserved.
        verify(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        ).called(1);
        // getMeasurableDataTypeById must NOT be queried: a habit item takes
        // the break branch, not the measurement branch.
        verifyNever(() => mockJournalDb.getMeasurableDataTypeById(any()));
        expect(
          capture.saved!.items.whereType<DashboardHabitItem>(),
          hasLength(1),
        );
      },
    );

    // copyDashboard's switch sends DashboardHealthItem, DashboardWorkoutItem,
    // and DashboardSurveyItem through the `break` arm: unlike measurement
    // items they are NOT looked up in JournalDb. These cases prove the copy
    // succeeds for each non-measurement item type without ever querying a
    // measurable.
    final nonMeasurableCopyCases = <({String label, DashboardItem item})>[
      (
        label: 'health',
        item: const DashboardHealthItem(
          color: '#0000FF',
          healthType: 'HealthDataType.WEIGHT',
        ),
      ),
      (
        label: 'workout',
        item: const DashboardWorkoutItem(
          workoutType: 'running',
          displayName: 'Running calories',
          color: '#0000FF',
          valueType: WorkoutValueType.energy,
        ),
      ),
      (
        label: 'survey',
        item: const DashboardSurveyItem(
          colorsByScoreKey: {
            'Positive Affect Score': '#00FF00',
            'Negative Affect Score': '#FF0000',
          },
          surveyType: 'panasSurveyTask',
          surveyName: 'PANAS',
        ),
      ),
    ];

    for (final copyCase in nonMeasurableCopyCases) {
      testWidgets(
        'copying a dashboard containing only a ${copyCase.label} item takes '
        'the break branch and never queries a measurable',
        (tester) async {
          final formKey = GlobalKey<FormBuilderState>();

          final capture = _stubUpsertCapture(mockPersistenceLogic);

          final dashboard = testDashboardConfig.copyWith(
            items: [copyCase.item],
          );

          await _pumpPage(
            tester,
            DashboardDefinitionPage(
              dashboard: dashboard,
              formKey: formKey,
            ),
          );

          // Mark dirty so copyDashboard persists a meaningful dashboard.
          await tester.enterText(
            find.byKey(const Key('dashboard_name_field')),
            'Copied ${copyCase.label} dashboard',
          );
          await tester.pump();

          await tester.tap(find.byKey(const Key('dashboard_copy')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // The dashboard was persisted and its single item survived the
          // copy.
          verify(
            () => mockPersistenceLogic.upsertDashboardDefinition(any()),
          ).called(1);
          expect(capture.saved!.items, hasLength(1));
          expect(capture.saved!.items.first, copyCase.item);

          // The break branch means NO measurable lookup happened for these
          // item types (only DashboardMeasurementItem hits getMeasurable…).
          verifyNever(() => mockJournalDb.getMeasurableDataTypeById(any()));
        },
      );
    }

    testWidgets(
      'reordering items via semantics reorders dashboardItems and persists',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        final capture = _stubUpsertCapture(mockPersistenceLogic);

        // Two health items render their titles synchronously from the
        // healthTypes map (no DB dependency), giving stable reorder targets.
        final twoHealthDashboard = testDashboardConfig.copyWith(
          items: const [
            DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.WEIGHT',
            ),
            DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.BODY_FAT_PERCENTAGE',
            ),
          ],
        );

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: twoHealthDashboard,
            formKey: formKey,
          ),
        );

        final handle = tester.ensureSemantics();

        // The ReorderableListView attaches the "Move up" custom action to an
        // ancestor of the item's title text node. Walk up from the text node
        // to find the node that actually carries the action.
        final moveUpId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move up'),
        );
        SemanticsNode? node = tester.getSemantics(
          find.text('Body Fat Percentage'),
        );
        while (node != null &&
            !(node.getSemanticsData().customSemanticsActionIds ?? const [])
                .contains(moveUpId)) {
          node = node.parent;
        }
        expect(
          node,
          isNotNull,
          reason: 'A reorderable node must expose the "Move up" action',
        );

        // "Move up" on the second item → onReorderItem(1, 0). The handler
        // moves "Body Fat Percentage" ahead of "Weight".
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node!.id,
          SemanticsAction.customAction,
          moveUpId,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Reorder set dirty → save pill enabled.
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The persisted item order reflects the reorder: Body Fat Percentage
        // (BODY_FAT_PERCENTAGE) now precedes Weight (WEIGHT).
        final healthItems = capture.saved!.items
            .whereType<DashboardHealthItem>()
            .toList();
        expect(healthItems, hasLength(2));
        expect(
          healthItems.first.healthType,
          'HealthDataType.BODY_FAT_PERCENTAGE',
        );
        expect(healthItems.last.healthType, 'HealthDataType.WEIGHT');

        handle.dispose();
      },
    );

    testWidgets(
      'moving the first item down hits the newIndex > oldIndex reorder branch',
      (tester) async {
        final formKey = GlobalKey<FormBuilderState>();

        final capture = _stubUpsertCapture(mockPersistenceLogic);

        // Two health items render their titles synchronously from the
        // healthTypes map (no DB dependency), giving stable reorder targets.
        final twoHealthDashboard = testDashboardConfig.copyWith(
          items: const [
            DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.WEIGHT',
            ),
            DashboardHealthItem(
              color: '#0000FF',
              healthType: 'HealthDataType.BODY_FAT_PERCENTAGE',
            ),
          ],
        );

        await _pumpPage(
          tester,
          DashboardDefinitionPage(
            dashboard: twoHealthDashboard,
            formKey: formKey,
          ),
        );

        final handle = tester.ensureSemantics();

        // Walk up from the first item's title text node to the reorderable
        // node that actually carries the "Move down" custom action.
        final moveDownId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move down'),
        );
        SemanticsNode? node = tester.getSemantics(find.text('Weight'));
        while (node != null &&
            !(node.getSemanticsData().customSemanticsActionIds ?? const [])
                .contains(moveDownId)) {
          node = node.parent;
        }
        expect(
          node,
          isNotNull,
          reason: 'A reorderable node must expose the "Move down" action',
        );

        // "Move down" on the first item makes Flutter call
        // onReorderItem(0, 1): newIndex(1) > oldIndex(0), so the handler
        // takes the `newIndex - 1` branch (insertionIndex = 0) and the order
        // is unchanged, but the previously-uncovered branch is exercised.
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node!.id,
          SemanticsAction.customAction,
          moveDownId,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Reorder set dirty → save pill enabled.
        expect(_pillEnabled(tester, 'Save'), isTrue);

        await tester.tap(_pill('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Moving the first item down by one with the newIndex - 1 adjustment
        // is an identity reorder: order is preserved but the branch ran.
        final healthItems = capture.saved!.items
            .whereType<DashboardHealthItem>()
            .toList();
        expect(healthItems, hasLength(2));
        expect(healthItems.first.healthType, 'HealthDataType.WEIGHT');
        expect(
          healthItems.last.healthType,
          'HealthDataType.BODY_FAT_PERCENTAGE',
        );

        handle.dispose();
      },
    );
  });
}
