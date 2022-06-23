import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data.dart';
import '../../../widget_test_utils.dart';
import 'dashboard_definition_test_mocks.dart';

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
      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets(
        'dashboard definition page is displayed with test item, '
        'then save button becomes visible after entering text', (tester) async {
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 500,
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

      expect(find.text('Running calories'), findsOneWidget);
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
    });

    testWidgets(
        'empty dashboard creation page is displayed, '
        'save button visible after entering data, '
        'tap save calls persistence mock', (tester) async {
      when(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 500,
              ),
              child: const CreateDashboardPage(),
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
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 500,
              ),
              child: const DashboardSettingsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      verify(mockJournalDb.watchDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text(testDashboardDescription), findsOneWidget);
    });

    testWidgets('dashboard list page is displayed with one test item',
        (tester) async {
      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [testDashboardConfig],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 500,
              ),
              child: const DashboardsListPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      verify(mockJournalDb.watchDashboards).called(1);

      // finds text in dashboard card
      expect(find.text(testDashboardName), findsOneWidget);
      expect(find.text(testDashboardDescription), findsOneWidget);
    });
  });
}
