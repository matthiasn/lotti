import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/themes/themes_service.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FillSurveyPage Widget Tests -', () {
    final mockPersistenceLogic = MockPersistenceLogic();

    setUp(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets('PANAS button is tappable, opens survey', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FillSurveyPage(),
        ),
      );

      await tester.pumpAndSettle();

      final panasButtonFinder = find.text('PANAS');
      expect(panasButtonFinder, findsOneWidget);

      await tester.tap(panasButtonFinder);
      await tester.pumpAndSettle();

      final panasTitleFinder = find.text(
        'The Positive and Negative Affect Schedule (PANAS; Watson et al., 1988)',
      );
      expect(panasTitleFinder, findsOneWidget);
    });

    testWidgets('PANAS button is tappable, opens survey', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FillSurveyWithTypePage(
            surveyType: 'panasSurveyTask',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final panasButtonFinder = find.text('PANAS');
      expect(panasButtonFinder, findsOneWidget);

      await tester.tap(panasButtonFinder);
      await tester.pumpAndSettle();

      final panasTitleFinder = find.text(
        'The Positive and Negative Affect Schedule (PANAS; Watson et al., 1988)',
      );
      expect(panasTitleFinder, findsOneWidget);
    });

    testWidgets('CFQ 11 button is tappable, opens survey', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FillSurveyPage(),
        ),
      );

      await tester.pumpAndSettle();

      final cfq11ButtonFinder = find.text('CFQ 11');
      expect(cfq11ButtonFinder, findsOneWidget);

      await tester.tap(cfq11ButtonFinder);
      await tester.pumpAndSettle();

      final cfqTitleFinder = find.text('Chalder Fatigue Scale (CFQ 11)');
      expect(cfqTitleFinder, findsOneWidget);

      final cancelIconFinder = find.byIcon(Icons.highlight_off);

      await tester.tap(cancelIconFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('YES'));
    });

    testWidgets('CFQ 11 button is tappable, opens survey, with linked',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FillSurveyWithLinkedPage(
            linkedId: 'some-id',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cfq11ButtonFinder = find.text('CFQ 11');
      expect(cfq11ButtonFinder, findsOneWidget);

      await tester.tap(cfq11ButtonFinder);
      await tester.pumpAndSettle();

      final cfqTitleFinder = find.text('Chalder Fatigue Scale (CFQ 11)');
      expect(cfqTitleFinder, findsOneWidget);

      final cancelIconFinder = find.byIcon(Icons.highlight_off);

      await tester.tap(cancelIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
