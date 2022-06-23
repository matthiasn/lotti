import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/services/tags_service.dart';

import '../../../widget_test_utils.dart';
import 'dashboard_definition_test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockTagsService = MockTagsService();
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('DashboardDefinitionPage Widget Tests - ', () {
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
      items: [],
      name: testDashboardName,
      description: testDashboardDescription,
      createdAt: testDateTime,
      updatedAt: testDateTime,
      vectorClock: null,
      private: false,
      version: '',
      lastReviewed: testDateTime,
      active: true,
      id: '',
    );

    testWidgets('Widget shows dashboard definition page with test item',
        (tester) async {
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
      expect(saveButtonFinder, findsNothing);
      expect(formKey.currentState!.isValid, isTrue);
    });
  });
}
