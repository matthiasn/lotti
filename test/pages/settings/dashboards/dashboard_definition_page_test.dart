import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';
import 'package:mocktail/mocktail.dart';

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
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    final testDateTime = DateTime.fromMillisecondsSinceEpoch(0);
    const testDashboardName = 'Some test dashboard';
    const testDashboardDescription = 'Some test dashboard description';

    final testDashboardConfig = DashboardDefinition(
      items: [
        DashboardHealthItem(
          color: '#0000FF',
          healthType: 'HealthDataType.RESTING_HEART_RATE',
        ),
        DashboardWorkoutItem(
          workoutType: 'running',
          displayName: 'Running calories',
          color: '#0000FF',
          valueType: WorkoutValueType.energy,
        ),
        DashboardMeasurementItem(
          id: '08511530-eb2d-11ec-bbb3-0f45b65444d2',
          aggregationType: AggregationType.dailySum,
        ),
      ],
      name: testDashboardName,
      description: '',
      createdAt: testDateTime,
      updatedAt: testDateTime,
      vectorClock: null,
      private: false,
      version: '',
      lastReviewed: testDateTime,
      active: true,
      id: '',
    );

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

      expect(find.text('Running calories'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      expect(saveButtonFinder, findsNothing);
      expect(formKey.currentState!.isValid, isTrue);

      expect(formKey.currentState!.isValid, isTrue);
      final formData = formKey.currentState!.value;
      expect(getTrimmed(formData, 'description'), '');

      await tester.enterText(
        descriptionFieldFinder,
        'Some test dashboard description',
      );

      await tester.pumpAndSettle();

      final formData2 = formKey.currentState!.value;
      expect(formKey.currentState!.isValid, isTrue);
      expect(getTrimmed(formData2, 'name'), testDashboardName);
      expect(getTrimmed(formData2, 'description'), testDashboardDescription);

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
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(nameFieldFinder, testDashboardConfig.name);

      await tester.pumpAndSettle();
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      verify(() => mockPersistenceLogic.upsertDashboardDefinition(any()))
          .called(1);
    });
  });
}
