import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/measurables/measurable_create_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks.dart';
import '../../../test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  var mockAppRouter = MockAppRouter();

  group('MeasurableDetailsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      mockAppRouter = MockAppRouter();
      when(mockAppRouter.pop).thenAnswer((invocation) async => true);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<AppRouter>(mockAppRouter)
        ..registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    testWidgets(
        'measurable details page is displayed with type water & updated',
        (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: MeasurableDetailsPage(dataType: measurableWater),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('measurable_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('measurable_description_field'));
      final saveButtonFinder = find.byKey(const Key('measurable_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );
      await tester.enterText(
        descriptionFieldFinder,
        'new description',
      );
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
    });

    testWidgets(
        'measurable details page is displayed with type water & deleted',
        (tester) async {
      Future<int> mockUpsertEntity() {
        return mockPersistenceLogic.upsertEntityDefinition(any());
      }

      when(mockUpsertEntity).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: MeasurableDetailsPage(dataType: measurableWater),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final trashIconFinder = find.byIcon(MdiIcons.trashCanOutline);
      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final deleteQuestionFinder =
          find.text('Do you want to delete this measurable data type?');
      final confirmDeleteFinder = find.text('YES, DELETE THIS MEASURABLE');
      expect(deleteQuestionFinder, findsOneWidget);
      expect(confirmDeleteFinder, findsOneWidget);

      await tester.tap(confirmDeleteFinder);
      await tester.pumpAndSettle();

      // delete button calls mocked function
      verify(mockUpsertEntity).called(1);
    });

    testWidgets(
        'measurable details page is displayed with type water & updated',
        (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const CreateMeasurablePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('measurable_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('measurable_description_field'));
      final saveButtonFinder = find.byKey(const Key('measurable_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );
      await tester.enterText(
        descriptionFieldFinder,
        'new description',
      );
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
    });
  });
}
