import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockTagsService = MockTagsService();
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('DashboardDefinitionPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockTagsService = mockTagsServiceWithTags([]);
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      final mockEntitiesCacheService = MockEntitiesCacheService();

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness],
        ]),
      );

      when(mockJournalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          [habitFlossing],
        ]),
      );

      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets(
        'dashboard definition page is displayed with test item, '
        'then save button becomes visible after entering text ',
        (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      when(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('f8f55c10-e30b-4bf5-990d-d569ce4867fb'),
      ).thenAnswer((_) async => measurableChocolate);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: DashboardDefinitionPage(
                dashboard: testDashboardConfig.copyWith(description: ''),
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('dashboard_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('dashboard_description_field'));
      final saveButtonFinder = find.byKey(const Key('dashboard_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      formKey.currentState!.save();
      expect(formKey.currentState!.isValid, isTrue);
      final formData = formKey.currentState!.value;

      // form is filled with name and empty description
      expect(getTrimmed(formData, 'name'), testDashboardName);
      expect(getTrimmed(formData, 'description'), '');

      await tester.enterText(
        descriptionFieldFinder,
        'Some test dashboard description',
      );
      await tester.pumpAndSettle();

      final formData2 = formKey.currentState!.value;
      expect(formKey.currentState!.isValid, isTrue);

      // form description is now filled and stored in formKey
      expect(getTrimmed(formData2, 'name'), testDashboardName);
      expect(getTrimmed(formData2, 'description'), testDashboardDescription);

      // save button is visible as there are unsaved changes
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // save button calls mocked function
      verify(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .called(1);
    });

    testWidgets(
        'dashboard definition page is displayed with test item, '
        'then updating aggregation type in one measurement ', (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      when(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('f8f55c10-e30b-4bf5-990d-d569ce4867fb'),
      ).thenAnswer((_) async => measurableChocolate);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: DashboardDefinitionPage(
                dashboard: testDashboardConfig,
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('dashboard_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('dashboard_description_field'));
      final saveButtonFinder = find.byKey(const Key('dashboard_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      formKey.currentState!.save();
      expect(formKey.currentState!.isValid, isTrue);
      final formData = formKey.currentState!.value;

      // form is filled with name and empty description
      expect(getTrimmed(formData, 'name'), testDashboardName);
      expect(getTrimmed(formData, 'description'), testDashboardDescription);

      final measurableFinder = find.text(measurableChocolate.displayName);
      expect(measurableFinder, findsOneWidget);

      await tester.dragUntilVisible(
        measurableFinder,
        find.byType(SingleChildScrollView),
        const Offset(0, 50),
      );

      await tester.tap(measurableFinder);
      await tester.pumpAndSettle();

      final aggregationFinder = find.text('dailySum');
      expect(aggregationFinder, findsOneWidget);

      await tester.tap(aggregationFinder);
      await tester.pumpAndSettle();

      // save button is visible as the aggregation type changed
      expect(saveButtonFinder, findsOneWidget);

      expect(
        find.text('${measurableChocolate.displayName} [dailySum]'),
        findsOneWidget,
      );
    });

    testWidgets(
        'dashboard definition page is displayed with test item, '
        'then tapping delete', (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      when(() => mockPersistenceLogic.deleteDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('f8f55c10-e30b-4bf5-990d-d569ce4867fb'),
      ).thenAnswer((_) async => measurableChocolate);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: DashboardDefinitionPage(
                dashboard: testDashboardConfig,
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('dashboard_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('dashboard_description_field'));
      final saveButtonFinder = find.byKey(const Key('dashboard_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      formKey.currentState!.save();
      expect(formKey.currentState!.isValid, isTrue);
      final formData = formKey.currentState!.value;

      // form description is now filled and stored in formKey
      expect(getTrimmed(formData, 'name'), testDashboardName);
      expect(getTrimmed(formData, 'description'), testDashboardDescription);

      // dashboard delete calls method in mock
      final trashIconFinder = find.byIcon(MdiIcons.trashCanOutline);
      expect(trashIconFinder, findsOneWidget);

      await tester.dragUntilVisible(
        trashIconFinder, // what you want to find
        find.byType(SingleChildScrollView), // widget you want to scroll
        const Offset(0, 50), // delta to move
      );

      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final deleteQuestionFinder =
          find.text('Do you want to delete this dashboard?');
      final confirmDeleteFinder = find.text('YES, DELETE THIS DASHBOARD');
      expect(deleteQuestionFinder, findsOneWidget);
      expect(confirmDeleteFinder, findsOneWidget);

      await tester.tap(confirmDeleteFinder);
      await tester.pumpAndSettle();

      // delete button calls mocked function
      verify(() => mockPersistenceLogic.deleteDashboardDefinition(any()))
          .called(1);
    });

    testWidgets(
        'dashboard definition page is displayed with test item, '
        'then tapping copy icon', (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      when(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('f8f55c10-e30b-4bf5-990d-d569ce4867fb'),
      ).thenAnswer((_) async => measurableChocolate);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: DashboardDefinitionPage(
                dashboard: testDashboardConfig,
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('dashboard_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('dashboard_description_field'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      // tapping copy copies to clipboard
      final copyIconFinder = find.byIcon(Icons.copy);
      expect(copyIconFinder, findsOneWidget);

      await tester.dragUntilVisible(
        copyIconFinder, // what you want to find
        find.byType(SingleChildScrollView), // widget you want to scroll
        const Offset(0, 50), // delta to move
      );

      await tester.tap(copyIconFinder);
      await tester.pumpAndSettle();

      // TODO:
      // final clipboardText = await Clipboard.getData('text/plain');
      // debugPrint(clipboardText?.text);

      // delete button calls mocked function
      verify(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .called(1);
    });

    // Tests for CreateDashboardPage
    testWidgets(
        'empty dashboard creation page is displayed, '
        'save button visible after entering data, '
        'tap save calls persistence mock', (tester) async {
      when(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: CreateDashboardPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('dashboard_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('dashboard_description_field'));
      final saveButtonFinder = find.byKey(const Key('dashboard_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible as there are no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(nameFieldFinder, testDashboardConfig.name);
      await tester.pumpAndSettle();

      // save button is now visible after text enter
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // save button calls mocked function
      verify(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .called(1);
    });

    testWidgets('dashboard definitions page is displayed with one test item',
        (tester) async {
      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [testDashboardConfig],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const DashboardSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      verify(mockJournalDb.watchDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);
    });

    testWidgets('dashboard definitions page is displayed with one test item',
        (tester) async {
      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [testDashboardConfig],
        ]),
      );

      when(
        () => mockJournalDb.watchDashboardById(testDashboardConfig.id),
      ).thenAnswer(
        (_) => Stream<DashboardDefinition>.fromIterable([testDashboardConfig]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: EditDashboardPage(dashboardId: testDashboardConfig.id),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // finds text in dashboard card
      expect(find.text(testDashboardDescription), findsOneWidget);

      final dashboardCategoryFinder = find.byKey(
        const Key('select_dashboard_category'),
      );

      expect(dashboardCategoryFinder, findsOneWidget);

      await tester.tap(dashboardCategoryFinder);
      await tester.pumpAndSettle();
    });
  });
}

String getTrimmed(Map<String, dynamic>? formData, String k) {
  if (formData == null || formData[k] == null) {
    return '';
  }
  return formData[k].toString().trim();
}
